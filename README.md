# dev-tool-project

Workspace repository tổng hợp toàn bộ hệ sinh thái dự án **Dev Tool Application**, quản lý tất cả microservices, frontend, core library và deployment infra thông qua **Git Submodules**.

---

## 1. Cấu trúc Submodules

| Thư mục Submodule | Ngôn ngữ / Stack | Repository | Mô tả chức năng |
| :--- | :--- | :--- | :--- |
| **web/dev-tool-web** | Angular 21 / TypeScript | [dev-tool-web](https://github.com/devToolApplication/dev-tool-web) | Frontend Single Page Application |
| **libs/develop-tool-core-lib** | Java 21 / Maven | [develop-tool-core-lib](https://github.com/devToolApplication/develop-tool-core-lib) | Thư viện Java dùng chung (n.devTool.core.*) |
| **services/ai-agent-mcrs** | Java 21 / Spring Boot 3.5 | [ai-agent-mcrs](https://github.com/devToolApplication/ai-agent-mcrs) | AI Agent orchestrator, Flowable workflow runtime |
| **services/trade-bot-mcrs** | Java 21 / Spring Boot | [trade-bot-mcrs](https://github.com/devToolApplication/trade-bot-mcrs) | Phân tích trading rules, backtest & strategy |
| **services/file-mcrs** | Java 21 / Spring Boot | [file-mcrs](https://github.com/devToolApplication/file-mcrs) | Quản lý upload, download file & assets |
| **services/develop-tool-consumer** | Java 21 / Spring Boot | [develop-tool-consumer](https://github.com/devToolApplication/develop-tool-consumer) | Kafka consumer & background processing |
| **services/job-service** | Node.js / TypeScript | [job-service](https://github.com/devToolApplication/job-service) | Lập lịch và quản lý cron jobs |
| **services/codex-sdk-service** | Node.js / TypeScript | [codex-sdk-service](https://github.com/devToolApplication/codex-sdk-service) | Codex SDK API bridge service |
| **services/mcp-platform** | TypeScript | [mcp-platform](https://github.com/devToolApplication/mcp-platform) | Registry & MCP runtime platform |
| **infra/server-install** | Docker / Shell | [server-install](https://github.com/devToolApplication/server-install) | Hạ tầng Docker & k8s deployment |

---

## 2. Hướng dẫn Clone & Setup

### Cách 1: Clone toàn bộ dự án cùng tất cả submodules (Khuyên dùng)
\\\ash
git clone --recurse-submodules https://github.com/devToolApplication/dev-tool-project.git
cd dev-tool-project
\\\

### Cách 2: Nếu đã clone repo gốc trước đó
\\\ash
git clone https://github.com/devToolApplication/dev-tool-project.git
cd dev-tool-project

# Khởi tạo và pull code các submodule
git submodule sync --recursive
git submodule update --init --recursive
\\\

---

## 3. Cập nhật Submodules

### Pull code mới nhất cho toàn bộ submodule
\\\ash
git submodule update --remote --merge
\\\

### Push commit cho tất cả submodules
Dùng script có sẵn trong repo:
- Windows: \push-all-submodules.bat\
- Linux/macOS: \./push-all-submodules.sh\

---

## 4. Yêu cầu Môi trường

- **Java:** JDK 21+
- **Node.js:** Node 20+, npm 10+
- **Build Tools:** Maven 3.9+, Angular CLI 21
- **Infra:** MongoDB, Redis, Apache Kafka, Keycloak, Elasticsearch (chạy qua Docker tại \infra/server-install/\)
