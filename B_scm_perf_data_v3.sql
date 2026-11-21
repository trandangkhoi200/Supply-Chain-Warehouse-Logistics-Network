
-- ============================================================
-- BUOC B: NAP DU LIEU LON vao scm_warehouse_perf
-- Chi chay tren schema MOI VA RONG (da chay xong Buoc A).
-- Ket qua: 20 kho, 50 NCC, 5.000 SKU, 10.000 dong NCC-san pham,
--          2.250 dong BOM, 100.000 dong ton kho, 10.000 don mua,
--          20.000 dong don mua, 4.000 chuyen hang, 4.000 phieu nhan.
-- Chay tung khoi mot (B0, B1, ...), doi xong khoi nay roi chay khoi sau.
-- ============================================================
USE scm_warehouse_perf;

-- ---------- B0. Bang so nguyen tam (se xoa o cuoi) ----------
SET SESSION cte_max_recursion_depth = 20000;
CREATE TABLE seq (n INT PRIMARY KEY);
INSERT INTO seq (n)
WITH RECURSIVE s (n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM s WHERE n < 10000
)
SELECT n FROM s;

-- ---------- B1. 20 kho (ten that theo thanh pho) ----------
INSERT INTO warehouses (warehouse_code, warehouse_name, address_line, city, country_code, is_active)
SELECT CONCAT('WH-', LPAD(n, 3, '0')),
       CONCAT('Kho ', ELT(1 + ((n - 1) MOD 10), 'Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Cần Thơ', 'Hải Phòng',
                          'Biên Hòa', 'Nha Trang', 'Huế', 'Vũng Tàu', 'Buôn Ma Thuột'),
              ' ', ((n - 1) DIV 10) + 1),
       CONCAT(n * 10, ' ', ELT(1 + (n MOD 4), 'Đường Nguyễn Văn Linh', 'Đường Lê Lợi',
                               'Đường Trần Hưng Đạo', 'Quốc lộ 1A')),
       ELT(1 + ((n - 1) MOD 10), 'Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Cần Thơ', 'Hải Phòng',
           'Biên Hòa', 'Nha Trang', 'Huế', 'Vũng Tàu', 'Buôn Ma Thuột'),
       'VN',
       TRUE
FROM seq WHERE n <= 20 ORDER BY n;

-- ---------- B2. 50 nha cung cap (ten cong ty that) ----------
INSERT INTO suppliers (supplier_code, supplier_name, email, phone, country_code, is_active)
SELECT CONCAT('SUP-', LPAD(n, 3, '0')),
       CONCAT('Công ty ', IF(n MOD 2 = 0, 'TNHH', 'CP'), ' ',
              ELT(1 + (n MOD 5), 'Linh Kiện Điện Tử', 'Cơ Khí Chính Xác', 'Vật Tư Công Nghiệp',
                  'Thiết Bị Điện', 'Nhựa Kỹ Thuật'), ' ',
              ELT(1 + (n MOD 8), 'An Phát', 'Hưng Thịnh', 'Minh Long', 'Đại Dương',
                  'Phú Quý', 'Việt Tiến', 'Hoàng Gia', 'Thành Công'),
              IF(n > 40, ' - Chi nhánh 2', '')),
       CONCAT('lienhe', n, '@example.vn'),
       CONCAT('09', LPAD(n, 8, '0')),
       'VN',
       TRUE
FROM seq WHERE n <= 50 ORDER BY n;

