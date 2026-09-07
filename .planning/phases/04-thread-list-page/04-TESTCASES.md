# Test Cases - Phase 04: Thread List & Cursor Navigation Workbench

**Phase:** 04-thread-list-page  
**Module:** `web/dev-tool-web` (Angular 21)  
**Target:** `CodexThreadListPageComponent` (.ts, .html, .scss), Playwright E2E List Workflows  
**Reference:** [docs/note/fe-note.md](docs/note/fe-note.md) §1 & §2, [docs/designs/codex-sdk-chat-history-workbench.md](docs/designs/codex-sdk-chat-history-workbench.md) §2

---

## 1. Danh sách Test Cases Playwright E2E

### TC-FE-PAGE-E2E-01: E2E Render Bảng Danh Sách và Cấu Trúc Shell
- **Mục đích:** Đảm bảo khi điều hướng tới `/codex-sdk/threads`, bảng `app-table` hiển thị đủ các cột cấu hình `TableConfig` và dữ liệu từ API mock.
- **Phân loại:** Playwright E2E Test (`e2e/codex-sdk-list.spec.ts`)
- **Các bước thực hiện:**
  1. Mock API `**/v1/codex-sdk/threads*` trả về 2 bản ghi threads.
  2. Truy cập `/codex-sdk/threads`.
- **Kết quả kỳ vọng:**
  - `app-page-shell` và `app-action-toolbar` hiển thị đầy đủ.
  - Header bảng chứa các cột: ID, Nội dung xem trước, Số lượt trao đổi, Thời gian tạo, Thao tác.
  - Số dòng trong bảng là 2.

---

### TC-FE-PAGE-E2E-02: E2E Phân Trang Bằng Con Trỏ (Next Cursor & Prev Cursor Navigation)
- **Mục đích:** Xác minh việc click nút "Trang sau" và "Trang trước" trên `app-action-toolbar` gọi API với đúng tham số cursor và quản lý stack lịch sử.
- **Phân loại:** Playwright E2E Test
- **Các bước thực hiện:**
  1. Mock trang 1 trả về `nextCursor = 'cursor_page_2'`.
  2. Kiểm tra ban đầu: Nút "Trang trước" bị `disabled`.
  3. Click nút "Trang sau".
  4. Chờ request trang 2 hoàn tất với query param `cursor=cursor_page_2`.
  5. Click nút "Trang trước".
- **Kết quả kỳ vọng:**
  - Khi sang trang 2, nút "Trang trước" được mở khóa (`isEnabled()`).
  - Khi click quay lại trang 1, request gọi API không còn tham số cursor trang 2.
  - Nút "Trang trước" trở lại trạng thái `disabled`.

---

### TC-FE-PAGE-E2E-03: E2E Lọc Dữ Liệu và Reset Lịch Sử Cursor
- **Mục đích:** Người dùng nhập từ khóa tìm kiếm trên `app-filter-panel`, bảng nạp lại dữ liệu và lịch sử con trỏ được đặt lại từ đầu.
- **Phân loại:** Playwright E2E Test
- **Các bước thực hiện:**
  1. Điều hướng sang trang 2.
  2. Mở `app-filter-panel`, nhập `"fix bug agent"` vào ô tìm kiếm và ấn Áp dụng.
- **Kết quả kỳ vọng:**
  - Request mới được gửi đi với query param `searchTerm=fix+bug+agent` và không có cursor cũ.
  - Nút "Trang trước" bị vô hiệu hóa lại (`disabled = true`).

---

### TC-FE-PAGE-E2E-04: E2E Mở Drawer Khi Click Nút "Xem chi tiết" Trên Hàng
- **Mục đích:** Click vào nút thao tác "Xem chi tiết" tại một dòng dữ liệu sẽ mở `app-drawer` đúng với thread ID đó.
- **Phân loại:** Playwright E2E Test
- **Các bước thực hiện:**
  1. Click nút "Xem chi tiết" (icon con mắt) tại dòng thread có ID `'t-test-01'`.
- **Kết quả kỳ vọng:**
  - `app-drawer` mở ra từ bên phải.
  - Tiêu đề drawer hoặc breadcrumb hiển thị `'t-test-01'`.
  - API lấy lịch sử thread `'**/v1/codex-sdk/threads/t-test-01'` được gọi.

---

### TC-FE-PAGE-E2E-05: E2E Mở Drawer Mới Từ Nút "Mở Workbench test" Trên Toolbar
- **Mục đích:** Click nút tạo mới trên toolbar mở Drawer ở chế độ tạo phiên đàm thoại mới.
- **Phân loại:** Playwright E2E Test
- **Các bước thực hiện:**
  1. Click nút "Mở Workbench test" trên `app-action-toolbar`.
- **Kết quả kỳ vọng:**
  - `app-drawer` mở ra.
  - Khu vực hiển thị tin nhắn trống, hiển thị hướng dẫn nhập prompt.
  - Thanh nhập prompt sẵn sàng nhận ký tự.

---

## 2. Kịch Bản Playwright Mẫu (`codex-sdk-list.spec.ts`)

```typescript
import { test, expect } from '@playwright/test';

test.describe('Codex SDK Thread List E2E', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    if (page.url().includes('auth/realms')) {
      await page.fill('#username', 'lamld');
      await page.fill('#password', 'Zzxx25102001');
      await page.click('#kc-login');
      await page.waitForNavigation();
    }
  });

  test('TC-FE-PAGE-E2E-02: Next and Prev cursor pagination', async ({ page }) => {
    let callCount = 0;
    await page.route('**/v1/codex-sdk/threads*', async (route) => {
      callCount++;
      const url = route.request().url();
      if (url.includes('cursor=cursor_page_2')) {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ data: { data: [{ id: 't-2', previewText: 'Page 2' }], nextCursor: null } }),
        });
      } else {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ data: { data: [{ id: 't-1', previewText: 'Page 1' }], nextCursor: 'cursor_page_2' } }),
        });
      }
    });

    await page.goto('/codex-sdk/threads');
    const nextBtn = page.locator('button:has-text("Trang sau")');
    const prevBtn = page.locator('button:has-text("Trang trước")');

    await expect(prevBtn).toBeDisabled();
    await nextBtn.click();
    await expect(prevBtn).toBeEnabled();
    await expect(page.locator('app-table')).toContainText('Page 2');

    await prevBtn.click();
    await expect(prevBtn).toBeDisabled();
    await expect(page.locator('app-table')).toContainText('Page 1');
  });
});
```

---

## 3. Lệnh Thực Thi

```powershell
npx playwright test e2e/codex-sdk-list.spec.ts
```
