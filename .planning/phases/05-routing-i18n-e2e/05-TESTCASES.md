# Test Cases - Phase 05: Routing, Multi-language & Comprehensive E2E Validation

**Phase:** 05-routing-i18n-e2e  
**Module:** `web/dev-tool-web` (Angular 21)  
**Target:** Routing, Sidebar Menu, i18n, Playwright E2E Integration Suite  
**Reference:** [docs/note/fe-note.md](docs/note/fe-note.md) §4, §5 & §6, [docs/designs/codex-sdk-chat-history-workbench.md](docs/designs/codex-sdk-chat-history-workbench.md) §4

---

## 1. Danh Sách Test Cases E2E Toàn Diện

### TC-FE-E2E-01: Render Giao Diện Hoàn Chỉnh và Cấu Trúc Shell
- **Mục đích:** Đảm bảo khi điều hướng tới `/codex-sdk/threads`, toàn bộ cấu trúc trang gồm `app-page-shell`, `app-action-toolbar`, `app-filter-panel` và `app-table` hiển thị đầy đủ, không bị lỗi render hoặc vỡ layout.
- **Phân loại:** Playwright E2E Test (`e2e/codex-sdk-integration.spec.ts`)
- **Các bước thực hiện:**
  1. Mở trình duyệt và truy cập `page.goto('/codex-sdk/threads')`.
  2. Chờ mạng ổn định và component nạp xong.
- **Kết quả kỳ vọng:**
  - `app-page-shell` hiển thị với tiêu đề "Lịch sử Chat Codex SDK".
  - `app-action-toolbar` hiển thị các nút thao tác.
  - `app-table` hiển thị bảng dữ liệu.

---

### TC-FE-E2E-02: Tương Tác Mở Drawer và Đóng Drawer Trên Trình Duyệt
- **Mục đích:** Xác minh nhấp nút "Mở Workbench test" trên thanh công cụ sẽ kích hoạt `app-drawer` mở ra từ bên phải màn hình, nút đóng drawer hoạt động chính xác.
- **Phân loại:** Playwright E2E Test
- **Các bước thực hiện:**
  1. Click nút "Mở Workbench test" trên `app-action-toolbar`.
  2. Kiểm tra `app-drawer` hiển thị.
  3. Click nút đóng drawer (icon close hoặc backdrop).
- **Kết quả kỳ vọng:**
  - `app-drawer` hiển thị (`toBeVisible()`).
  - Sau bước 3, `app-drawer` đóng lại (`toBeHidden()`).

---

### TC-FE-E2E-03: Responsive Drawer Mobile-First (< 768px)
- **Mục đích:** Đảm bảo giao diện tuân thủ nguyên tắc Mobile-First (`docs/note/fe-note.md` §5): trên màn hình di động nhỏ, Drawer tự động bung rộng 100% full-width thay vì giữ kích thước cố định 650px của desktop.
- **Phân loại:** Playwright E2E Responsive Test
- **Các bước thực hiện:**
  1. Thiết lập kích thước màn hình `page.setViewportSize({ width: 375, height: 667 })`.
  2. Nhấp nút mở Drawer.
  3. Đo kích thước bounding box của `.app-drawer-panel`.
- **Kết quả kỳ vọng:**
  - Chiều rộng của Drawer panel chiếm trọn màn hình (`width >= 360px`).
  - Không xuất hiện thanh cuộn ngang ngoài ý muốn trên toàn trang (`overflow-x`).

---

### TC-FE-E2E-04: Luồng E2E Chat Hoàn Chỉnh từ Danh Sách đến Nhận Token Stream
- **Mục đích:** Kiểm tra luồng người dùng thực tế: Vào bảng danh sách -> Click dòng thread -> Mở drawer xem lịch sử -> Nhập prompt tiếp theo -> Nhận token SSE từ backend.
- **Phân loại:** Playwright E2E Flow Test
- **Các bước thực hiện:**
  1. Mock danh sách thread và chi tiết thread history.
  2. Mock endpoint SSE stream `**/v1/codex-sdk/stream`.
  3. Click dòng thread đầu tiên trên bảng.
  4. Nhập prompt tiếp theo vào ô chat và bấm "Gửi".
- **Kết quả kỳ vọng:**
  - Lịch sử chat cũ hiển thị đúng.
  - Sau khi gửi, token mới được append vào cuối timeline của Assistant.

---

