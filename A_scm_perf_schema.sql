-- ============================================================
-- BUOC A: TAO SCHEMA RIENG scm_warehouse_perf (rong, khong dung chung voi schema test)
-- Gom PHAN 1 -> PHAN 6 cua file cu (bang, index, view, trigger, procedure)
-- KHONG co du lieu nen nho (phan 7) va khong co test case (phan 9)
-- ============================================================
CREATE DATABASE IF NOT EXISTS scm_warehouse_perf CHARACTER SET utf8mb4;

USE scm_warehouse_perf;

-- ============================================================
-- 1. CAC BANG DANH MUC COT LOI (MASTER DATA)
-- ============================================================

CREATE TABLE warehouses (
    warehouse_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    warehouse_code VARCHAR(20) NOT NULL,
    warehouse_name VARCHAR(120) NOT NULL,
    address_line VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    country_code CHAR(2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_warehouses_code UNIQUE (warehouse_code),
    CONSTRAINT chk_warehouses_country_code
        CHECK (REGEXP_LIKE(country_code, '^[A-Z]{2}$'))
) ENGINE = InnoDB;

CREATE TABLE suppliers (
    supplier_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    supplier_code VARCHAR(20) NOT NULL,
    supplier_name VARCHAR(160) NOT NULL,
    email VARCHAR(150) NULL,
    phone VARCHAR(40) NULL,
    country_code CHAR(2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_suppliers_code UNIQUE (supplier_code),
    CONSTRAINT chk_suppliers_country_code
        CHECK (REGEXP_LIKE(country_code, '^[A-Z]{2}$'))
) ENGINE = InnoDB;

CREATE TABLE products (
    product_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(40) NOT NULL,
    product_name VARCHAR(160) NOT NULL,
    unit_of_measure VARCHAR(20) NOT NULL,
    product_type VARCHAR(20) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_products_sku UNIQUE (sku),
    CONSTRAINT chk_products_type
        CHECK (product_type IN ('FINISHED_GOOD', 'ASSEMBLY', 'COMPONENT'))
) ENGINE = InnoDB;

CREATE TABLE supplier_products (
    supplier_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    supplier_sku VARCHAR(60) NULL,
    standard_unit_price DECIMAL(14, 2) NOT NULL,
    lead_time_days INT NOT NULL DEFAULT 0,
    PRIMARY KEY (supplier_id, product_id),
    CONSTRAINT fk_supplier_products_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id),
    CONSTRAINT fk_supplier_products_product
        FOREIGN KEY (product_id) REFERENCES products (product_id),
    CONSTRAINT chk_supplier_products_price
        CHECK (standard_unit_price >= 0),
    CONSTRAINT chk_supplier_products_lead_time
        CHECK (lead_time_days >= 0)
) ENGINE = InnoDB;


-- ============================================================
-- 2. TON KHO, BOM VA CANH BAO
-- ============================================================

CREATE TABLE inventory (
    warehouse_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity_on_hand INT NOT NULL DEFAULT 0,
    quantity_reserved INT NOT NULL DEFAULT 0,
    reorder_point INT NOT NULL DEFAULT 0,
    last_updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (warehouse_id, product_id),
    CONSTRAINT fk_inventory_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (warehouse_id),
    CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_id) REFERENCES products (product_id),
    CONSTRAINT chk_inventory_quantities
        CHECK (
            quantity_on_hand >= 0
            AND quantity_reserved >= 0
            AND quantity_reserved <= quantity_on_hand
            AND reorder_point >= 0
        )
) ENGINE = InnoDB;

CREATE TABLE product_components (
    parent_product_id BIGINT NOT NULL,
    component_product_id BIGINT NOT NULL,
    quantity_required DECIMAL(14, 3) NOT NULL,
    PRIMARY KEY (parent_product_id, component_product_id),
    CONSTRAINT fk_product_components_parent
        FOREIGN KEY (parent_product_id) REFERENCES products (product_id),
    CONSTRAINT fk_product_components_component
        FOREIGN KEY (component_product_id) REFERENCES products (product_id),
    CONSTRAINT chk_product_components_not_self
        CHECK (parent_product_id <> component_product_id),
    CONSTRAINT chk_product_components_qty
        CHECK (quantity_required > 0)
) ENGINE = InnoDB;

