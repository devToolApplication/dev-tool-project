# Frontend (FE) Development Notes & Lessons Learned

Tài liệu ghi nhớ các lỗi sai và quy chuẩn bắt buộc khi phát triển tính năng trên `dev-tool-web` (Angular).

---

## 1. Sử dụng Shared UI Components (TUYỆT ĐỐI KHÔNG tự viết UI thô hoặc import thư viện bên ngoài tự do)
- **Sai lầm:** Tự viết HTML table thô (`<table>`, `<tr>`, `<td>`), tự style Tailwind/CSS riêng cho table hoặc import trực tiếp `primeng/*` (như `TableModule`, `DialogModule`, `DropdownModule`...).
- **Quy chuẩn chuẩn hóa:** Toàn bộ feature PHẢI dùng bộ `SharedModule` của dự án:
  - **Layout/Khung trang:** `app-page-shell`, `app-section-panel`.
  - **Toolbar & Actions:** `app-action-toolbar` (`ActionToolbarAction`).
  - **Bộ lọc:** `app-filter-panel` (`FilterPanelField`).
  - **Bảng dữ liệu:** `app-table` với cấu hình qua `TableConfig<T>`.
  - **Xem chi tiết:** `app-drawer` kết hợp `app-key-value-list`, `app-json-viewer`, `app-badge`.
  - **Form / Modal:** `app-dialog`, `app-button`.
  - **Copy dữ liệu:** `app-copyable-text`.

---

## 2. Chuẩn cấu hình TableConfig
- **Sai lầm:** Định nghĩa các thuộc tính không có trong interface `TableConfig` như `selectable: false`, `hoverable: true`, `emptyMessage: string`.
- **Quy chuẩn:**
  - Tiêu đề rỗng dùng: `emptyTitle` và `emptyDescription`.
  - Cột actions: Mỗi action trong mảng `actions` của cột `type: 'actions'` PHẢI có thuộc tính `onClick: (row) => void`.
  - Custom cell renderer: Sử dụng `[customTemplates]="{ [fieldName]: templateRef }"` và khai báo `<ng-template #templateRef let-row="row">`.

---

## 3. Quản lý State & Component Độc lập
- **Sai lầm:** Tạo các sub-component dialog rải rác nhưng không khai báo/import đúng module, gây lỗi template không nhận diện component/directive hoặc missing pipe (`JsonPipe`).
- **Quy chuẩn:**
  - Nếu dialog đơn giản gắn liền với màn hình, tích hợp trực tiếp vào màn hình chính hoặc nếu tách component thì phải khai báo đầy đủ trong `declarations` / `exports` của Feature Module.
  - Luôn kiểm tra `npm run build` ngay sau khi viết xong để đảm bảo không lỗi template binding hoặc type error.