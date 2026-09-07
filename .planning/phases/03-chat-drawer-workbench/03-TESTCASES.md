# Test Cases - Phase 03: Conversation Timeline & Collapsible Inspector

**Phase:** 03-chat-drawer-workbench  
**Module:** `web/dev-tool-web` (Angular 21)  
**Target:** `CodexChatDrawerComponent` (.ts, .html, .scss), Playwright E2E Drawer Workflows  
**Reference:** [docs/note/fe-note.md](docs/note/fe-note.md) §1, §5, [docs/designs/codex-sdk-chat-history-workbench.md](docs/designs/codex-sdk-chat-history-workbench.md) §2 & §3

---

## 1. Danh sách Test Cases Chi tiết

### TC-FE-DRAWER-E2E-01: E2E Render Lịch Sử Hội Thoại và Bong Bóng Chat
- **Mục đích:** Kiểm tra trình duyệt thực tế mở Drawer hiển thị đúng lịch sử turns hội thoại (User bên phải, Assistant bên trái) từ mock API.
- **Phân loại:** Playwright E2E Test (`e2e/codex-sdk-drawer.spec.ts`)
- **Các bước thực hiện:**
  1. Đăng nhập Keycloak (`lamld` / `Zzxx25102001`).
  2. Dùng `page.route('**/v1/codex-sdk/threads/thread-100', ...)` trả về 1 turn User và 1 turn Assistant.
  3. Mở Drawer qua URL `/codex-sdk/threads?threadId=thread-100` hoặc click dòng tương ứng trên bảng.
- **Kết quả kỳ vọng:**
  - Selector `.app-drawer-panel` hiển thị (`toBeVisible()`).
  - Xuất hiện `.turn-bubble.user` chứa text prompt của User.
  - Xuất hiện `.turn-bubble.assistant` chứa text câu trả lời của Assistant.

---

### TC-FE-DRAWER-E2E-02: E2E Đóng Mở Tool Call Accordion (Collapsible Inspector)
- **Mục đích:** Kiểm tra người dùng click vào từng Tool Call header sẽ mở accordion hiển thị JSON payload chi tiết qua `app-json-viewer`.
- **Phân loại:** Playwright E2E Test
- **Các bước thực hiện:**
  1. Mock turn Assistant có chứa `toolCalls: [{ name: 'exec_command', input: { cmd: 'git status' } }]`.
  2. Mở Drawer và xác minh header tool call hiển thị dạng thẻ gọn `.tool-call-header`.
  3. Click vào `.tool-call-header`.
- **Kết quả kỳ vọng:**
  - Accordion mở ra, hiển thị component `app-json-viewer`.
  - JSON payload chứa chuỗi `"cmd": "git status"` hiển thị rõ ràng trên DOM.
  - Click lại lần nữa, accordion đóng lại (`toBeHidden()`).

---

### TC-FE-DRAWER-E2E-03: E2E Gửi Prompt Mới và Nhận SSE Streaming Token
- **Mục đích:** Kiểm tra luồng gửi prompt trực tiếp từ thanh `.workbench-bottom-bar`, nhận streaming token dồn liên tục trên trình duyệt thực.
- **Phân loại:** Playwright E2E Test
- **Các bước thực hiện:**
  1. Mock route POST `**/v1/codex-sdk/stream` trả về stream SSE:
     ```
     event: message\ndata: Đang \n\n
     event: message\ndata: kiểm tra hệ thống.\n\n
     event: done\ndata: Done\n\n
     ```
  2. Điền text `"Kiểm tra hệ thống"` vào `textarea.prompt-textarea`.
  3. Click nút "Gửi" (`app-button` submit).
- **Kết quả kỳ vọng:**
  - Turn User xuất hiện ngay lập tức trên timeline.
  - Xuất hiện turn Assistant tạm thời kèm con trỏ `.streaming-cursor`.
  - Nội dung text tăng dần thành `"Đang kiểm tra hệ thống."`.
  - Khi stream kết thúc, con trỏ nhấp nháy biến mất.