CREATE TABLE restock_alerts (
    alert_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    warehouse_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    observed_quantity INT NOT NULL,
    reorder_point_snapshot INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(15) NOT NULL DEFAULT 'OPEN',
    open_alert_lock TINYINT
        AS (IF(status = 'OPEN', 1, NULL)) STORED,
    CONSTRAINT fk_restock_alerts_inventory
        FOREIGN KEY (warehouse_id, product_id)
        REFERENCES inventory (warehouse_id, product_id),
    CONSTRAINT chk_restock_alerts_status
        CHECK (status IN ('OPEN', 'ACKNOWLEDGED', 'RESOLVED')),
    CONSTRAINT uq_restock_alerts_one_open
        UNIQUE (warehouse_id, product_id, open_alert_lock)
) ENGINE = InnoDB;


-- ============================================================
-- 3. DAT HANG, VAN CHUYEN VA NHAN HANG
-- ============================================================

CREATE TABLE purchase_orders (
    purchase_order_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    po_number VARCHAR(30) NOT NULL,
    supplier_id BIGINT NOT NULL,
    destination_warehouse_id BIGINT NOT NULL,
    ordered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expected_at TIMESTAMP NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    CONSTRAINT uq_purchase_orders_number UNIQUE (po_number),
    CONSTRAINT fk_purchase_orders_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id),
    CONSTRAINT fk_purchase_orders_warehouse
        FOREIGN KEY (destination_warehouse_id)
        REFERENCES warehouses (warehouse_id),
    CONSTRAINT chk_purchase_orders_dates
        CHECK (expected_at IS NULL OR expected_at >= ordered_at),
    CONSTRAINT chk_purchase_orders_status
        CHECK (
            status IN (
                'DRAFT',
                'APPROVED',
                'PARTIALLY_RECEIVED',
                'RECEIVED',
                'CANCELLED'
            )
        )
) ENGINE = InnoDB;

CREATE TABLE purchase_order_items (
    purchase_order_id BIGINT NOT NULL,
    line_no INT NOT NULL,
    product_id BIGINT NOT NULL,
    ordered_quantity INT NOT NULL,
    unit_price DECIMAL(14, 2) NOT NULL,
    PRIMARY KEY (purchase_order_id, line_no),
    CONSTRAINT fk_po_items_order
        FOREIGN KEY (purchase_order_id)
        REFERENCES purchase_orders (purchase_order_id),
    CONSTRAINT fk_po_items_product
        FOREIGN KEY (product_id) REFERENCES products (product_id),
    CONSTRAINT chk_po_items_line_no
        CHECK (line_no > 0),
    CONSTRAINT chk_po_items_quantity
        CHECK (ordered_quantity > 0),
    CONSTRAINT chk_po_items_unit_price
        CHECK (unit_price >= 0)
) ENGINE = InnoDB;

CREATE TABLE shipments (
    shipment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    tracking_number VARCHAR(70) NOT NULL,
    purchase_order_id BIGINT NOT NULL,
    carrier_name VARCHAR(100) NULL,
    shipped_at TIMESTAMP NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PREPARING',
    CONSTRAINT uq_shipments_tracking UNIQUE (tracking_number),
    CONSTRAINT fk_shipments_order
        FOREIGN KEY (purchase_order_id)
        REFERENCES purchase_orders (purchase_order_id),
    CONSTRAINT chk_shipments_status
        CHECK (
            status IN (
                'PREPARING',
                'IN_TRANSIT',
                'DELIVERED',
                'EXCEPTION',
                'CANCELLED'
            )
        )
) ENGINE = InnoDB;

CREATE TABLE shipment_items (
    shipment_id BIGINT NOT NULL,
    line_no INT NOT NULL,
    shipped_quantity INT NOT NULL,
    PRIMARY KEY (shipment_id, line_no),
    CONSTRAINT fk_shipment_items_shipment
        FOREIGN KEY (shipment_id) REFERENCES shipments (shipment_id),
    CONSTRAINT chk_shipment_items_line_no
        CHECK (line_no > 0),
    CONSTRAINT chk_shipment_items_quantity
        CHECK (shipped_quantity > 0)
) ENGINE = InnoDB;

CREATE TABLE goods_receipts (
    receipt_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    receipt_number VARCHAR(30) NOT NULL,
    shipment_id BIGINT NOT NULL,
    received_at TIMESTAMP NOT NULL,
    posted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    received_by VARCHAR(100) NOT NULL,
    CONSTRAINT uq_goods_receipts_number UNIQUE (receipt_number),
    CONSTRAINT fk_goods_receipts_shipment
        FOREIGN KEY (shipment_id) REFERENCES shipments (shipment_id)
) ENGINE = InnoDB;

