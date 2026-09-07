# Development Guidelines & AI Instructions

## ⚠️ BẮT BUỘC: ĐỌC TÀI LIỆU QUY CHUẨN TRƯỚC KHI IMPLEMENT

Trước khi bắt tay vào code hoặc sửa đổi bất kỳ phần nào trên hệ thống, AI **BẮT BUỘC PHẢI ĐỌC KỸ** các tài liệu sau:

1. **Frontend (FE):** Bắt buộc đọc file `docs/note/fe-note.md`
   - Dùng 100% Shared UI Components của dự án (`app-page-shell`, `app-action-toolbar`, `app-filter-panel`, `app-table`, `app-drawer`, `app-dialog`, `app-button`, `app-copyable-text`). Tuyệt đối không tự viết UI thô hay import `primeng/*` bên ngoài.
   - Bắt buộc kiểm tra & tuân thủ tiêu chuẩn **UI/UX Pro Max** và **Taste Skill** trước khi code giao diện (`docs/note/fe-note.md` mục 7).
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

---

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
- Author a backlog-ready spec/issue → invoke /spec