# ROBOT Phase 4 – Ghi sổ và đối chiếu tồn kho trước / sau

Dựa trên bản **ROBOT lịch sử đơn giản**. Giữ nguyên Tổng quan, Tồn kho, Đơn đặt mua, Ghi sổ, Lịch sử nhập hàng. Chỉ bổ sung thông tin kho/tồn hiện có tại danh sách dòng hàng và **khung so sánh tồn trước – nhập thêm – tồn sau** sau khi ghi sổ thành công.

## Cài đặt trên Windows / VS Code

1. Giải nén toàn bộ ZIP. Mở **thư mục có `app.py`** bằng VS Code.
2. Chạy `python -m pip install -r requirements.txt` nếu chưa có thư viện.
3. Tạo `.env` bằng cách sao chép `.env.example` (đổi tên bản sao thành `.env`). Nhập mật khẩu MySQL và tên database của em. **Không chia sẻ `.env`.**
4. Giữ `ALLOW_RECEIPT_POSTING=false` để xem giao diện. Chạy `python app.py`, vào `http://127.0.0.1:5000/receiving`.
5. Để demo ghi thật: **sao lưu database** (nên dùng bản sao demo), kiểm tra `sp_post_goods_receipt` và các Trigger đã có, rồi chuyển `ALLOW_RECEIPT_POSTING=true`, lưu `.env`, khởi động lại Flask.
6. Ở trang Nhận hàng, chọn dòng có `Còn nhận > 0` bằng nút **Chọn nhận**. Giao diện tự điền mã chuyến/dòng và cho biết kho đích/SKU/số tồn hiện có. Điền số phiếu mới, số lượng hợp lệ và người nhận, bấm Ghi sổ **một lần**.
7. Sau khi thành công, khung trên đầu trang hiển thị số tồn trước, số lượng chấp nhận, số tồn sau và chênh lệch, kèm liên kết **Xem đúng SKU và kho** và **Xem phiếu trong lịch sử**.

## Phân biệt dữ liệu thật và minh họa

- Cặp sản phẩm/kho xác định bằng `shipments → purchase_orders.destination_warehouse_id` và `purchase_order_items.product_id`.
- Trước khi gọi `sp_post_goods_receipt`, ứng dụng đọc `inventory.quantity_on_hand` (không tồn tại dòng tồn kho thì tính là 0). Sau khi thủ tục hoàn tất, ứng dụng đọc lại cặp sản phẩm/kho đó.
- Trigger `trg_process_goods_receipt_item_bi` trong `codechinh.sql` là nơi cập nhật `quantity_on_hand` bằng số lượng được chấp nhận.
- **Phiếu cũ** trong lịch sử chỉ hiển thị lượng nhận và kho. Không thể khẳng định tồn trước từ tồn hiện tại nếu không có bản ghi ảnh chụp tồn quá khứ.
- **Kết quả trước/sau của lần vừa ghi** được hiển thị ngay trên trang Nhận hàng qua phiên trình duyệt. Bản đơn giản **không lưu lâu dài ảnh chụp tồn trước/sau** và **không yêu cầu tạo bảng phụ** `robot_demo_receipt_audit`.
- Nếu có giao dịch tồn kho đồng thời trong lúc ghi sổ, chênh lệch quan sát có thể khác lượng vừa nhập. Giao diện cảnh báo khi không khớp; không khẳng định sai rằng kết quả đã đối chiếu thành công.
- Stored Procedure của dự án có `COMMIT` nội bộ. Nếu MySQL báo lỗi ở bước kiểm tra sau khi ghi sổ, **đừng bấm ghi sổ lần hai** trước khi kiểm tra trang Lịch sử.

## Lưu ý

- Không cần chạy SQL tạo bảng lịch sử mới. Database cần sẵn 13 bảng, 2 VIEW, Stored Procedure và Trigger như bản gốc.
- Giữ ứng dụng ở `127.0.0.1`, không chạy máy chủ phát triển Flask trên Internet.
- Nên tạo tài khoản MySQL có quyền phù hợp thay vì dùng `root`; nếu dùng `root` để demo trên máy riêng, cần cẩn thận bảo vệ file `.env` và dữ liệu.


## Bổ sung: đối chiếu ngay trên trang Tồn kho

- Ghi sổ thành công, chọn **Xem đúng SKU và kho**: trang Tồn kho hiển thị **tồn trước / số lượng nhập / tồn sau** đã đo tại thời điểm ghi. Dữ liệu này lưu tạm trong Flask session (trình duyệt hiện tại), không phải lịch sử vĩnh viễn.
- Trang **Lịch sử nhập hàng** → **Xem tồn kho** tự truyền mã phiếu. Nếu là phiếu cũ, trang Tồn kho sẽ hiển thị đúng SKU, kho, số lượng đã nhận, cột Hiện có và tồn kho hiện tại, nhưng **không tự suy ra tồn trước**.
- Không cần thêm bảng hay chạy SQL mới. Ghi sổ chỉ bật khi `ALLOW_RECEIPT_POSTING=true` và nên thử trên cơ sở dữ liệu bản sao.
- Giữ file `.env` riêng, không đưa mật khẩu MySQL lên mạng.
