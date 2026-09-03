# Account Management Feature Design

## 1. Overview
Hệ thống quản lý tài khoản bên thứ 3 (OpenAI/ChatGPT, Google, Claude, Twitter, GitHub, v.v.) phục vụ dev tool và các tác vụ automation, AI Agent. Tính năng cung cấp màn hình quản lý tập trung với đầy đủ chức năng CRUD, ẩn/hiện mật khẩu, tự động tính toán mã 2FA TOTP 6 số theo thời gian thực (Live OTP) và 1-click copy thông tin.

## 2. Architecture & Tech Stack
- **Backend:** `services/ai-agent-mcrs` (Spring Boot 3, Java 21, MongoDB, Spring Security).
- **Frontend:** `web/dev-tool-web` (Angular 18+, PrimeNG / Tailwind CSS shared UI components, RxJS, TOTP algorithm).

## 3. Backend Design (`ai-agent-mcrs`)

### 3.1 Data Model: `AccountEntity`
- Collection: `ai_agent_account`
- Package: `com.lamld.aiAgent.modules.account.infrastructure.entity`
- Fields:
  - `id`: String (ObjectId)
  - `name`: String (Tên định danh tài khoản, ví dụ: "GPT Plus Dev Team")
  - `type`: String (Phân loại: `OPENAI`, `GOOGLE`, `CLAUDE`, `GITHUB`, `TWITTER`, `CUSTOM`)
  - `username`: String (Email hoặc Username đăng nhập)
  - `password`: String (Mật khẩu đăng nhập)
  - `twoFactorSecret`: String (TOTP Secret Key Base32 để sinh OTP 6 số)
  - `backupCodes`: List<String> (Danh sách mã dự phòng nếu có)
  - `status`: Status (`ACTIVE`, `INACTIVE`, `LOCKED`, `EXPIRED`)
  - `note`: String (Ghi chú mô tả)
  - `metadata`: Map<String, Object> (Thông tin mở rộng: proxy, recovery email, phone, config kèm theo)
  - `tags`: List<String> (Tag phân loại / lọc)
  - `createdAt`, `updatedAt`, `createdBy`, `updatedBy`: Kế thừa từ `BaseEntity`.

### 3.2 API Contracts (`/v1/admin/accounts`)
- `POST /v1/admin/accounts`: Tạo mới Account (`AccountCreateDto`)
- `PUT /v1/admin/accounts/{id}`: Cập nhật Account (`AccountUpdateDto`)
- `GET /v1/admin/accounts/{id}`: Lấy chi tiết Account
- `GET /v1/admin/accounts/page`: Phân trang, tìm kiếm theo keyword, lọc theo `type`, `status` (`Pageable`, `BasePageResponse<AccountResponse>`)
- `DELETE /v1/admin/accounts/{id}`: Xóa Account (soft-delete hoặc hard-delete)
- `GET /v1/admin/accounts/{id}/otp`: Lấy mã OTP 6 số hiện tại + remaining seconds (fallback cho BE/automation).

## 4. Frontend Design (`dev-tool-web`)

### 4.1 Module Structure
- `src/app/features/account-management/`
  - `account-management.module.ts`
  - `account-management.routes.ts`
  - `pages/account-list/`:
    - `account-list.component.ts` / `.html` / `.scss`
  - `components/`:
    - `account-form-dialog/`: Dialog Thêm / Sửa Account
    - `account-detail-dialog/`: Dialog xem chi tiết thông tin mở rộng (metadata, backup codes, ghi chú)
  - `services/`:
    - `account.service.ts`: Gọi REST API backend
    - `totp.service.ts`: Tính toán TOTP 6 số và chu kỳ 30s trực tiếp trên client để phản hồi tức thì
  - `models/`:
    - `account.model.ts`: Interface DTOs, Enums, Filters

### 4.2 UI/UX Layout & Interactivity
- **Side Menu Navigation:** Thêm entry `/accounts` (Label: `layout.menu.accountManagement`, Icon: `pi pi-id-card`).
- **Table Columns:**
  1. `Type`: Tag màu nhận diện thương hiệu (OpenAI, Google, Claude, GitHub...).
  2. `Tên & Username`: Hiển thị name + username kèm nút copy 1-click có tooltip & toast feedback.
  3. `Password`: Masked `••••••••` kèm icon Toggle Xem/Ẩn và nút copy 1-click.
  4. `2FA Live OTP`: Mã 6 số lớn màu xanh lá (ví dụ: `839 201`), progress bar / countdown số giây còn lại (30s cycle), nút copy 1-click.
  5. `Trạng thái`: Badge Active (Xanh) / Inactive (Xám) / Locked (Đỏ).
  6. `Thao tác`: Xem chi tiết, Sửa, Xóa (với xác nhận confirm dialog).
- **Search & Filter:**
  - Keyword search input (Name, Username, Note).
  - Filter dropdown theo Type & Status.
  - Phân trang Table qua BE API.

## 5. Security & Edge Cases
- **Bảo mật 2FA Secret & Password:** Giới hạn quyền admin truy cập endpoint, validate đúng định dạng Base32 cho TOTP secret.
- **Tính toán OTP:** Hỗ trợ tính TOTP cả ở FE (cho UX mượt mà thời gian thực không cần spam request) lẫn API BE (cho các service automation cần lấy OTP tự động).
- **Copy Feedback:** Tích hợp Toast notification và Clipboard API an toàn.
