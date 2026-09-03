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

---

## 4. Quản lý Đa ngôn ngữ (i18n)
- **Sai lầm:** Hardcode chuỗi tiếng Việt/tiếng Anh trực tiếp trong HTML/TS mà không qua hệ thống i18n của dự án.
- **Quy chuẩn chuẩn hóa:**
  - Tạo file dịch feature tại `src/app/core/i18n/features/{feature-name}.i18n.json` với cả 2 key `"vi"` và `"en"`.
  - Đăng ký file dịch vào `I18nService` (`src/app/core/i18n/i18n.service.ts`) trong object `TRANSLATIONS`.
  - Trong template HTML: Sử dụng pipe `| translateContent` cho label/placeholder hoặc truyền key i18n trực tiếp vào các Shared Components (`app-page-shell`, `app-action-toolbar`, `app-filter-panel`, `app-table`).

---

## 5. Mobile-First & Responsive Design
- **Sai lầm:** Dùng layout cứng `grid-cols-2` không có breakpoint, hoặc dialog buttons `flex-row` trên mobile làm tràn màn hình và vỡ form.
- **Quy chuẩn:**
  - Form grid: `grid grid-cols-1 sm:grid-cols-2 gap-3` để co giãn 1 cột trên mobile và 2 cột trên desktop.
  - Dialog / Drawer actions: `flex flex-col-reverse sm:flex-row justify-end gap-2` (mobile full width stacked, desktop inline).
  - Truncate text: `truncate`, `min-w-0`, `max-w-full`, `select-all` cho key / code / username để tránh vỡ cột bảng trên màn hình nhỏ.

---

## 6. Bắt buộc viết Unit & Integration Tests (BẮT BUỘC)
- **Sai lầm:** Chỉ hoàn thành code UI/Service mà không viết test, để người dùng phải nhắc nhở mới viết.
- **Quy chuẩn chuẩn hóa:** Mọi tính năng mới hoặc chỉnh sửa bắt buộc phải có test đi kèm:
  - **Service/Logic Tests:** File `.spec.ts` tương ứng test toàn bộ function tính toán, parse logic, TOTP, regex, v.v.
  - **API Service Tests:** Dùng `HttpTestingController` mock response và verify request URL, method, payload.
  - **Component UI Tests:** Test render initial state, trigger toolbar action, mở/đóng modal dialog, toggle state (như password, filter, drawer).
  - **Validation Gate:** Luôn chạy `npm run test` (Vitest/Angular testing) và đảm bảo 100% test suite PASS trước khi bàn giao.