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

## 6. Quy định bắt buộc Testing: Bắt buộc Playwright E2E cho mọi luồng UI/UX (KHÔNG CHỈ MỖI UNIT TEST)
- **Sai lầm nghiêm trọng:** 
  - Chỉ viết Unit Test (`.spec.ts`) hoặc chỉ mock hàm đơn thuần trong Vitest/Jasmine rồi coi là xong việc.
  - Không viết hoặc không chạy Playwright E2E dẫn đến việc bỏ lọt các lỗi chết người trên trình duyệt thực: vỡ layout, sai DOM selector, lỗi truyền nhận SSE stream, lỗi nút pagination/toolbar không bấm được, lỗi Keycloak auth redirect, hoặc drawer không co giãn trên mobile.
- **Quy chuẩn bắt buộc 100%:**
  - **TUYỆT ĐỐI KHÔNG CHỈ DỰA VÀO UNIT TEST:** Mọi tính năng, màn hình và phase FE bắt buộc phải có test suite **Playwright E2E** (`e2e/*.spec.ts`) kiểm chứng toàn bộ luồng tương tác thực tế của người dùng trên trình duyệt (Chromium / WebKit).
  - **Phạm vi kiểm thử E2E bắt buộc bao gồm:**
    1. Đăng nhập Keycloak tự động (sử dụng tài khoản test `lamld` / `Zzxx25102001`).
    2. Render hoàn chỉnh cấu trúc trang (`app-page-shell`, `app-action-toolbar`, `app-table`).
    3. Tương tác phân trang (Next/Prev Cursor hoặc Page Index) và xác minh request param tương ứng.
    4. Mở/đóng `app-drawer` từ bảng danh sách hoặc thanh toolbar.
    5. Xử lý form, nhập prompt, nhận và dồn SSE streaming token theo thời gian thực (kết hợp `page.route()` mock SSE stream và API).
    6. Kiểm thử nút dừng stream (`AbortController`) và cơ chế retry khi lỗi mạng.
    7. Kiểm thử Responsive Mobile Viewport (< 768px) đảm bảo drawer full-width và không bị vỡ giao diện.
  - **Nghiệm thu bàn giao:**
    - Unit Tests (`.spec.ts`): Chạy `npm test` đạt 100% PASS.
    - Playwright E2E (`e2e/*.spec.ts`): Bắt buộc chạy `npx playwright test e2e/<feature>.spec.ts` đạt 100% PASS trên trình duyệt thật trước khi hoàn tất.


---

## 7. Bắt buộc kiểm tra UI/UX Pro Max & Taste Skills trước khi implement
- **Nguyên tắc cốt lõi:** Trước khi bắt tay vào thiết kế layout, styling hoặc code bất kỳ component/page FE nào, AI **BẮT BUỘC** phải rà soát qua các tiêu chuẩn của **UI/UX Pro Max** (`dev-fe-design-skills` / `ui-ux-design-rule`) và **Taste Skill** (`tools/agent-skill/shared/skills/taste-skill/SKILL.md`, `stitch-skill/DESIGN.md`, `redesign-skill`).
- **Checklist bắt buộc tuân thủ:**
  1. **Anti-Slop & Anti-Default:**
     - Tuyệt đối không dùng gradient neon tím xanh rập khuôn ("AI Purple"), không dùng pure black `#000000` (dùng charcoal `#070b22` hoặc `#18181b`).
     - Chỉ dùng **duy nhất 1 accent color** chủ đạo cho cả hệ thống (độ bão hòa < 80%), không phân tán màu sắc.
     - Dùng token thiết kế `var(--app-*)` đã quy định trong `src/theme/tokens.css` và `src/theme/dark.css`. Cấm dùng màu hardcoded hex/rgb/tailwind utility tùy tiện.
  2. **Typography & Hierarchy:**
     - Dùng font hiện đại (`Geist`, `Geist Mono`, `Outfit`), không dùng font mặc định của trình duyệt.
     - Headline phải có presence: giảm line-height, áp dụng negative tracking (`letter-spacing: -0.01em` đến `-0.02em`).
     - Dùng `font-variant-numeric: tabular-nums` cho các hiển thị số, metrics, bảng dữ liệu.
  3. **Visual Depth & Layout:**
     - Không để layout phẳng lỳ (flat zero texture); sử dụng tinted shadow, squircle radius (`var(--app-radius-*)`), và subtle highlight gradient.
     - Tránh layout 3 cột đều chằn chặn rập khuôn AI; áp dụng bố cục có chính - phụ rõ ràng: **1 viewport đầu tiên chỉ có 1 trọng tâm chính**, mọi thứ khác đẩy xuống secondary/advanced.
     - Viewport container luôn hỗ trợ `min-height: 100dvh` (fallback cùng `100vh`) để tránh bug nhảy layout trên mobile Safari/Chrome.
  4. **Interactivity & Micro-Interactions:**
     - Mọi interactive control (button, item) phải có hover state rõ ràng và active state vật lý (`transform: scale(0.98)`).
     - Luôn có focus ring (`:focus-visible` với `--app-focus-ring`) đạt chuẩn Accessibility.
     - Chuyển động có transition mượt (120ms - 200ms) qua motion tokens; không dùng animation giật cục.

---

## 8. TUYỆT ĐỐI CẤM DÙNG LOGIC FALLBACK (NO FALLBACK RULE)
- **Sai lầm:**
  - Tự viết logic fallback ngầm ở FE (ví dụ: tự mock dữ liệu khi API lỗi, tự động swallow error rồi hiển thị thành công giả, hoặc fallback sang mock service không qua server).
  - Tự sinh dữ liệu mẫu che giấu lỗi kết nối tới BE (`ai-agent-mcrs`) hoặc che giấu trạng thái lỗi của AI process run.
- **Quy chuẩn bắt buộc:**
  - **Minh bạch trạng thái lỗi:** Khi BE hoặc SSE Stream trả về lỗi, FE phải hiển thị chính xác trạng thái lỗi từ response (toast thông báo mã lỗi và message thật từ BE).
  - **Không fake fallback state:** Tuyệt đối không tự bắt lỗi 400/500 rồi render giao diện với danh sách giả lập. Nếu AI đang xử lý dở dang hoặc gặp lỗi dừng luồng, phải hiển thị đúng trạng thái của workflow run (`FAILED`, `ERROR`, `BLOCKED`).