### TC-FE-INT-01: Kiểm Tra Đăng Ký Menu Sidebar trong `menu.config.ts`
- **Mục đích:** Xác minh mục menu "Codex SDK Chat" được tích hợp chuẩn xác vào cây điều hướng hệ thống thuộc nhóm `layout.menu.aiAgentMcrs`.
- **Phân loại:** Integration & Configuration Test
- **Các bước thực hiện:**
  1. Đọc mảng `APP_LAYOUT_MENU` trong `src/app/app-shell/navigation/config/menu.config.ts`.
  2. Tìm mục con có `routerLink: '/codex-sdk/threads'`.
- **Kết quả kỳ vọng:**
  - Tồn tại item với `label: 'layout.menu.codexSdkChat'`.
  - Icon cấu hình là `'pi pi-comments'`.

---

### TC-FE-INT-02: Kiểm Tra Tính Đầy Đủ Của Đa Ngôn Ngữ (i18n Parity)
- **Mục đích:** Đảm bảo 100% các nhãn text hiển thị trên giao diện đều được định nghĩa qua file dịch `codex-sdk.i18n.json` ở cả 2 thứ tiếng `vi` và `en`.
- **Phân loại:** i18n Static Verification
- **Các bước thực hiện:**
  1. Đọc file `src/app/core/i18n/features/codex-sdk.i18n.json`.
  2. Lấy danh sách keys của object `vi` và object `en`.
  3. So sánh đối soát 2 danh sách keys.
- **Kết quả kỳ vọng:**
  - Không có key nào bị thiếu giữa 2 ngôn ngữ (`vi` keys khớp hoàn toàn 100% với `en` keys).
  - Không có key nào bị để giá trị chuỗi rỗng.

---

### TC-FE-INT-03: Kiểm Tra Build Production Không Phát Sinh Lỗi Compile
- **Mục đích:** Xác minh mã nguồn TypeScript, template HTML và cấu hình module tích hợp không có lỗi gõ kiểu (`strict type check`) hoặc lỗi missing dependency.
- **Phân loại:** Build & Compile Test
- **Các bước thực hiện:**
  1. Chạy lệnh build production của Angular CLI.
- **Kết quả kỳ vọng:**
  - Lệnh build kết thúc với mã thoát 0 (`Exit code 0`).
  - Zero compile errors, zero template binding warnings.

---

## 2. Kịch Bản Playwright Tích Hợp Toàn Diện (`codex-sdk-integration.spec.ts`)

```typescript
import { test, expect } from '@playwright/test';

test.describe('Codex SDK End-to-End Suite', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    if (page.url().includes('auth/realms')) {
      await page.fill('#username', 'lamld');
      await page.fill('#password', 'Zzxx25102001');
      await page.click('#kc-login');
      await page.waitForNavigation();
    }
  });

  test('TC-FE-E2E-04: Full conversation flow with drawer and SSE streaming', async ({ page }) => {
    await page.route('**/v1/codex-sdk/threads*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          data: {
            data: [{ id: 'thread-real-01', previewText: 'Lịch sử thảo luận trước', turnCount: 2 }],
            nextCursor: null,
          },
        }),
      });
    });

    await page.route('**/v1/codex-sdk/threads/thread-real-01', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          data: {
            id: 'thread-real-01',
            turns: [
              { id: 'turn-1', role: 'user', content: 'Turn 1 prompt' },
              { id: 'turn-2', role: 'assistant', content: 'Turn 1 response' },
            ],
          },
        }),
      });
    });

    await page.route('**/v1/codex-sdk/stream', async (route) => {
      await route.fulfill({
        status: 200,
        headers: { 'Content-Type': 'text/event-stream' },
        body: 'event: message\ndata: Phản hồi \n\nevent: message\ndata: mới.\n\nevent: done\ndata: Done\n\n',
      });
    });

    await page.goto('/codex-sdk/threads');
    await page.click('button:has-text("Xem chi tiết")');
    await expect(page.locator('app-drawer')).toBeVisible();
    await expect(page.locator('.turn-bubble.assistant')).toContainText('Turn 1 response');

    await page.fill('textarea.prompt-textarea', 'Prompt 2');
    await page.click('.workbench-bottom-bar button[type="submit"]');

    await expect(page.locator('.turn-bubble.assistant').last()).toContainText('Phản hồi mới.');
  });
});
```

---

## 3. Lệnh Thực Thi

```powershell
npx playwright test e2e/codex-sdk-integration.spec.ts
```
