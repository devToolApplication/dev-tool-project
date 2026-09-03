# Development Guidelines & AI Instructions

## ⚠️ BẮT BUỘC: ĐỌC TÀI LIỆU QUY CHUẨN TRƯỚC KHI IMPLEMENT

Trước khi bắt tay vào code hoặc sửa đổi bất kỳ phần nào trên hệ thống, AI **BẮT BUỘC PHẢI ĐỌC KỸ** các tài liệu sau:

1. **Frontend (FE):** Bắt buộc đọc file `docs/note/fe-note.md`
   - Dùng 100% Shared UI Components của dự án (`app-page-shell`, `app-action-toolbar`, `app-filter-panel`, `app-table`, `app-drawer`, `app-dialog`, `app-button`, `app-copyable-text`). Tuyệt đối không tự viết UI thô hay import `primeng/*` bên ngoài.
   - Tuân thủ interface `TableConfig<T>`.
   - Bắt buộc xử lý đa ngôn ngữ qua i18n (`docs/note/fe-note.md` mục 4).
   - Bắt buộc thiết kế Responsive & Mobile-First (`docs/note/fe-note.md` mục 5).
   - **Bắt buộc viết đầy đủ Unit & Integration Tests (`.spec.ts`)** cho Service, API và Component. Chạy `npm run test` đảm bảo 100% pass.

2. **Backend (BE):** Bắt buộc đọc file `docs/note/be-note.md`
   - Tất cả Service bắt buộc `extends BaseService` và sử dụng `mapperUtil` (`map`, `mapTo`, `mapList`, `mapPage`).
   - Kiến trúc 3 lớp: Service PHẢI gọi qua tầng trung gian `Storage` (`infrastructure/storage`), không inject trực tiếp `Repository` vào Service.
   - Sử dụng chuẩn `BusinessException` và `BusinessErrorCode`.
   - File encoding trên Windows luôn là UTF-8 No BOM.
   - **Bắt buộc viết đầy đủ Unit Tests (`*ServiceTest.java`)** cho Service. Chạy `mvn test` đảm bảo 100% pass.

---

## 3) Submodule Synchronization
Repository sử dụng git submodules. Luôn đảm bảo submodules được sync và update đầy đủ:
```bash
git submodule sync --recursive
git submodule update --init --recursive
```