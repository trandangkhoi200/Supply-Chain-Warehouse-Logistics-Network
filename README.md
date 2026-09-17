📦 Warehouse & Supply Chain Management Database

📖 Giới thiệu (About the Project)
Dự án này là một thiết kế cơ sở dữ liệu quan hệ (Relational Database) chuyên sâu dành cho nghiệp vụ Logistics hiện đại. Thay vì chỉ ghi nhận xuất/nhập kho đơn thuần, hệ thống được xây dựng để giải quyết bài toán phức tạp của mạng lưới chuỗi cung ứng: quản lý hàng hóa phân tán trên nhiều nhà kho vật lý, xử lý cấu trúc linh kiện đệ quy (BOM) và tự động hóa quy trình luân chuyển hàng hóa.

Đồ án tuân thủ nghiêm ngặt các tiêu chuẩn công nghiệp về tài liệu thiết kế (ISO/IEC/IEEE 29148, ISO/IEC 19505, ISO/IEC 11179).

✨ Tính năng cốt lõi (Key Business Rules)
- 🌍 Quản lý Đa kho địa lý (Multi-Warehouse Inventory): Số lượng tồn kho và ngưỡng an toàn được theo dõi độc lập tại từng vị trí nhà kho thông qua bảng trung gian tồn kho.
- 🧩 Cấu trúc Đệ quy đa cấp (Bill of Materials - BOM): Khai báo và phân rã các mặt hàng phức tạp thành nhiều linh kiện con với định mức số lượng chính xác thông qua mối quan hệ tự trỏ.
- ⚖️ Cân bằng tồn kho (Internal Transfer): Khi một kho chạm ngưỡng báo động, hệ thống bắt buộc ưu tiên quét và điều chuyển hàng hóa nội bộ (Internal Transfer) từ các kho khác. Chỉ khi toàn mạng lưới không có hàng dư, hệ thống mới phát sinh giao dịch đặt mua ngoài (Order).
- 👥 Phân quyền & Quản lý Đối tác: Thiết lập ràng buộc chặt chẽ với tỷ lệ 1-1 cho Nhân viên quản lý kho trực tiếp và tỷ lệ 1-N cho các Đại diện liên hệ của Nhà cung cấp.

🛠️ Tài liệu & Thiết kế bao gồm
- Sơ đồ EER (Khái niệm): Biểu diễn thực thể, phân rã (disjoint), mối quan hệ và bản số.
- Sơ đồ Crow's Foot (Vật lý): Ánh xạ cấu trúc bảng chuẩn công nghiệp loại bỏ hình thoi.
- Lược đồ Lô-gíc & Chuẩn hóa: Đảm bảo toàn bộ bảng và thuộc tính đạt chuẩn hóa 3NF/BCNF, triệt tiêu dư thừa dữ liệu. Naming convention tuân thủ 100% chuẩn `snake_case`.
- Từ điển Dữ liệu (Data Dictionary): Ràng buộc kiểu dữ liệu, khóa chính/ngoại và quy tắc nghiệp vụ chi tiết.

---
Đồ án môn học Cơ sở dữ liệu - Nhóm ROBOT