---

### TC-FE-DRAWER-E2E-04: E2E Nút Hủy Stream (AbortController)
- **Mục đích:** Đảm bảo khi đang nhận SSE stream, người dùng click nút "Dừng stream" thì trình duyệt hủy kết nối an toàn.
- **Phân loại:** Playwright E2E Test
- **Các bước thực hiện:**
  1. Mock route SSE stream với delay giữa các chunk (chưa hoàn tất).
  2. Click nút "Gửi" prompt.
  3. Chờ nút "Dừng stream" xuất hiện và click vào nút.
- **Kết quả kỳ vọng:**
  - Nút "Dừng stream" chuyển lại thành nút "Gửi".
  - Nội dung đã nhận trước khi dừng được giữ nguyên trên màn hình.
  - Không xuất hiện banner lỗi kết nối nghiêm trọng.

---

### TC-FE-DRAWER-E2E-05: E2E Phục Hồi Lỗi Partial Stream & Nút "Thử lại"
- **Mục đích:** Khi kết nối stream bị đứt giữa chừng, giao diện hiển thị banner cảnh báo inline kèm nút "Thử lại".
- **Phân loại:** Playwright E2E Test
- **Các bước thực hiện:**
  1. Mock SSE stream ném lỗi network đứt gãy sau 1 token.
  2. Click "Gửi" prompt.
  3. Kiểm tra banner lỗi xuất hiện và click nút "Thử lại".
- **Kết quả kỳ vọng:**
  - Xuất hiện banner `.stream-error-banner` kèm thông điệp lỗi.
  - Nút "Thử lại" được kích hoạt, tự động gửi lại prompt tương ứng.

---

### TC-FE-DRAWER-E2E-06: E2E Kiểm Tra Scroll Anchoring
- **Mục đích:** Khi người dùng chủ động cuộn chuột lên để đọc turn cũ, nhận token mới không bị giật trang xuống đáy.
- **Phân loại:** Playwright E2E Test
- **Các bước thực hiện:**
  1. Nạp thread có nhiều turns vượt quá chiều cao màn hình.
  2. Dùng script Playwright cuộn `.drawer-scroll-container` lên trên (`scrollTop = 100`).
  3. Phát sinh thêm streaming tokens.
- **Kết quả kỳ vọng:**
  - Vị trí cuộn `scrollTop` của container không bị cưỡng ép nhảy về đáy (`scrollTop !== scrollHeight`).

---

## 2. Kịch Bản Playwright Mẫu (`codex-sdk-drawer.spec.ts`)

```typescript
import { test, expect } from '@playwright/test';

test.describe('Codex SDK Chat Drawer E2E', () => {
  test.beforeEach(async ({ page }) => {
    // 1. Đăng nhập Keycloak
    await page.goto('/login');
    if (page.url().includes('auth/realms')) {
      await page.fill('#username', 'lamld');
      await page.fill('#password', 'Zzxx25102001');
      await page.click('#kc-login');
      await page.waitForNavigation();
    }
  });

  test('TC-FE-DRAWER-E2E-03: Gửi prompt và stream tokens', async ({ page }) => {
    // 2. Mock SSE stream response
    await page.route('**/v1/codex-sdk/stream', async (route) => {
      await route.fulfill({
        status: 200,
        headers: { 'Content-Type': 'text/event-stream' },
        body: 'event: message\ndata: Xin chào\n\nevent: done\ndata: Done\n\n',
      });
    });

    await page.goto('/codex-sdk/threads');
    await page.click('button:has-text("Mở Workbench test")');
    await expect(page.locator('app-drawer')).toBeVisible();

    await page.fill('textarea.prompt-textarea', 'Xin chào bot');
    await page.click('.workbench-bottom-bar button[type="submit"]');

    await expect(page.locator('.turn-bubble.assistant')).toContainText('Xin chào');
  });
});
```

---

## 3. Lệnh Thực Thi

```powershell
npx playwright test e2e/codex-sdk-drawer.spec.ts
```
