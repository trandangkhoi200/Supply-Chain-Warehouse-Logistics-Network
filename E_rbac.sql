-- ============================================================
-- E. PHAN QUYEN RBAC (muc 5.2) tren scm_warehouse_perf
-- PHAN 1: chay bang tai khoan root.  PHAN 2: thu bang tung tai khoan.
-- ============================================================
USE scm_warehouse_perf;

-- ---------- PHAN 1A. Tao 5 vai tro ----------
CREATE ROLE IF NOT EXISTS
    'role_warehouse_clerk', 'role_purchasing_staff', 'role_receiving_clerk',
    'role_logistics_coord', 'role_scm_manager';

-- ---------- PHAN 1B. Cap quyen ----------
-- Nhan vien kho (UR-01)
GRANT SELECT ON scm_warehouse_perf.warehouses TO 'role_warehouse_clerk';
GRANT SELECT ON scm_warehouse_perf.products TO 'role_warehouse_clerk';
GRANT SELECT, UPDATE (quantity_reserved) ON scm_warehouse_perf.inventory TO 'role_warehouse_clerk';
GRANT SELECT ON scm_warehouse_perf.v_inventory_availability TO 'role_warehouse_clerk';
GRANT SELECT, UPDATE (status) ON scm_warehouse_perf.restock_alerts TO 'role_warehouse_clerk';

-- Nhan vien mua hang (UR-02)
GRANT SELECT ON scm_warehouse_perf.warehouses TO 'role_purchasing_staff';
GRANT SELECT ON scm_warehouse_perf.products TO 'role_purchasing_staff';
GRANT SELECT, INSERT, UPDATE, DELETE ON scm_warehouse_perf.suppliers TO 'role_purchasing_staff';
GRANT SELECT, INSERT, UPDATE, DELETE ON scm_warehouse_perf.supplier_products TO 'role_purchasing_staff';
GRANT SELECT, INSERT, UPDATE, DELETE ON scm_warehouse_perf.purchase_orders TO 'role_purchasing_staff';
GRANT SELECT, INSERT, UPDATE, DELETE ON scm_warehouse_perf.purchase_order_items TO 'role_purchasing_staff';
GRANT SELECT ON scm_warehouse_perf.v_purchase_order_fulfillment TO 'role_purchasing_staff';

-- Nhan vien nhan hang (UR-03)
GRANT SELECT ON scm_warehouse_perf.purchase_orders TO 'role_receiving_clerk';
GRANT SELECT ON scm_warehouse_perf.shipments TO 'role_receiving_clerk';
GRANT SELECT ON scm_warehouse_perf.shipment_items TO 'role_receiving_clerk';
GRANT SELECT, INSERT, UPDATE, DELETE ON scm_warehouse_perf.goods_receipts TO 'role_receiving_clerk';
GRANT SELECT, INSERT, UPDATE, DELETE ON scm_warehouse_perf.goods_receipt_items TO 'role_receiving_clerk';

-- Nhan vien logistics (UR-04)
GRANT SELECT ON scm_warehouse_perf.purchase_orders TO 'role_logistics_coord';
GRANT SELECT ON scm_warehouse_perf.purchase_order_items TO 'role_logistics_coord';
GRANT SELECT, INSERT, UPDATE, DELETE ON scm_warehouse_perf.shipments TO 'role_logistics_coord';
GRANT SELECT, INSERT, UPDATE, DELETE ON scm_warehouse_perf.shipment_items TO 'role_logistics_coord';

-- Nguoi quan ly (UR-05)
GRANT SELECT ON scm_warehouse_perf.* TO 'role_scm_manager';
GRANT INSERT, UPDATE, DELETE ON scm_warehouse_perf.product_components TO 'role_scm_manager';
GRANT UPDATE (reorder_point) ON scm_warehouse_perf.inventory TO 'role_scm_manager';
GRANT UPDATE (status) ON scm_warehouse_perf.restock_alerts TO 'role_scm_manager';