-- ---------- B3. 5.000 san pham co ten that ----------
-- 1..250: thanh pham | 251..1250: cum lap rap | 1251..5000: linh kien
-- Nhom hang = id MOD 5 (0: may tinh, 1: xe dap, 2: dien gia dung, 3: dien thoai, 4: noi that)
-- => chuoi BOM (id -> id+250 -> id+1000 / id+2000) luon cung nhom, nen hop ly:
--    vi du Xe dap -> Khung xe dap -> Oc vit inox M6
INSERT INTO products (sku, product_name, unit_of_measure, product_type, is_active)
SELECT CONCAT('SKU-', LPAD(n, 5, '0')),
       CASE
         WHEN n <= 250 THEN CONCAT(
             CASE n MOD 5
               WHEN 0 THEN ELT(1 + ((n DIV 5) MOD 3), 'Laptop', 'Máy tính để bàn', 'Máy chủ rack')
               WHEN 1 THEN ELT(1 + ((n DIV 5) MOD 4), 'Xe đạp địa hình', 'Xe đạp đua', 'Xe đạp thành phố', 'Xe đạp điện')
               WHEN 2 THEN ELT(1 + ((n DIV 5) MOD 6), 'Tủ lạnh', 'Máy giặt', 'Nồi cơm điện', 'Quạt điện', 'Máy hút bụi', 'Máy lạnh')
               WHEN 3 THEN ELT(1 + ((n DIV 5) MOD 4), 'Điện thoại thông minh', 'Máy tính bảng', 'Tai nghe Bluetooth', 'Đồng hồ thông minh')
               ELSE ELT(1 + ((n DIV 5) MOD 4), 'Bàn làm việc', 'Ghế văn phòng', 'Tủ hồ sơ', 'Kệ sách')
             END,
             ' ', ELT(1 + ((n DIV 7) MOD 5), 'Pro', 'Plus', 'Lite', 'Max', 'Eco'), ' M', LPAD(n, 4, '0'))
         WHEN n <= 1250 THEN CONCAT(
             CASE n MOD 5
               WHEN 0 THEN ELT(1 + ((n DIV 5) MOD 5), 'Bo mạch chủ', 'Khung vỏ máy', 'Cụm tản nhiệt', 'Bộ nguồn', 'Cụm bàn phím')
               WHEN 1 THEN ELT(1 + ((n DIV 5) MOD 5), 'Khung xe đạp', 'Cụm bánh xe', 'Bộ truyền động', 'Cụm phanh', 'Cụm tay lái')
               WHEN 2 THEN ELT(1 + ((n DIV 5) MOD 5), 'Cụm động cơ', 'Bo mạch điều khiển', 'Cụm máy nén', 'Thân vỏ', 'Cụm cánh quạt')
               WHEN 3 THEN ELT(1 + ((n DIV 5) MOD 5), 'Màn hình cảm ứng', 'Bộ pin', 'Bo mạch chính', 'Cụm camera', 'Vỏ khung kim loại')
               ELSE ELT(1 + ((n DIV 5) MOD 5), 'Khung thép', 'Mặt bàn gỗ', 'Cụm bánh xe ghế', 'Cụm tay vịn', 'Cụm ngăn kéo')
             END,
             ' loại ', ELT(1 + ((n DIV 7) MOD 3), 'A', 'B', 'C'), ' - ', LPAD(n, 4, '0'))
         ELSE CONCAT(
             CASE n MOD 5
               WHEN 0 THEN ELT(1 + ((n DIV 5) MOD 6), 'Ốc vít inox M3', 'Tụ điện', 'Điện trở', 'Cáp nối SATA', 'Keo tản nhiệt', 'Đầu nối USB')
               WHEN 1 THEN ELT(1 + ((n DIV 5) MOD 6), 'Ốc vít inox M6', 'Vòng bi', 'Xích xe', 'Líp xe', 'Lốp xe', 'Dây phanh')
               WHEN 2 THEN ELT(1 + ((n DIV 5) MOD 6), 'Dây điện', 'Cầu chì', 'Gioăng cao su', 'Lò xo', 'Ốc vít M4', 'Công tắc')
               WHEN 3 THEN ELT(1 + ((n DIV 5) MOD 6), 'Pin lithium', 'Cáp sạc USB-C', 'Loa nhỏ', 'Ốc vít M2', 'Ống kính', 'Đèn LED')
               ELSE ELT(1 + ((n DIV 5) MOD 6), 'Ốc vít gỗ', 'Bu lông M8', 'Bản lề', 'Tay nắm', 'Đệm mút', 'Ray trượt')
             END,
             ' - ', LPAD(n, 4, '0'))
       END,
       CASE WHEN n <= 250 THEN 'cái' WHEN n <= 1250 THEN 'bộ' ELSE 'hộp' END,
       CASE WHEN n <= 250 THEN 'FINISHED_GOOD'
            WHEN n <= 1250 THEN 'ASSEMBLY'
            ELSE 'COMPONENT' END,
       TRUE
FROM seq WHERE n <= 5000 ORDER BY n;

-- ---------- B4. Moi san pham co 2 nha cung cap (10.000 dong) ----------
INSERT INTO supplier_products (supplier_id, product_id, supplier_sku, standard_unit_price, lead_time_days)
SELECT (n MOD 50) + 1, n, CONCAT('A-', n),
       10000 + ((n * 37) MOD 90000), 1 + (n MOD 14)
FROM seq WHERE n <= 5000;

INSERT INTO supplier_products (supplier_id, product_id, supplier_sku, standard_unit_price, lead_time_days)
SELECT ((n + 17) MOD 50) + 1, n, CONCAT('B-', n),
       10000 + ((n * 53 + 11) MOD 90000), 1 + ((n + 5) MOD 14)
FROM seq WHERE n <= 5000;

-- ---------- B5. BOM nhieu cap (thanh pham -> cum lap rap -> linh kien) ----------
INSERT INTO product_components (parent_product_id, component_product_id, quantity_required)
SELECT n, n + 250, 1 + (n MOD 3) FROM seq WHERE n <= 250 ORDER BY n;