CREATE TABLE goods_receipt_items (
    receipt_id BIGINT NOT NULL,
    line_no INT NOT NULL,
    accepted_quantity INT NOT NULL,
    PRIMARY KEY (receipt_id, line_no),
    CONSTRAINT fk_goods_receipt_items_receipt
        FOREIGN KEY (receipt_id) REFERENCES goods_receipts (receipt_id),
    CONSTRAINT chk_goods_receipt_items_line_no
        CHECK (line_no > 0),
    CONSTRAINT chk_goods_receipt_items_quantity
        CHECK (accepted_quantity > 0)
) ENGINE = InnoDB;

SHOW TABLES;
USE scm_warehouse_perf;
SELECT
    TABLE_NAME,
    CONSTRAINT_NAME,
    CONSTRAINT_TYPE
FROM information_schema.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'scm_warehouse_perf'
ORDER BY TABLE_NAME, CONSTRAINT_TYPE;

USE scm_warehouse_perf;

-- 4. INDEXES TOI UU HIEU NANG TRA CUU

CREATE INDEX idx_inventory_product_id
ON inventory (product_id);

CREATE INDEX idx_purchase_orders_supplier_status
ON purchase_orders (supplier_id, status);

CREATE INDEX idx_shipments_purchase_order_id
ON shipments (purchase_order_id);

CREATE INDEX idx_goods_receipts_shipment_id
ON goods_receipts (shipment_id);

CREATE INDEX idx_product_components_component_id
ON product_components (component_product_id);

USE scm_warehouse_perf;
-- VIEW 1: TON KHO KHA DUNG
CREATE OR REPLACE VIEW v_inventory_availability AS
SELECT
    i.warehouse_id,
    w.warehouse_code,
    w.warehouse_name,
    i.product_id,
    p.sku,
    p.product_name,
    p.unit_of_measure,
    i.quantity_on_hand,
    i.quantity_reserved,
    (i.quantity_on_hand - i.quantity_reserved) AS quantity_available,
    i.reorder_point,
    ((i.quantity_on_hand - i.quantity_reserved)
        < i.reorder_point) AS is_below_reorder_point,
    i.last_updated_at
FROM inventory AS i
INNER JOIN warehouses AS w
    ON i.warehouse_id = w.warehouse_id
INNER JOIN products AS p
    ON i.product_id = p.product_id;
-- VIEW 2: THEO DOI TIEN DO DON DAT HANG
CREATE OR REPLACE VIEW v_purchase_order_fulfillment AS
SELECT
    po.purchase_order_id,
    po.po_number,
    po.status AS po_status,
    poi.line_no,
    p.sku,
    p.product_name,
    poi.ordered_quantity,
    COALESCE(ship_agg.total_shipped_quantity, 0)
        AS total_shipped_quantity,
    COALESCE(rcpt_agg.total_accepted_quantity, 0)
        AS total_accepted_quantity,
    (
        poi.ordered_quantity
        - COALESCE(rcpt_agg.total_accepted_quantity, 0)
    ) AS remaining_quantity
FROM purchase_orders AS po
INNER JOIN purchase_order_items AS poi
    ON po.purchase_order_id = poi.purchase_order_id
INNER JOIN products AS p
    ON poi.product_id = p.product_id
LEFT JOIN (
    SELECT
        s.purchase_order_id,
        si.line_no,
        SUM(si.shipped_quantity) AS total_shipped_quantity
    FROM shipments AS s
    INNER JOIN shipment_items AS si
        ON s.shipment_id = si.shipment_id
    WHERE s.status <> 'CANCELLED'
    GROUP BY
        s.purchase_order_id,
        si.line_no
) AS ship_agg
    ON poi.purchase_order_id = ship_agg.purchase_order_id
    AND poi.line_no = ship_agg.line_no
LEFT JOIN (
    SELECT
        s.purchase_order_id,
        gri.line_no,
        SUM(gri.accepted_quantity) AS total_accepted_quantity
    FROM shipments AS s
    INNER JOIN goods_receipts AS gr
        ON s.shipment_id = gr.shipment_id
    INNER JOIN goods_receipt_items AS gri
        ON gr.receipt_id = gri.receipt_id
    WHERE s.status <> 'CANCELLED'
    GROUP BY
        s.purchase_order_id,
        gri.line_no
) AS rcpt_agg
    ON poi.purchase_order_id = rcpt_agg.purchase_order_id
    AND poi.line_no = rcpt_agg.line_no;


SHOW FULL TABLES
FROM scm_warehouse_perf
WHERE TABLE_TYPE = 'VIEW';

USE scm_warehouse_perf;

