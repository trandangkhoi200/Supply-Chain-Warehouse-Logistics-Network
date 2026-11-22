-- CHỈ CHẠY TRÊN MYSQL LOCAL VỚI SCHEMA DEMO. Thay MAT_KHAU_MANH_CUA_EM.
-- Lưu ý: nếu chạy codechinh.sql mặc định, schema là scm_warehouse_test.
-- Đổi tên schema bên dưới nếu em dùng một bản sao demo khác.
CREATE USER IF NOT EXISTS 'robot_demo'@'localhost'
IDENTIFIED BY 'MAT_KHAU_MANH_CUA_EM';

GRANT SELECT ON scm_warehouse_test.products TO 'robot_demo'@'localhost';
GRANT SELECT ON scm_warehouse_test.warehouses TO 'robot_demo'@'localhost';
GRANT SELECT ON scm_warehouse_test.inventory TO 'robot_demo'@'localhost';
GRANT SELECT ON scm_warehouse_test.purchase_orders TO 'robot_demo'@'localhost';
GRANT SELECT ON scm_warehouse_test.purchase_order_items TO 'robot_demo'@'localhost';
GRANT SELECT ON scm_warehouse_test.shipments TO 'robot_demo'@'localhost';
GRANT SELECT ON scm_warehouse_test.shipment_items TO 'robot_demo'@'localhost';
GRANT SELECT ON scm_warehouse_test.goods_receipts TO 'robot_demo'@'localhost';
GRANT SELECT ON scm_warehouse_test.goods_receipt_items TO 'robot_demo'@'localhost';
GRANT SELECT ON scm_warehouse_test.v_inventory_availability TO 'robot_demo'@'localhost';
GRANT SELECT ON scm_warehouse_test.v_purchase_order_fulfillment TO 'robot_demo'@'localhost';
-- Chỉ cấp EXECUTE khi nhóm muốn demo thực sự ghi sổ (có thể ảnh hưởng tồn kho).
-- GRANT EXECUTE ON PROCEDURE scm_warehouse_test.sp_post_goods_receipt TO 'robot_demo'@'localhost';