-- ---------- PHAN 1C. Thu hoi quyen nhay cam (REVOKE) ----------
REVOKE INSERT, UPDATE, DELETE ON scm_warehouse_perf.goods_receipts FROM 'role_receiving_clerk';
REVOKE INSERT, UPDATE, DELETE ON scm_warehouse_perf.goods_receipt_items FROM 'role_receiving_clerk';
REVOKE DELETE ON scm_warehouse_perf.suppliers FROM 'role_purchasing_staff';
REVOKE DELETE ON scm_warehouse_perf.supplier_products FROM 'role_purchasing_staff';
REVOKE DELETE ON scm_warehouse_perf.purchase_orders FROM 'role_purchasing_staff';
REVOKE DELETE ON scm_warehouse_perf.purchase_order_items FROM 'role_purchasing_staff';
REVOKE DELETE ON scm_warehouse_perf.shipments FROM 'role_logistics_coord';
REVOKE DELETE ON scm_warehouse_perf.shipment_items FROM 'role_logistics_coord';

GRANT EXECUTE ON PROCEDURE scm_warehouse_perf.sp_post_goods_receipt TO 'role_receiving_clerk';

-- ---------- PHAN 1D. Tao tai khoan mau va gan vai tro ----------
CREATE USER IF NOT EXISTS 'nv_kho_01'@'localhost'  IDENTIFIED BY 'Kho@2026Strong!';
CREATE USER IF NOT EXISTS 'nv_nhap_01'@'localhost' IDENTIFIED BY 'Nhap@2026Strong!';
CREATE USER IF NOT EXISTS 'ql_kho_01'@'localhost'  IDENTIFIED BY 'QuanLy@2026Strong!';

GRANT 'role_warehouse_clerk' TO 'nv_kho_01'@'localhost';
GRANT 'role_receiving_clerk' TO 'nv_nhap_01'@'localhost';
GRANT 'role_scm_manager'     TO 'ql_kho_01'@'localhost';

SET DEFAULT ROLE ALL TO 'nv_kho_01'@'localhost', 'nv_nhap_01'@'localhost', 'ql_kho_01'@'localhost';
FLUSH PRIVILEGES;

-- Xem quyen (chup man hinh):
SHOW GRANTS FOR 'nv_nhap_01'@'localhost' USING 'role_receiving_clerk';

-- ============================================================
-- PHAN 2. THU QUYEN. Moi muc: mo ket noi MOI trong Workbench bang tai khoan do
-- (Database > Manage Connections > New, user + mat khau o tren, host localhost),
-- chay cau lenh, chup man hinh ket qua.
-- ============================================================

-- ===== Dang nhap nv_nhap_01 (nhan vien nhan hang) =====
USE scm_warehouse_perf;
-- (a) Ghi truc tiep vao phieu nhan -> PHAI BI TU CHOI (ERROR 1142 ... command denied)
INSERT INTO goods_receipts (receipt_number, shipment_id, received_at, received_by)
VALUES ('GR-RBAC-DIRECT', 1, UTC_TIMESTAMP(), 'NV_NHAP_01');
-- (b) Ghi so qua procedure -> PHAI THANH CONG (chuyen hang 1, dong 1, con du 5 don vi)
CALL sp_post_goods_receipt('GR-RBAC-01', 1, UTC_TIMESTAMP(), 'NV_NHAP_01', 1, 1);

-- ===== Dang nhap nv_kho_01 (nhan vien kho) =====
USE scm_warehouse_perf;
-- (c) Doc ton kho -> PHAI THANH CONG
SELECT warehouse_code, sku, quantity_available
FROM v_inventory_availability WHERE warehouse_code = 'WH-001' AND sku = 'SKU-00001';
-- (d) Sua so luong giu cho -> PHAI THANH CONG (giu nguyen gia tri)
UPDATE inventory SET quantity_reserved = quantity_reserved
WHERE warehouse_id = 1 AND product_id = 1;
-- (e) Sua so luong ton thuc te -> PHAI BI TU CHOI (ERROR 1143 ... column denied)
UPDATE inventory SET quantity_on_hand = 999 WHERE warehouse_id = 1 AND product_id = 1;

-- ===== Dang nhap ql_kho_01 (nguoi quan ly) =====
USE scm_warehouse_perf;
-- (f) Doc toan bo -> PHAI THANH CONG
SELECT COUNT(*) FROM purchase_orders;
-- (g) Chinh nguong dat hang lai -> PHAI THANH CONG (giu nguyen gia tri)
UPDATE inventory SET reorder_point = reorder_point WHERE warehouse_id = 1 AND product_id = 1;
-- (h) Xoa chung tu goc -> PHAI BI TU CHOI (ERROR 1142 ... command denied)
DELETE FROM purchase_orders WHERE purchase_order_id = 1;