INSERT INTO product_components (parent_product_id, component_product_id, quantity_required)
SELECT n, n + 1000, 2 + (n MOD 4) FROM seq WHERE n BETWEEN 251 AND 1250 ORDER BY n;

INSERT INTO product_components (parent_product_id, component_product_id, quantity_required)
SELECT n, n + 2000, 1 + (n MOD 5) FROM seq WHERE n BETWEEN 251 AND 1250 ORDER BY n;

-- ---------- B6. 100.000 dong ton kho (20 kho x 5.000 SKU), chia 4 dot ----------
-- Trigger tu tao canh bao (restock_alerts) cho dong nao thap hon nguong.
INSERT INTO inventory (warehouse_id, product_id, quantity_on_hand, quantity_reserved, reorder_point)
SELECT warehouse_id, product_id, qoh,
       FLOOR(qoh * ((warehouse_id + product_id) MOD 4) / 10),
       10 + ((product_id * 7) MOD 120)
FROM (
    SELECT w.warehouse_id, p.product_id,
           10 + ((w.warehouse_id * 131 + p.product_id * 17) MOD 491) AS qoh
    FROM warehouses AS w CROSS JOIN products AS p
    WHERE w.warehouse_id BETWEEN 1 AND 5
) AS x;

INSERT INTO inventory (warehouse_id, product_id, quantity_on_hand, quantity_reserved, reorder_point)
SELECT warehouse_id, product_id, qoh,
       FLOOR(qoh * ((warehouse_id + product_id) MOD 4) / 10),
       10 + ((product_id * 7) MOD 120)
FROM (
    SELECT w.warehouse_id, p.product_id,
           10 + ((w.warehouse_id * 131 + p.product_id * 17) MOD 491) AS qoh
    FROM warehouses AS w CROSS JOIN products AS p
    WHERE w.warehouse_id BETWEEN 6 AND 10
) AS x;

INSERT INTO inventory (warehouse_id, product_id, quantity_on_hand, quantity_reserved, reorder_point)
SELECT warehouse_id, product_id, qoh,
       FLOOR(qoh * ((warehouse_id + product_id) MOD 4) / 10),
       10 + ((product_id * 7) MOD 120)
FROM (
    SELECT w.warehouse_id, p.product_id,
           10 + ((w.warehouse_id * 131 + p.product_id * 17) MOD 491) AS qoh
    FROM warehouses AS w CROSS JOIN products AS p
    WHERE w.warehouse_id BETWEEN 11 AND 15
) AS x;

INSERT INTO inventory (warehouse_id, product_id, quantity_on_hand, quantity_reserved, reorder_point)
SELECT warehouse_id, product_id, qoh,
       FLOOR(qoh * ((warehouse_id + product_id) MOD 4) / 10),
       10 + ((product_id * 7) MOD 120)
FROM (
    SELECT w.warehouse_id, p.product_id,
           10 + ((w.warehouse_id * 131 + p.product_id * 17) MOD 491) AS qoh
    FROM warehouses AS w CROSS JOIN products AS p
    WHERE w.warehouse_id BETWEEN 16 AND 20
) AS x;

-- ---------- B7. 10.000 don dat mua ----------
INSERT INTO purchase_orders (po_number, supplier_id, destination_warehouse_id, ordered_at, status)
SELECT CONCAT('PO-', LPAD(n, 6, '0')),
       (n MOD 50) + 1,
       (n MOD 20) + 1,
       DATE_ADD('2026-01-01 08:00:00', INTERVAL (n MOD 300) DAY),
       ELT(1 + (n MOD 10), 'DRAFT', 'APPROVED', 'APPROVED', 'APPROVED', 'APPROVED',
           'PARTIALLY_RECEIVED', 'PARTIALLY_RECEIVED', 'RECEIVED', 'RECEIVED', 'CANCELLED')
FROM seq ORDER BY n;

-- ---------- B8. 20.000 dong don mua (moi don 2 dong, san pham thuoc danh muc cua NCC) ----------
INSERT INTO purchase_order_items (purchase_order_id, line_no, product_id, ordered_quantity, unit_price)
SELECT n, 1, p, 10 + ((n * 13 + 7) MOD 190), 10000 + ((p * 37) MOD 90000)
FROM (
    SELECT n, (n MOD 50) + 50 * (1 + (n MOD 99)) AS p FROM seq
) AS x ORDER BY n;

