# Dedicated Subagent Routing, Bootstrap & Development Enforcement

## ⚠️ BẮT BUỘC: ĐỌC TÀI LIỆU QUY CHUẨN TRƯỚC KHI IMPLEMENT

Trước khi thực hiện bất kỳ task nào liên quan đến Backend hoặc Frontend, AI Agent **BẮT BUỘC PHẢI ĐỌC KỸ** các file hướng dẫn chuẩn hóa:

- **Frontend Development:** Đọc `docs/note/fe-note.md`
  - Bắt buộc dùng 100% Shared UI Components của dự án.
  - Cấu hình chuẩn `TableConfig<T>`.
  - Quản lý đa ngôn ngữ qua i18n (`account-management.i18n.json`).
  - Thiết kế Mobile-First & Responsive.
  - **Bắt buộc viết Unit & Integration Tests (`.spec.ts`)**, verify `npm run test` pass 100%.

- **Backend Development:** Đọc `docs/note/be-note.md`
  - Service bắt buộc `extends BaseService` và sử dụng `mapperUtil`.
  - Kiến trúc 3 lớp: Service -> Storage Layer (`Storage`) -> Repository / MongoTemplate.
  - Sử dụng chuẩn `BusinessException` & `BusinessErrorCode`.
  - File encoding UTF-8 No BOM.
  - **Bắt buộc viết Unit Tests (`*ServiceTest.java`)**, verify `mvn test` pass 100%.

---

## Danh sách Dedicated Subagents có sẵn

| Subagent Name | Role | Primary Use Case |
|---|---|---|
| `ba-agent` | Business Analyst | Phân tích yêu cầu, bóc tách User Story, Acceptance Criteria, Functional Spec |
| `architect-agent` | Solution / System Architect | Thiết kế kiến trúc, Module folder layout, API Contracts, 2-3 phương án & Trade-off, ADR |
| `dev-be-agent` | Backend Developer | Code Java/Spring Boot/Node/Go/Python, DB query, TDD, Clean Code, SRP, xử lý lỗi |
| `dev-fe-agent` | Frontend Developer | Code Angular/React/Vue, UI components, responsive layout, styling, token system |
| `test-qa-agent` | QA / Test Engineer | Lên test case song song, Local Live Test (chạy service, test FE->BE), Pre-CD Gate |
| `bpmn-agent` | BPMN Specialist | Thiết kế, thẩm định và ánh xạ luồng BPMN 2.0 |
| `trade-analysis-agent` | Trading Specialist | Phân tích quy tắc giao dịch, chỉ báo kỹ thuật, rule engine, risk management |

## Quy định Spawn Subagent trong Codex

1. **Chỉ định rõ Subagent:** Khi gọi subtask/spawn agent, phải chỉ định chính xác tên subagent: `ba-agent`, `architect-agent`, `dev-be-agent`, `dev-fe-agent`, `test-qa-agent`, `bpmn-agent`, `trade-analysis-agent`.
2. **Không tự tạo prompt agent mới:** Không định nghĩa lại system prompt mới từ đầu cho subagent; subagent sẽ tự động load cấu hình trong `~/.codex/agents/{name}.toml`.
3. **Truyền đúng context:** Cung cấp input đầu vào rõ ràng (task ID, requirements, contract, files liên quan, expected output) để agent thực thi độc lập.

---

## Submodule Management
Repository sử dụng git submodules. Luôn đảm bảo submodules được sync và update đầy đủ:
```bash
git submodule sync --recursive
git submodule update --init --recursive
```