-- ============================================================
-- D. DO HIEU NANG (NFR-04 < 500 ms) tren scm_warehouse_perf
-- (100.000 dong ton kho, 10.000 don mua)
-- Chay tung cau EXPLAIN ANALYZE. Trong o ket qua, bam chuot phai vao o
-- "EXPLAIN" -> "Open Value in Viewer" de doc/copy ca ke hoach.
-- Thoi gian can ghi vao bao cao: so "actual time=...X..." o dong tren cung
-- (dong dau tien cua cay ke hoach), don vi ms.
-- ============================================================
USE scm_warehouse_perf;

-- ---------- PERF-01: ton kho kha dung cua 1 SKU tai 1 kho ----------
EXPLAIN ANALYZE
SELECT warehouse_code, sku, quantity_available
FROM v_inventory_availability
WHERE warehouse_code = 'WH-005'
  AND sku = 'SKU-02500';

-- ---------- PERF-02: canh bao ton kho dang mo (status = OPEN) ----------
EXPLAIN ANALYZE
SELECT alert_id, warehouse_id, product_id, observed_quantity, reorder_point_snapshot
FROM restock_alerts
WHERE status = 'OPEN';

-- ---------- PERF-03: phan ra BOM de quy cho 1 thanh pham ----------
EXPLAIN ANALYZE
WITH RECURSIVE bom_tree (
    level, parent_product_id, component_product_id, cumulative_quantity, path
) AS (
    SELECT 1, pc.parent_product_id, pc.component_product_id, pc.quantity_required,
           CAST(CONCAT(pc.parent_product_id, '->', pc.component_product_id) AS CHAR(500))
    FROM product_components AS pc
    INNER JOIN products AS p ON pc.parent_product_id = p.product_id
    WHERE p.sku = 'SKU-00001'
    UNION ALL
    SELECT bt.level + 1, pc.parent_product_id, pc.component_product_id,
           CAST(bt.cumulative_quantity * pc.quantity_required AS DECIMAL(14, 3)),
           CONCAT(bt.path, '->', pc.component_product_id)
    FROM product_components AS pc
    INNER JOIN bom_tree AS bt ON pc.parent_product_id = bt.component_product_id
    WHERE bt.level < 10
)
SELECT bt.level, p_parent.sku, p_comp.sku, bt.cumulative_quantity
FROM bom_tree AS bt
INNER JOIN products AS p_parent ON bt.parent_product_id = p_parent.product_id
INNER JOIN products AS p_comp ON bt.component_product_id = p_comp.product_id
ORDER BY bt.path;

-- ---------- PERF-04: ty le hoan thanh don mua theo nha cung cap ----------
EXPLAIN ANALYZE
WITH ordered_by_supplier AS (
    SELECT po.supplier_id,
           COUNT(DISTINCT po.purchase_order_id) AS total_orders,
           SUM(poi.ordered_quantity) AS total_ordered_units
    FROM purchase_orders AS po
    INNER JOIN purchase_order_items AS poi ON po.purchase_order_id = poi.purchase_order_id
    WHERE po.status IN ('APPROVED', 'PARTIALLY_RECEIVED', 'RECEIVED')
    GROUP BY po.supplier_id
),
accepted_by_supplier AS (
    SELECT po.supplier_id, SUM(gri.accepted_quantity) AS total_accepted_units
    FROM purchase_orders AS po
    INNER JOIN shipments AS sh ON po.purchase_order_id = sh.purchase_order_id
    INNER JOIN goods_receipts AS gr ON sh.shipment_id = gr.shipment_id
    INNER JOIN goods_receipt_items AS gri ON gr.receipt_id = gri.receipt_id
    WHERE po.status IN ('APPROVED', 'PARTIALLY_RECEIVED', 'RECEIVED')
      AND sh.status <> 'CANCELLED'
    GROUP BY po.supplier_id
)
SELECT s.supplier_code, s.supplier_name, obs.total_orders, obs.total_ordered_units,
       COALESCE(abs.total_accepted_units, 0) AS total_accepted_units,
       ROUND(COALESCE(abs.total_accepted_units, 0)
             / NULLIF(obs.total_ordered_units, 0) * 100, 2) AS fulfillment_rate_pct
FROM suppliers AS s
INNER JOIN ordered_by_supplier AS obs ON s.supplier_id = obs.supplier_id
LEFT JOIN accepted_by_supplier AS abs ON s.supplier_id = abs.supplier_id
ORDER BY fulfillment_rate_pct DESC;