DELIMITER $$
-- 1. BR-05: Sản phẩm thuộc dòng đơn mua phải nằm
-- trong danh mục của nhà cung cấp
CREATE TRIGGER trg_validate_po_item_supplier_bi
BEFORE INSERT ON purchase_order_items
FOR EACH ROW
BEGIN
    DECLARE v_supplier_id BIGINT;

    SELECT supplier_id
    INTO v_supplier_id
    FROM purchase_orders
    WHERE purchase_order_id = NEW.purchase_order_id;

    IF NOT EXISTS (
        SELECT 1
        FROM supplier_products
        WHERE supplier_id = v_supplier_id
          AND product_id = NEW.product_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'BR-05: San pham khong thuoc danh muc cung ung cua nha cung cap.';
    END IF;
END$$


-- 2. BR-07 & BR-08: Kiểm tra dòng giao hàng khớp dòng PO
-- và tổng giao không vượt tổng đặt
CREATE TRIGGER trg_validate_shipment_item_bi
BEFORE INSERT ON shipment_items
FOR EACH ROW
BEGIN
    DECLARE v_po_id BIGINT;
    DECLARE v_ordered_qty INT;
    DECLARE v_already_shipped INT;

    SELECT purchase_order_id
    INTO v_po_id
    FROM shipments
    WHERE shipment_id = NEW.shipment_id;

    SELECT ordered_quantity
    INTO v_ordered_qty
    FROM purchase_order_items
    WHERE purchase_order_id = v_po_id
      AND line_no = NEW.line_no
    FOR UPDATE;

    IF v_ordered_qty IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'BR-07: Dong giao hang khong ton tai tren don dat mua.';
    END IF;

    SELECT COALESCE(SUM(si.shipped_quantity), 0)
    INTO v_already_shipped
    FROM shipment_items AS si
    INNER JOIN shipments AS s
        ON si.shipment_id = s.shipment_id
    WHERE s.purchase_order_id = v_po_id
      AND si.line_no = NEW.line_no
      AND s.status <> 'CANCELLED';

    IF (v_already_shipped + NEW.shipped_quantity)
       > v_ordered_qty THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'BR-08: Tong so luong giao vuot qua so luong dat mua.';
    END IF;
END$$


-- 3. BR-09, BR-10, BR-11:
-- Đối chiếu dòng nhận với chuyến hàng và cộng tồn kho
CREATE TRIGGER trg_process_goods_receipt_item_bi
BEFORE INSERT ON goods_receipt_items
FOR EACH ROW
BEGIN
    DECLARE v_shipment_id BIGINT;
    DECLARE v_po_id BIGINT;
    DECLARE v_warehouse_id BIGINT;
    DECLARE v_product_id BIGINT;
    DECLARE v_shipped_qty INT;
    DECLARE v_already_accepted INT;

    SELECT shipment_id
    INTO v_shipment_id
    FROM goods_receipts
    WHERE receipt_id = NEW.receipt_id;

    SELECT shipped_quantity
    INTO v_shipped_qty
    FROM shipment_items
    WHERE shipment_id = v_shipment_id
      AND line_no = NEW.line_no
    FOR UPDATE;

    IF v_shipped_qty IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'BR-09: Dong nhan hang khong khop voi dong chuyen hang.';
    END IF;

    SELECT COALESCE(SUM(gri.accepted_quantity), 0)
    INTO v_already_accepted
    FROM goods_receipt_items AS gri
    INNER JOIN goods_receipts AS gr
        ON gri.receipt_id = gr.receipt_id
    WHERE gr.shipment_id = v_shipment_id
      AND gri.line_no = NEW.line_no;

    IF (v_already_accepted + NEW.accepted_quantity)
       > v_shipped_qty THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'BR-10: Tong so luong chap nhan vuot qua so luong da giao.';
    END IF;

    SELECT po.purchase_order_id,
           po.destination_warehouse_id
    INTO v_po_id, v_warehouse_id
    FROM shipments AS s
    INNER JOIN purchase_orders AS po
        ON s.purchase_order_id = po.purchase_order_id
    WHERE s.shipment_id = v_shipment_id;

    SELECT product_id
    INTO v_product_id
    FROM purchase_order_items
    WHERE purchase_order_id = v_po_id
      AND line_no = NEW.line_no;

    INSERT INTO inventory (
        warehouse_id,
        product_id,
        quantity_on_hand,
        quantity_reserved,
        reorder_point
    )
    VALUES (
        v_warehouse_id,
        v_product_id,
        NEW.accepted_quantity,
        0,
        0
    )
    ON DUPLICATE KEY UPDATE
        quantity_on_hand =
            quantity_on_hand + VALUES(quantity_on_hand);
END$$


-- 4. NFR-05: Phiếu nhận hàng bất biến sau khi ghi sổ
CREATE TRIGGER trg_immutable_goods_receipts_bu
BEFORE UPDATE ON goods_receipts
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
        'NFR-05: Phieu nhan hang da ghi so khong duoc phep sua.';
END$$

CREATE TRIGGER trg_immutable_goods_receipts_bd
BEFORE DELETE ON goods_receipts
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
        'NFR-05: Phieu nhan hang da ghi so khong duoc phep xoa.';
END$$

CREATE TRIGGER trg_immutable_goods_receipt_items_bu
BEFORE UPDATE ON goods_receipt_items
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
        'NFR-05: Chi tiet phieu nhan da ghi so khong duoc phep sua.';
END$$

CREATE TRIGGER trg_immutable_goods_receipt_items_bd
BEFORE DELETE ON goods_receipt_items
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
        'NFR-05: Chi tiet phieu nhan da ghi so khong duoc phep xoa.';
END$$


-- 5. BR-12: Ngăn chặn chu trình gián tiếp trong BOM
CREATE TRIGGER trg_prevent_bom_cycle_bi
BEFORE INSERT ON product_components
FOR EACH ROW
BEGIN
    DECLARE v_has_cycle INT DEFAULT 0;

    WITH RECURSIVE bom_ancestors (ancestor_id) AS (
        SELECT parent_product_id
        FROM product_components
        WHERE component_product_id = NEW.parent_product_id

        UNION

        SELECT pc.parent_product_id
        FROM product_components AS pc
        INNER JOIN bom_ancestors AS ba
            ON pc.component_product_id = ba.ancestor_id
    )
    SELECT COUNT(*)
    INTO v_has_cycle
    FROM bom_ancestors
    WHERE ancestor_id = NEW.component_product_id;

    IF v_has_cycle > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'BR-12: Phat hien chu trinh trong dinh muc nguyen vat lieu (BOM).';
    END IF;
END$$


-- 6. BR-13: Tự động tạo cảnh báo tồn kho thấp khi
-- khả dụng < reorder_point (INSERT mới)
CREATE TRIGGER trg_auto_create_restock_alert_ai
AFTER INSERT ON inventory
FOR EACH ROW
BEGIN
    DECLARE v_available INT;

    SET v_available =
        NEW.quantity_on_hand - NEW.quantity_reserved;

    IF v_available < NEW.reorder_point THEN
        INSERT IGNORE INTO restock_alerts (
            warehouse_id,
            product_id,
            observed_quantity,
            reorder_point_snapshot,
            status
        )
        VALUES (
            NEW.warehouse_id,
            NEW.product_id,
            v_available,
            NEW.reorder_point,
            'OPEN'
        );
    END IF;
END$$


-- 7. BR-13: Tự động tạo cảnh báo tồn kho thấp khi
-- khả dụng < reorder_point (UPDATE)
CREATE TRIGGER trg_auto_create_restock_alert_au
AFTER UPDATE ON inventory
FOR EACH ROW
BEGIN
    DECLARE v_available INT;

    SET v_available =
        NEW.quantity_on_hand - NEW.quantity_reserved;

    IF v_available < NEW.reorder_point THEN
        INSERT IGNORE INTO restock_alerts (
            warehouse_id,
            product_id,
            observed_quantity,
            reorder_point_snapshot,
            status
        )
        VALUES (
            NEW.warehouse_id,
            NEW.product_id,
            v_available,
            NEW.reorder_point,
            'OPEN'
        );
    END IF;
END$$
DELIMITER ;


USE scm_warehouse_perf;

DELIMITER $$

CREATE PROCEDURE sp_post_goods_receipt (
    IN p_receipt_number VARCHAR(30),
    IN p_shipment_id BIGINT,
    IN p_received_at TIMESTAMP,
    IN p_received_by VARCHAR(100),
    IN p_line_no INT,
    IN p_accepted_quantity INT
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_receipt_id BIGINT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO goods_receipts (
        receipt_number,
        shipment_id,
        received_at,
        received_by
    )
    VALUES (
        p_receipt_number,
        p_shipment_id,
        p_received_at,
        p_received_by
    );

    SET v_receipt_id = LAST_INSERT_ID();

    INSERT INTO goods_receipt_items (
        receipt_id,
        line_no,
        accepted_quantity
    )
    VALUES (
        v_receipt_id,
        p_line_no,
        p_accepted_quantity
    );

    COMMIT;
END$$

DELIMITER ;

SHOW PROCEDURE STATUS
WHERE Db = 'scm_warehouse_perf'
  AND Name = 'sp_post_goods_receipt';
