# External Integrations

**Analysis Date:** 2026-09-05

## APIs & External Services

**AI & LLM Providers:**
- OpenAI / ChatGPT API - LLM inference and agent reasoning via Codex SDK
  - SDK/Client: `@openai/codex`, `@anthropic-ai/claude-code`, `dev.langchain4j:langchain4j-core`
  - Auth: `CODEX_API_KEY`, `OPENAI_API_KEY`, device-auth via ChatGPT login (`auth.json`)
  - Endpoints / URL: `CODEX_OPENAI_BASE_URL`, `OPENAI_BASE_URL`
- Model Context Protocol (MCP) Runtime:
  - Services: Facebook MCP (`services/mcp-platform/facebookmcp`), MongoDB MCP, Keycloak MCP, Elasticsearch MCP, Kubernetes MCP
  - SDK/Client: `@modelcontextprotocol/sdk`, `spring-ai-starter-mcp-server-webflux`
  - Config: `catalog.yaml`, `CODEX_MCP_ENABLED`, `MDB_MCP_CONNECTION_STRING`

**Crypto & Financial Exchanges:**
- Binance USD-M Futures - Live cryptocurrency market data, order placement, and position tracking
  - SDK/Client: `io.github.binance:binance-derivatives-trading-usds-futures` (`services/trade-bot-mcrs`)
  - Base URL: `BINANCE_USDM_BASE_URL` (default: `https://fapi.binance.com`)
  - Auth: Binance API Key & Secret via runtime configuration

**Social & Platform Automation:**
- Facebook Graph / Automation Bridge - Facebook page and interaction tooling
  - SDK/Client: `agentic-facebook` Python bridge (`services/mcp-platform/facebookmcp/bridge.py`)
  - Runtime: Python subprocess spawned by Node MCP server

## Data Storage

**Databases:**
- MongoDB (Primary NoSQL Document Store):
  - Used by: `services/ai-agent-mcrs`, `services/trade-bot-mcrs`, `services/file-mcrs`, `services/develop-tool-consumer`, `services/job-service`, `services/codex-sdk-service`
  - Connection: `MONGODB_URI`, `MONGODB_DATABASE`, `MONGODB_DB`
  - Client: `spring-boot-starter-data-mongodb` (`MongoTemplate` / Spring Data Repositories in Java), `mongodb` (Node.js native driver), `mongoose` (in `services/job-service`)
- PostgreSQL (Relational BPMN State):
  - Used by: Flowable Process Engine in `services/ai-agent-mcrs`
  - Connection: `FLOWABLE_DB_HOST`, `FLOWABLE_DB_PORT`, `FLOWABLE_DB_NAME`, `FLOWABLE_DB_USERNAME`, `FLOWABLE_DB_PASSWORD`
  - Client: JDBC with `org.postgresql:postgresql` driver (`flowable-spring-boot-starter-process`)

**File Storage:**
- File Management Microservice (`services/file-mcrs`) for upload/download and asset serving
- Kubernetes Persistent Volumes provisioned by Longhorn (`11.longhorn` CSI storage class)
- Object Storage: Cloudflare R2 (S3-compatible) for Velero cluster backup archives (`s3Url: https://*.r2.cloudflarestorage.com`, bucket: `velero-backup`)

**Caching & Messaging:**
- Redis:
  - Distributed cache, session storage, and pub/sub message bus (`trade-bot:realtime:progress` channel)
  - Connection: `REDIS_HOST`, `REDIS_PORT`, `REDIS_USERNAME`, `REDIS_PASSWORD`, `REDIS_URL`, `REDIS_PREFIX`
  - Client: `spring-boot-starter-data-redis` (Lettuce in Java), `redis` (Node.js)
- Caffeine Cache:
  - In-process high-performance local memory cache in Java services (`com.github.ben-manes.caffeine`)
- Apache Kafka:
  - Distributed event streaming and background job consumption
  - Used by: `services/develop-tool-consumer` and `libs/develop-tool-core-lib`
  - Client: `org.springframework.kafka:spring-kafka`

## Authentication & Identity

**Auth Provider:**
- Keycloak Identity & Access Management (OIDC / OAuth 2.0)
  - Realm: `develop_tool_realm`
  - Issuer URI: `OAUTH2_ISSUER_URI`, `KEYCLOAK_ISSUER_URI`
  - Token Endpoint: `OAUTH2_TOKEN_URI`
  - JWKS Endpoint: `KEYCLOAK_JWKS_URI`
  - Implementation:
    - Frontend: `keycloak-js` in `web/dev-tool-web`
    - Java Microservices: `spring-boot-starter-oauth2-resource-server` & `spring-boot-starter-oauth2-client` in `libs/develop-tool-core-lib`
    - Node.js Microservices: `jose` JWT verification against Keycloak JWKS in `services/codex-sdk-service` and `services/job-service`
