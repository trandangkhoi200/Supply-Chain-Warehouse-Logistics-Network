"""ROBOT Phase 4 – lightweight Flask frontend to the original MySQL schema.
Local classroom demo; do not expose directly to the public Internet.
"""
import hmac
import os
import secrets
from datetime import datetime, timezone
from functools import wraps

import pymysql
from dotenv import load_dotenv
from flask import Flask, flash, redirect, render_template, request, session, url_for

load_dotenv()
app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY") or secrets.token_hex(32)
app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax")

DATABASE = os.getenv("MYSQL_DATABASE", "scm_warehouse_test")
ALLOW_POST = os.getenv("ALLOW_RECEIPT_POSTING", "false").strip().lower() == "true"


def connect():
    return pymysql.connect(
        host=os.getenv("MYSQL_HOST", "127.0.0.1"),
        port=int(os.getenv("MYSQL_PORT", "3306")),
        user=os.getenv("MYSQL_USER", "robot_demo"),
        password=os.getenv("MYSQL_PASSWORD", ""),
        database=DATABASE,
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=False,
        connect_timeout=5,
        read_timeout=15,
        write_timeout=15,
    )


def fetch(sql, params=()):
    db = connect()
    try:
        with db.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()
    finally:
        db.close()


def csrf_token():
    if "csrf_token" not in session:
        session["csrf_token"] = secrets.token_urlsafe(32)
    return session["csrf_token"]


app.jinja_env.globals["csrf_token"] = csrf_token