INSERT INTO purchase_order_items (purchase_order_id, line_no, product_id, ordered_quantity, unit_price)
SELECT n, 2, p, 10 + ((n * 13 + 21) MOD 190), 10000 + ((p * 53 + 11) MOD 90000)
FROM (
    SELECT n, (((n MOD 50) + 33) MOD 50) + 50 * (1 + (n MOD 99)) AS p FROM seq
) AS x ORDER BY n;

-- ---------- B9. Chuyen hang cho cac don PARTIALLY_RECEIVED / RECEIVED (4.000 chuyen) ----------
INSERT INTO shipments (tracking_number, purchase_order_id, carrier_name, shipped_at, status)
SELECT CONCAT('TRK-', LPAD(purchase_order_id, 6, '0')),
       purchase_order_id,
       ELT(1 + (purchase_order_id MOD 3), 'Viettel Post', 'GHTK Freight', 'Giao Hang Nhanh'),
       DATE_ADD(ordered_at, INTERVAL 3 DAY),
       'DELIVERED'
FROM purchase_orders
WHERE status IN ('PARTIALLY_RECEIVED', 'RECEIVED')
ORDER BY purchase_order_id;

-- (Dung bang tam de tranh loi 1442 do trigger co SELECT ... FOR UPDATE)
CREATE TABLE tmp_ship AS
SELECT s.shipment_id, poi.line_no,
       CASE WHEN po.status = 'RECEIVED' THEN poi.ordered_quantity
            ELSE FLOOR(poi.ordered_quantity * 0.6) END AS shipped_quantity
FROM shipments AS s
INNER JOIN purchase_orders AS po ON po.purchase_order_id = s.purchase_order_id
INNER JOIN purchase_order_items AS poi ON poi.purchase_order_id = po.purchase_order_id;

INSERT INTO shipment_items (shipment_id, line_no, shipped_quantity)
SELECT shipment_id, line_no, shipped_quantity FROM tmp_ship ORDER BY shipment_id, line_no;

DROP TABLE tmp_ship;

-- ---------- B10. Phieu nhan hang (trigger se tu cong ton kho) ----------
INSERT INTO goods_receipts (receipt_number, shipment_id, received_at, received_by)
SELECT CONCAT('GR-', LPAD(shipment_id, 6, '0')),
       shipment_id,
       DATE_ADD(shipped_at, INTERVAL 2 DAY),
       'NV_NHAP_01'
FROM shipments ORDER BY shipment_id;

CREATE TABLE tmp_rcpt AS
SELECT gr.receipt_id, si.line_no,
       CASE WHEN po.status = 'RECEIVED' THEN si.shipped_quantity
            ELSE FLOOR(si.shipped_quantity * 0.9) END AS accepted_quantity
FROM goods_receipts AS gr
INNER JOIN shipment_items AS si ON si.shipment_id = gr.shipment_id
INNER JOIN shipments AS s ON s.shipment_id = gr.shipment_id
INNER JOIN purchase_orders AS po ON po.purchase_order_id = s.purchase_order_id;

INSERT INTO goods_receipt_items (receipt_id, line_no, accepted_quantity)
SELECT receipt_id, line_no, accepted_quantity FROM tmp_rcpt ORDER BY receipt_id, line_no;

DROP TABLE tmp_rcpt;

-- ---------- B11. Don dep va cap nhat thong ke ----------
DROP TABLE seq;
ANALYZE TABLE warehouses, suppliers, products, supplier_products, inventory,
              product_components, restock_alerts, purchase_orders,
              purchase_order_items, shipments, shipment_items,
              goods_receipts, goods_receipt_items;

-- ---------- B12. KIEM TRA SO DONG (chup man hinh cai nay dua vao bao cao) ----------
SELECT 'warehouses' AS bang, COUNT(*) AS so_dong FROM warehouses
UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'supplier_products', COUNT(*) FROM supplier_products
UNION ALL SELECT 'product_components', COUNT(*) FROM product_components
UNION ALL SELECT 'inventory', COUNT(*) FROM inventory
UNION ALL SELECT 'restock_alerts', COUNT(*) FROM restock_alerts
UNION ALL SELECT 'purchase_orders', COUNT(*) FROM purchase_orders
UNION ALL SELECT 'purchase_order_items', COUNT(*) FROM purchase_order_items
UNION ALL SELECT 'shipments', COUNT(*) FROM shipments
UNION ALL SELECT 'shipment_items', COUNT(*) FROM shipment_items
UNION ALL SELECT 'goods_receipts', COUNT(*) FROM goods_receipts
UNION ALL SELECT 'goods_receipt_items', COUNT(*) FROM goods_receipt_items;
-- Ky vong: 20 / 50 / 5000 / 10000 / 2250 / 100000 / (tuy du lieu) / 10000 / 20000 / 4000 / 8000 / 4000 / 8000