- Service-to-Service & Machine Authentication:
  - Keycloak Client Credentials: `SERVICE_CLIENT_ID`, `SERVICE_CLIENT_SECRET`, `AI_AGENT_MCRS_CLIENT_ID`, `AI_AGENT_MCRS_CLIENT_SECRET`
  - Static API Tokens for admin/agent endpoints: `API_TOKEN`, `CODEX_API_TOKEN`, `CODEX_SDK_API_TOKEN`, `X_API_KEY`
  - Shared Callback Security: `AI_AGENT_SECURITY_SECRET_KEY`

## Monitoring & Observability

**Error Tracking:**
- Centralized Elasticsearch log collector across services
  - Configuration: `LOG_ELASTIC_BASE_URL`, `LOG_ELASTIC_URL`, `LOG_ELASTIC_USERNAME`, `LOG_ELASTIC_PASSWORD`, `LOG_ELASTIC_INDEX_PREFIX`

**Logs:**
- Java Services: Apache Log4j2 (`org.springframework.boot:spring-boot-starter-log4j2`) with structured JSON formatting
- Node.js Services: Custom batching Elasticsearch HTTP logger with retry backoff and queue buffer (`services/codex-sdk-service/src/shared/logger/`, `services/job-service/src/shared/logger/`)

**Metrics & Health:**
- Spring Boot Actuator with Micrometer Prometheus Registry (`/actuator/health`, `/actuator/prometheus`)
- Prometheus & Grafana stack running in Kubernetes (`infra/server-install/k8s-deployment/charts/9.monitoring`)

## CI/CD & Deployment

**Hosting:**
- Kubernetes Cluster managed via Rancher (`infra/server-install/k8s-deployment/`)
- Ingress: NGINX Ingress Controller (`1.nginx`) with `cert-manager` (`2.cert-manager`) for TLS termination

**CI Pipeline:**
- Jenkins with dynamically provisioned Kubernetes Jenkins agents (`4.jenkins`, `4.jenkins-agent`)
- Package Registries:
  - Maven: GitHub Packages (`https://maven.pkg.github.com/devToolApplication/develop-tool-core-lib`)
  - npm: GitHub Packages (`https://npm.pkg.github.com/@devToolApplication/develop-tool-nodejs-core-lib`)
  - Nexus Repository OSS (`10.nexus`)

## Environment Configuration

**Required env vars:**
- `MONGODB_URI` / `MONGODB_DATABASE`: MongoDB connection string and database name
- `REDIS_HOST` / `REDIS_PORT` / `REDIS_PASSWORD`: Redis cache and pub/sub connection
- `OAUTH2_ISSUER_URI` / `KEYCLOAK_ISSUER_URI`: Keycloak OpenID Connect discovery URI
- `FLOWABLE_DB_HOST` / `FLOWABLE_DB_NAME` / `FLOWABLE_DB_USERNAME` / `FLOWABLE_DB_PASSWORD`: Flowable BPMN PostgreSQL connection
- `CODEX_SDK_API_URL` / `AI_AGENT_MCRS_URL`: Inter-service endpoint routing
- `LOG_ELASTIC_BASE_URL`: Elasticsearch log aggregation server URL
- `CODEX_API_KEY` / `OPENAI_API_KEY`: LLM API authentication keys

**Secrets location:**
- Kubernetes Manifests: `infra/server-install/k8s-deployment/manifests/secrets/` (`mongodb-secret.yaml`, `redis-secret.yaml`, `kafka-secret.yaml`, `keycloak-secret.yaml`, `elastic-log-secret.yaml`, `ai-agent-mcrs-secret.yaml`, `job-service-secret.yaml`)
- Local Development: Root and service-level `.env` files (git-ignored)

## Webhooks & Callbacks

**Incoming:**
- Flowable BPMN message / signal catch events and user task completions (`services/ai-agent-mcrs`)
- Agent execution callback routes (`services/codex-sdk-service` callback module with signature verification)
- WebSocket / STOMP real-time client subscriptions for workflow progress (`/topic/progress`, `/topic/workflow-execution`)

**Outgoing:**
- FeignClient synchronous HTTP calls from `ai-agent-mcrs` to `codex-sdk-service` and `file-mcrs`
- WebClient SSE / streaming execution calls from `ai-agent-mcrs` to AI execution backends
- Binance REST API orders and WebSocket streaming tickers (`services/trade-bot-mcrs`)
- Redis Pub/Sub progress publishing on `trade-bot:realtime:progress` channel

---

*Integration audit: 2026-09-05*