def verify_csrf(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        token = request.form.get("csrf_token", "")
        if not hmac.compare_digest(token, session.get("csrf_token", "")):
            flash("Phiên biểu mẫu không hợp lệ. Vui lòng tải lại trang.", "danger")
            return redirect(url_for("receiving"))
        return f(*args, **kwargs)
    return wrapper


@app.context_processor
def globals_for_templates():
    return {"database_name": DATABASE, "posting_enabled": ALLOW_POST}


@app.route("/")
def dashboard():
    try:
        inventory = fetch("SELECT COUNT(*) AS count FROM inventory")[0]["count"]
        products = fetch("SELECT COUNT(*) AS count FROM products")[0]["count"]
        purchase_orders = fetch("SELECT COUNT(*) AS count FROM purchase_orders")[0]["count"]
        low_stock = fetch("SELECT COUNT(*) AS count FROM v_inventory_availability WHERE is_below_reorder_point = 1")[0]["count"]
        alerts = fetch("""SELECT warehouse_code, sku, product_name, quantity_available, reorder_point
                           FROM v_inventory_availability WHERE is_below_reorder_point = 1
                           ORDER BY quantity_available ASC LIMIT 8""")
        return render_template("dashboard.html", page="dashboard", stats={"inventory": inventory, "products": products, "orders": purchase_orders, "low": low_stock}, alerts=alerts)
    except pymysql.MySQLError as exc:
        app.logger.warning("Dashboard database error: %s", exc)
        return render_template("error.html", page="dashboard", detail="Không kết nối được MySQL hoặc chưa nạp đầy đủ 13 bảng và 2 VIEW. Kiểm tra tệp .env và README."), 503


@app.route("/inventory")
def inventory():
    keyword = request.args.get("q", "").strip()[:80]
    warehouse = request.args.get("warehouse", "").strip()
    low_only = request.args.get("low") == "1"
    where, args = [], []
    if keyword:
        where.append("(sku LIKE %s OR product_name LIKE %s)")
        args.extend([f"%{keyword}%", f"%{keyword}%"])
    if warehouse:
        try:
            warehouse_id = int(warehouse)
        except ValueError:
            warehouse_id = -1
        where.append("warehouse_id = %s")
        args.append(warehouse_id)
    if low_only:
        where.append("is_below_reorder_point = 1")
    sql = """SELECT warehouse_code, warehouse_name, sku, product_name, unit_of_measure,
                    quantity_on_hand, quantity_reserved, quantity_available,
                    reorder_point, is_below_reorder_point
             FROM v_inventory_availability"""
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY warehouse_code, sku LIMIT 250"
    try:
        warehouses = fetch("SELECT warehouse_id, warehouse_code, warehouse_name FROM warehouses ORDER BY warehouse_code")
        rows = fetch(sql, tuple(args))
        # A receipt's accepted quantity can be shown from existing records.
        # Historical before/after balances are NOT reconstructed; only balances
        # observed during a successful posting in this Flask browser session count.
        selected_receipt = request.args.get("receipt", "").strip()[:30]
        receipt_detail = None
        comparison = None
        if selected_receipt:
            detail_sql = """SELECT gr.receipt_number, gr.received_at, gri.accepted_quantity,
                                   p.sku, p.product_name, w.warehouse_id, w.warehouse_code
                            FROM goods_receipts AS gr
                            JOIN goods_receipt_items AS gri ON gri.receipt_id = gr.receipt_id
                            JOIN shipments AS s ON s.shipment_id = gr.shipment_id
                            JOIN purchase_orders AS po ON po.purchase_order_id = s.purchase_order_id
                            JOIN purchase_order_items AS poi
                              ON poi.purchase_order_id = po.purchase_order_id
                             AND poi.line_no = gri.line_no
                            JOIN products AS p ON p.product_id = poi.product_id
                            JOIN warehouses AS w ON w.warehouse_id = po.destination_warehouse_id
                            WHERE gr.receipt_number = %s AND p.sku = %s
                              AND w.warehouse_id = %s LIMIT 1"""
            try:
                selected_wh = int(warehouse)
            except (TypeError, ValueError):
                selected_wh = -1
            matched = fetch(detail_sql, (selected_receipt, keyword, selected_wh))
            if matched:
                receipt_detail = matched[0]
        last_posted = session.get("inventory_receipt_comparison")
        if last_posted and last_posted.get("sku") == keyword and str(last_posted.get("warehouse_id")) == warehouse:
            if not selected_receipt or selected_receipt == last_posted.get("receipt_number"):
                # Compare only with a legitimate stored receipt, and never with an
                # unrelated SKU/warehouse passed by the browser.
                if selected_receipt or any(x["sku"] == keyword and x["warehouse_code"] == last_posted.get("warehouse_code") for x in rows):
                    comparison = last_posted
        return render_template("inventory.html", page="inventory", rows=rows,
                               warehouses=warehouses, selected_warehouse=warehouse,
                               keyword=keyword, low_only=low_only,
                               receipt_detail=receipt_detail, comparison=comparison)
    except pymysql.MySQLError:
        return render_template("error.html", page="inventory", detail="Không đọc được dữ liệu tồn kho. Kiểm tra quyền SELECT trên VIEW v_inventory_availability."), 503


@app.route("/orders")
def orders():
    keyword = request.args.get("q", "").strip()[:80]
    sql = """SELECT po_number, po_status, line_no, sku, product_name,
                    ordered_quantity, total_shipped_quantity, total_accepted_quantity, remaining_quantity
             FROM v_purchase_order_fulfillment"""
    args = ()
    if keyword:
        sql += " WHERE po_number LIKE %s OR sku LIKE %s"
        args = (f"%{keyword}%", f"%{keyword}%")
    sql += " ORDER BY po_number DESC, line_no LIMIT 250"
    try:
        rows = fetch(sql, args)
        return render_template("orders.html", page="orders", rows=rows, keyword=keyword)
    except pymysql.MySQLError:
        return render_template("error.html", page="orders", detail="Không đọc được tiến độ đơn mua. Kiểm tra VIEW v_purchase_order_fulfillment."), 503



@app.route("/receipt-history")
def receipt_history():
    """Read-only lookup of accepted inbound receipts and their destination warehouses."""
    keyword = request.args.get("q", "").strip()[:80]
    warehouse = request.args.get("warehouse", "").strip()
    filters, args = [], []
    if keyword:
        filters.append("(gr.receipt_number LIKE %s OR p.sku LIKE %s OR p.product_name LIKE %s OR po.po_number LIKE %s OR s.tracking_number LIKE %s)")
        args.extend([f"%{keyword}%"] * 5)
    if warehouse:
        try:
            warehouse_id = int(warehouse)
        except ValueError:
            warehouse_id = -1
        filters.append("w.warehouse_id = %s")
        args.append(warehouse_id)

    sql = """SELECT gr.receipt_number, gr.received_at, gr.received_by,
                    gr.shipment_id, s.tracking_number, po.po_number,
                    gri.line_no, p.sku, p.product_name, gri.accepted_quantity,
                    w.warehouse_id, w.warehouse_code, w.warehouse_name
             FROM goods_receipts AS gr
             JOIN goods_receipt_items AS gri ON gri.receipt_id = gr.receipt_id
             JOIN shipments AS s ON s.shipment_id = gr.shipment_id
             JOIN purchase_orders AS po ON po.purchase_order_id = s.purchase_order_id
             JOIN purchase_order_items AS poi
               ON poi.purchase_order_id = po.purchase_order_id AND poi.line_no = gri.line_no
             JOIN products AS p ON p.product_id = poi.product_id
             JOIN warehouses AS w ON w.warehouse_id = po.destination_warehouse_id"""
    if filters:
        sql += " WHERE " + " AND ".join(filters)
    sql += " ORDER BY gr.received_at DESC, gr.receipt_id DESC, gri.line_no LIMIT 250"
    try:
        warehouses = fetch("SELECT warehouse_id, warehouse_code, warehouse_name FROM warehouses ORDER BY warehouse_code")
        rows = fetch(sql, tuple(args))
        return render_template("receipt_history.html", page="receipt_history", rows=rows,
                               warehouses=warehouses, keyword=keyword, selected_warehouse=warehouse)
    except pymysql.MySQLError as exc:
        app.logger.warning("Receipt history query error: %s", exc)
        return render_template("error.html", page="receipt_history", detail="Không đọc được lịch sử nhận hàng. Kiểm tra quyền SELECT và các bảng chứng từ trong MySQL."), 503

def receiving_data():
    shipments = fetch("""SELECT s.shipment_id, s.tracking_number, po.po_number,
                                s.status AS shipment_status
                         FROM shipments s JOIN purchase_orders po
                           ON s.purchase_order_id = po.purchase_order_id
                         ORDER BY s.shipment_id DESC LIMIT 100""")
    items = fetch("""SELECT si.shipment_id, si.line_no, p.sku, p.product_name,
                            w.warehouse_code, COALESCE(inv.quantity_on_hand, 0) AS quantity_on_hand,
                            si.shipped_quantity,
                            (si.shipped_quantity - COALESCE(r.accepted, 0)) AS remaining_to_accept
                     FROM shipment_items si
                     JOIN shipments s ON s.shipment_id = si.shipment_id
                     JOIN purchase_orders po ON po.purchase_order_id = s.purchase_order_id
                     JOIN warehouses w ON w.warehouse_id = po.destination_warehouse_id
                     JOIN purchase_order_items poi
                       ON poi.purchase_order_id = s.purchase_order_id AND poi.line_no = si.line_no
                     JOIN products p ON p.product_id = poi.product_id
                     LEFT JOIN inventory inv ON inv.warehouse_id = w.warehouse_id
                       AND inv.product_id = p.product_id
                     LEFT JOIN (
                        SELECT gr.shipment_id, gri.line_no, SUM(gri.accepted_quantity) AS accepted
                        FROM goods_receipts gr
                        JOIN goods_receipt_items gri ON gri.receipt_id = gr.receipt_id
                        GROUP BY gr.shipment_id, gri.line_no
                     ) r ON r.shipment_id = si.shipment_id AND r.line_no = si.line_no
                     ORDER BY si.shipment_id DESC, si.line_no LIMIT 400""")
    return shipments, items


@app.route("/receiving", methods=["GET"])
def receiving():
    try:
        shipments, items = receiving_data()
        result = session.pop("last_receipt_result", None)
        return render_template("receiving.html", page="receiving", shipments=shipments,
                               items=items, result=result)
    except pymysql.MySQLError:
        return render_template("error.html", page="receiving", detail="Không đọc được danh sách chuyến hàng. Kiểm tra bảng shipments, shipment_items và quyền truy cập."), 503


@app.post("/receiving/post")
@verify_csrf
def post_receipt():
    if not ALLOW_POST:
        flash("Chức năng ghi sổ đang tắt. Để demo, đặt ALLOW_RECEIPT_POSTING=true trong .env.", "danger")
        return redirect(url_for("receiving"))

    receipt_number = request.form.get("receipt_number", "").strip()
    received_by = request.form.get("received_by", "").strip()
    try:
        shipment_id = int(request.form.get("shipment_id", ""))
        line_no = int(request.form.get("line_no", ""))
        accepted_quantity = int(request.form.get("accepted_quantity", ""))
    except ValueError:
        flash("Mã chuyến, dòng hàng và số lượng phải là số nguyên.", "danger")
        return redirect(url_for("receiving"))

    if (not receipt_number or len(receipt_number) > 30 or
            not received_by or len(received_by) > 100 or
            shipment_id <= 0 or line_no <= 0 or accepted_quantity <= 0):
        flash("Dữ liệu không hợp lệ. Mã phiếu tối đa 30 ký tự, tên người nhận tối đa 100 ký tự và số lượng phải dương.", "danger")
        return redirect(url_for("receiving"))

    # Identify the product and destination warehouse from the actual shipment/PO,
    # never by guessing from SKU or the user's selected inventory filter.
    target_sql = """SELECT p.sku, p.product_name, w.warehouse_code, w.warehouse_id,
                           p.product_id, COALESCE(inv.quantity_on_hand, 0) AS quantity_on_hand
                    FROM shipment_items si
                    JOIN shipments s ON s.shipment_id = si.shipment_id
                    JOIN purchase_orders po ON po.purchase_order_id = s.purchase_order_id
                    JOIN purchase_order_items poi
                      ON poi.purchase_order_id = po.purchase_order_id AND poi.line_no = si.line_no
                    JOIN products p ON p.product_id = poi.product_id
                    JOIN warehouses w ON w.warehouse_id = po.destination_warehouse_id
                    LEFT JOIN inventory inv ON inv.warehouse_id = w.warehouse_id
                      AND inv.product_id = p.product_id
                    WHERE si.shipment_id = %s AND si.line_no = %s"""
    stock_sql = """SELECT COALESCE(quantity_on_hand, 0) AS quantity_on_hand
                   FROM inventory WHERE warehouse_id = %s AND product_id = %s"""
    db = None
    posted = False
    try:
        db = connect()
        with db.cursor() as cur:
            cur.execute(target_sql, (shipment_id, line_no))
            target = cur.fetchone()
            if target is None:
                flash("Không tìm thấy dòng hàng tương ứng với chuyến đã chọn.", "danger")
                return redirect(url_for("receiving"))
            before_qty = int(target["quantity_on_hand"])
            # This procedure commits internally. Do NOT treat a later SELECT error
            # as a failed insert, or the user might retry a successfully posted receipt.
            cur.execute("CALL sp_post_goods_receipt(%s, %s, %s, %s, %s, %s)", (
                receipt_number, shipment_id,
                datetime.now(timezone.utc).replace(tzinfo=None),
                received_by, line_no, accepted_quantity,
            ))
            # Consume any remaining procedure result sets.
            while cur.nextset():
                pass
            posted = True
            # The procedure has already committed. This is only a harmless extra commit.
            db.commit()
            after_qty = None
            try:
                cur.execute(stock_sql, (target["warehouse_id"], target["product_id"]))
                stock_row = cur.fetchone()
                after_qty = int(stock_row["quantity_on_hand"]) if stock_row else 0
            except pymysql.MySQLError as exc:
                app.logger.warning("Could not verify posted receipt inventory: %s", exc)
            observed_delta = (after_qty - before_qty) if after_qty is not None else None
            session["last_receipt_result"] = {
                "receipt_number": receipt_number,
                "shipment_id": shipment_id,
                "line_no": line_no,
                "sku": target["sku"],
                "product_name": target["product_name"],
                "warehouse_code": target["warehouse_code"],
                "warehouse_id": target["warehouse_id"],
                "accepted_quantity": accepted_quantity,
                "before_qty": before_qty,
                "after_qty": after_qty,
                "observed_delta": observed_delta,
                "matches": observed_delta == accepted_quantity if observed_delta is not None else False,
            }
            session["inventory_receipt_comparison"] = dict(session["last_receipt_result"])
        flash(f"Ghi sổ phiếu {receipt_number} thành công! Xem khung đối chiếu tồn kho bên dưới.", "success")
    except pymysql.MySQLError as exc:
        if posted:
            # Do not report a failure after the procedure has committed.
            flash(f"Phiếu {receipt_number} đã được ghi sổ, nhưng chưa đối chiếu được tồn kho. Kiểm tra trong Lịch sử nhập hàng trước khi thao tác lại.", "danger")
        else:
            if db is not None:
                db.rollback()
            message = str(exc.args[1] if len(exc.args) > 1 else "MySQL từ chối thao tác.")
            flash("Không thể ghi sổ: " + message[:240], "danger")
    finally:
        if db is not None:
            db.close()
    return redirect(url_for("receiving"))


if __name__ == "__main__":
    # Local demo only: the development server is never bound to public interfaces.
    app.run(host="127.0.0.1", port=int(os.getenv("PORT", "5000")), debug=False)
