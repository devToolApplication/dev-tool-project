# Thiết kế User Task Screen Framework

## 1. Trạng thái tài liệu

- Trạng thái: Đã duyệt hướng kiến trúc và breakdown phase.
- Nguồn đầu vào: `D:\.Download\User_Task_Screen_Plan_So_Bo.md`.
- Phạm vi hệ thống:
  - Frontend: `web/dev-tool-web`.
  - Backend: `services/ai-agent-mcrs`.
  - Shared backend contract: `libs/develop-tool-core-lib`.
  - Workflow runtime: Flowable 7.2.
- Mục tiêu tài liệu: khóa thiết kế chi tiết cho 18 phase trước khi viết implementation plan.

## 2. Mục tiêu

Xây dựng một luồng User Task dùng chung cho người dùng cuối:

```text
/tasks
  -> User Task Inbox
  -> /tasks/:taskId
  -> TaskHostPage
  -> TaskScreenRegistry(formKey)
  -> TaskShell
  -> Specific Task Screen
  -> Claim hoặc Action API
  -> Flowable
```

Hệ thống phải:

1. Dùng `formKey` của Flowable làm discriminator duy nhất để chọn màn hình.
2. Tách API user-facing khỏi API admin hiện tại.
3. Chỉ trả dữ liệu whitelist cần cho từng màn hình.
4. Kiểm tra quyền ở backend theo assignee, candidate user, candidate realm-role và admin override.
5. Hỗ trợ active task, completed task read-only, history, claim, action, idempotency và concurrency.
6. Chuyển bốn loại màn hình đầu tiên sang framework mới:
   - `KOC_CANDIDATE_APPROVAL`
   - `KOC_DISCOVERY_DECISION`
   - `MANUAL_2FA_CONFIRMATION`
   - `APPROVAL`
7. Giữ process instance cũ và màn admin cũ hoạt động trong giai đoạn cutover.

## 3. Ngoài phạm vi

Phiên bản đầu không xây dựng:

- Dynamic form hoặc JSON schema rendering engine.
- Attachment.
- Comment thread độc lập ngoài action history.
- Delegate, reassign hoặc unclaim trên user-facing UI.
- Các formKey `FORM`, `REVIEW`, `SIGN`, `UPLOAD`, `SELECT`.
- MongoDB audit collection riêng.
- Redis idempotency.
- Migration cưỡng bức process instance đang chạy sang process definition mới.
- Distributed exactly-once giữa Flowable PostgreSQL và MongoDB.

## 4. Quyết định kiến trúc đã khóa

### 4.1. Frontend

- Tạo feature NgModule độc lập `features/user-task`.
- Route chuẩn:
  - `/tasks`
  - `/tasks/:taskId`
- `TaskHostStore` dùng Angular Signals và được provide tại `TaskHostPage`, không provide ở root hoặc feature module.
- `TaskScreenRegistry` là registry tĩnh, typed, ánh xạ chính xác `formKey` sang component và presentation contract.
- Không fallback từ `formKey` sang `taskDefinitionKey`, task name hoặc URL.
- Backend là nguồn sự thật của `claimable`, `readOnly` và `allowedActions`.
- UI chỉ dùng Shared UI Components và design tokens hiện có.

### 4.2. Backend

Giữ User Task trong module `workflowprocess`, nhưng tách một vertical slice user-facing:

```text
modules/workflowprocess/
├── api/usertask/
├── application/usertask/
├── domain/usertask/
└── infrastructure/flowable/storage/
```

- `UserTaskService extends BaseService`.
- Service chỉ gọi `UserTaskStorage`, policy, projector và action mapper.
- `UserTaskStorage` đóng gói Flowable `TaskService`, `HistoryService`, identity links và comments.
- Không gọi API Flowable trực tiếp từ controller.
- `UserTaskDefinitionRegistry` là registry backend duy nhất theo `formKey`; mỗi definition chứa projector, action mapper và tập action hợp lệ.
- Projector khai báo đúng các variable cần đọc.
- Action mapper không nhận process variables hoàn chỉnh từ FE.
- API admin `/v1/admin/workflows/**` tiếp tục tồn tại và giữ quyền admin.

### 4.3. BPMN

- `formKey` là contract bắt buộc của User Task user-facing.
- BPMN version mới được deploy bất biến.
- Process instance cũ tiếp tục chạy trên deployment cũ.
- Candidate group ID trùng trực tiếp với Keycloak realm-role.
- `RETURN` là outcome BPMN; backend không dùng Change Activity State.

## 5. Contract xuyên phase

### 5.1. Form key và action

| formKey | Action hợp lệ | Process variables do backend tạo |
|---|---|---|
| `KOC_CANDIDATE_APPROVAL` | `APPROVE`, `REJECT` | `approved`, `selectedCandidates` |
| `KOC_DISCOVERY_DECISION` | `FIND_MORE`, `STOP` | `discoveryDecision` và cập nhật `flowData.variableData.discoveryDecision` |
| `MANUAL_2FA_CONFIRMATION` | `CONFIRM` | `manualApproved` |
| `APPROVAL` | `APPROVE`, `REJECT`, `RETURN` | `taskOutcome` |

Không có action mặc định cho formKey không được đăng ký.

### 5.2. API user-facing

```text
GET  /v1/user-tasks
GET  /v1/user-tasks/{taskId}
GET  /v1/user-tasks/{taskId}/history
POST /v1/user-tasks/{taskId}/claim
POST /v1/user-tasks/{taskId}/actions
```

Query chính của inbox:

| Query | Giá trị |
|---|---|
| `view` | `MY`, `CLAIMABLE`, `ALL` |
| `status` | `ACTIVE`, `COMPLETED` |
| `keyword` | Tìm theo task name, workflow name hoặc business key |
| `formKey` | Một formKey chính xác |
| `businessKey` | Business key của process, dùng thay cho filter `campaignId` cũ |
| `dueFrom`, `dueTo` | ISO-8601 instant |
| `page`, `size`, `sort` | Chuẩn pagination hiện có |

Quy tắc:

- Mặc định `view=MY`, `status=ACTIVE`.
- `view=ALL` chỉ dành cho admin.
- `view=CLAIMABLE&status=COMPLETED` trả `400 INVALID_TASK_QUERY`.
- `view=MY&status=COMPLETED` chỉ trả historic task có assignee hoặc structured action actor là user hiện tại.
- `view=ALL&status=COMPLETED` chỉ dành cho admin.
- Active task không có `formKey` bị loại khỏi API user-facing.
- Task có `formKey` chưa đăng ký vẫn xuất hiện trong inbox, nhưng detail là unsupported và không có action.

### 5.3. Task summary

```json
{
  "id": "task-1",
  "name": "Human Approval - Select KOC Candidates",
  "formKey": "KOC_CANDIDATE_APPROVAL",
  "status": "ACTIVE",
  "assignee": "lamld",
  "processInstanceId": "process-1",
  "workflowName": "KOC Candidate Discovery",
  "businessKey": "campaign-1",
  "createdAt": "2026-09-08T08:00:00Z",
  "dueAt": null,
  "priority": 50,
  "claimable": false,
  "readOnly": false,
  "supported": true
}
```

List API không trả `content`, process variables hoặc secrets.

### 5.4. Task detail

```json
{
  "id": "task-1",
  "name": "Human Approval - Select KOC Candidates",
  "formKey": "KOC_CANDIDATE_APPROVAL",
  "status": "ACTIVE",
  "assignee": "lamld",
  "processInstanceId": "process-1",
  "workflowName": "KOC Candidate Discovery",
  "businessKey": "campaign-1",
  "createdAt": "2026-09-08T08:00:00Z",
  "completedAt": null,
  "claimable": false,
  "readOnly": false,
  "supported": true,
  "allowedActions": ["APPROVE", "REJECT"],
  "content": {}
}
```

Quy tắc unsupported:

- `formKey` không rỗng nhưng FE/BE chưa hỗ trợ: API detail trả `200`, `supported=false`, `readOnly=true`, `allowedActions=[]`, `content=null`.
- Action trên task unsupported trả `422 UNSUPPORTED_TASK_FORM_KEY`.
- Task không có `formKey` không thuộc user-facing API và trả `404 USER_TASK_NOT_FOUND`.

### 5.5. Action request

```json
{
  "requestId": "b5733b35-06c6-493e-8068-d952c77a5a1e",
  "action": "APPROVE",
  "variables": {
    "approvedCandidateIds": ["fb-koc-01", "fb-koc-03"]
  },
  "comment": "Đồng ý danh sách đề xuất"
}
```

Quy tắc:

- `requestId` bắt buộc là UUID.
- `comment` được trim ở backend, tối đa 2.000 ký tự.
- `APPROVE`: comment tùy chọn.
- `REJECT`, `RETURN`: comment bắt buộc.
- `FIND_MORE`, `STOP`, `CONFIRM`: comment tùy chọn.
- `variables` chỉ chứa lựa chọn tối thiểu của người dùng.
- Backend dựng process variables từ dữ liệu server-side.

Action response:

```json
{
  "taskId": "task-1",
  "requestId": "b5733b35-06c6-493e-8068-d952c77a5a1e",
  "action": "APPROVE",
  "status": "COMPLETED",
  "completedAt": "2026-09-08T08:10:00Z"
}
```

### 5.6. History response

```json
[
  {
    "type": "CLAIM",
    "actor": "lamld",
    "action": null,
    "comment": null,
    "createdAt": "2026-09-08T08:05:00Z"
  },
  {
    "type": "ACTION",
    "actor": "lamld",
    "action": "APPROVE",
    "comment": "Đồng ý danh sách đề xuất",
    "createdAt": "2026-09-08T08:10:00Z"
  }
]
```

History được dựng từ Flowable task history và structured comments. Không trả raw comment JSON cho FE.

### 5.7. Error contract

`BaseResponse` bổ sung `errorCode` nhưng giữ các field hiện tại:

```json
{
  "traceId": "trace-1",
  "path": "/v1/user-tasks/task-1/actions",
  "status": 409,
  "errorCode": "TASK_ACTION_CONFLICT",
  "errorMessage": "Task was completed by another request"
}
```

Error code bắt buộc:

| Enum constant | HTTP | Serialized `errorCode` |
|---|---|---|
| `USER_TASK_INVALID_QUERY` | 400 | `INVALID_TASK_QUERY` |
| `USER_TASK_INVALID_ACTION` | 400 | `INVALID_TASK_ACTION` |
| `USER_TASK_INVALID_PAYLOAD` | 400 | `INVALID_TASK_PAYLOAD` |
| `USER_TASK_COMMENT_REQUIRED` | 400 | `COMMENT_REQUIRED` |
| `USER_TASK_UNAUTHENTICATED` | 401 | `USER_TASK_UNAUTHENTICATED` |
| `USER_TASK_ACCESS_DENIED` | 403 | `TASK_ACCESS_DENIED` |
| `USER_TASK_NOT_FOUND` | 404 | `USER_TASK_NOT_FOUND` |
| `USER_TASK_ALREADY_CLAIMED` | 409 | `TASK_ALREADY_CLAIMED` |
| `USER_TASK_ALREADY_COMPLETED` | 409 | `TASK_ALREADY_COMPLETED` |
| `USER_TASK_ACTION_CONFLICT` | 409 | `TASK_ACTION_CONFLICT` |
| `USER_TASK_UNSUPPORTED_FORM_KEY` | 422 | `UNSUPPORTED_TASK_FORM_KEY` |

### 5.8. Authorization matrix

| Trạng thái | User thường | Candidate | Assignee | Admin |
|---|---|---|---|---|
| Active, chưa gán | Không thấy | Xem và claim | Không áp dụng | Xem, claim, action |
| Active, gán cho chính mình | Không áp dụng | Xem | Xem và action | Xem và action |
| Active, gán người khác | Không thấy | Xem read-only | Không áp dụng | Xem và action |
| Completed | Không thấy | Chỉ thấy nếu là assignee/actor | Xem read-only | Xem read-only |

Candidate group chỉ lấy từ `realm_access.roles`. Resource roles không được dùng để match Flowable candidate group.

### 5.9. Idempotency và transaction

- Structured action comment dùng type riêng `USER_TASK_ACTION`.
- Comment chứa `requestId`, action, actor và action response.
- Ghi comment và `TaskService.complete` chạy trong cùng transaction:
  `@Transactional("flowableTransactionManager")`.
- Retry cùng `taskId`, `requestId` và actor trả action response đã lưu.
- Cùng `requestId` nhưng actor khác trả `409 TASK_ACTION_CONFLICT`.
- Request ID khác trên task completed trả `409 TASK_ALREADY_COMPLETED`.
- Khi optimistic lock xảy ra, backend đọc lại history:
  - Nếu tìm thấy cùng request ID: trả kết quả cũ.
  - Nếu không: trả `409 TASK_ACTION_CONFLICT`.
- Cam kết idempotency chỉ tồn tại trong thời gian Flowable history/comments còn được giữ.
- Không tuyên bố distributed exactly-once cho side effect MongoDB. Delegate ghi MongoDB phải có natural key hoặc unique index; KOC candidate tiếp tục dựa trên unique `external_profile_id`.

## 6. Cấu trúc frontend mục tiêu

```text
features/user-task/
├── api/
│   ├── user-task-api.service.ts
│   └── user-task-api.service.spec.ts
├── components/
│   ├── task-action-bar/
│   ├── task-header/
│   ├── task-history/
│   ├── task-info/
│   └── task-shell/
├── models/
│   ├── user-task.model.ts
│   ├── user-task.dto.ts
│   └── user-task.config.ts
├── pages/
│   ├── task-inbox/
│   └── task-host/
├── registry/
│   ├── task-screen.registry.ts
│   └── task-screen.registry.spec.ts
├── screens/
│   ├── generic-approval/
│   ├── koc-candidate-approval/
│   ├── koc-discovery-decision/
│   ├── manual-2fa-confirmation/
│   └── unsupported-task/
├── store/
│   ├── task-host.store.ts
│   └── task-host.store.spec.ts
├── user-task.module.ts
└── user-task.routes.ts
```

## 7. Cấu trúc backend mục tiêu

```text
modules/workflowprocess/
├── api/usertask/
│   ├── UserTaskController.java
│   ├── request/UserTaskActionRequest.java
│   └── response/
├── application/usertask/
│   ├── UserTaskService.java
│   ├── UserTaskPolicyService.java
│   └── UserTaskPrincipalFactory.java
├── domain/usertask/
│   ├── UserTaskAction.java
│   ├── UserTaskDefinition.java
│   ├── UserTaskDefinitionRegistry.java
│   ├── UserTaskFormKey.java
│   ├── UserTaskPrincipal.java
│   ├── UserTaskSnapshot.java
│   └── projector/
├── infrastructure/flowable/storage/
│   └── UserTaskStorage.java
└── infrastructure/flowable/usertask/
    ├── action/
    ├── comment/
    └── projector/
```

Projector và action mapper được gom trong một `UserTaskDefinition` đăng ký theo `UserTaskFormKey`. Không dùng reflection scan theo string class name và không có generic fallback mapper.

## 8. Dependency graph

```text
01 Test Safety
  ├── 02 Deployment Safety
  └── 03 Error Contract
        └── 04 Authenticated Principal
              └── 05 Authorization Policy
                    └── 06 Flowable Storage
                          ├── 07 List and Detail API
                          ├── 08 Projectors
                          ├── 09 History API
                          └── 10 Claim and Allowed Actions
                                └── 11 Action API
                                      └── 12 Idempotency and Concurrency

02 + 08 + 10 + 11
  └── 13 BPMN Contract and Version

03 + 07 + 08
  └── 14 Frontend Foundation
        ├── 15 Task Inbox
        └── 16 Task Host and Shell
              └── 17A/17B/17C/17D Specific Screens

13 + 15 + 16 + 17A/17B/17C/17D
  └── 18 Cutover and Release Gate
```

Các phase 08, 09 và 10 có thể triển khai song song sau phase 06 nếu ownership file không giao nhau.

## 9. Thiết kế từng phase

### Phase 01 - Test Safety Baseline

**Mục tiêu**

Biến `mvn test` thành gate an toàn, lặp lại được và không kết nối PostgreSQL/MongoDB từ xa.

**Thiết kế**

1. Gắn `@Tag("live")` cho các test phụ thuộc hạ tầng thật:
   - `FlowableFacebookHitlLiveTest`
   - `FlowableRealEngineTest`
   - `FlowableKocCandidateDiscoveryWorkflowTest`
   - `FlowableRealMultiStepTest`
2. Maven Surefire mặc định loại tag `live`.
3. Tạo Maven profile `live-flowable-tests` để chạy live tests có chủ đích.
4. Xóa toàn bộ host, username và password hard-code trong test. Live profile chỉ đọc:
   - `FLOWABLE_TEST_JDBC_URL`
   - `FLOWABLE_TEST_DB_USERNAME`
   - `FLOWABLE_TEST_DB_PASSWORD`
   - `MONGODB_TEST_URI`
5. Thiếu biến môi trường thì live test bị skip với lý do rõ ràng, không fallback sang endpoint mặc định.
6. Bổ sung H2 test-scope để các Flowable contract test mới chạy in-memory trong default suite.
7. Test unit hiện tại tiếp tục dùng Mockito; không khởi tạo Spring context nếu không cần.

**Đầu ra**

- Default Maven suite không chạm external state.
- Có một lệnh riêng cho live integration.
- Credential không còn nằm trong source test.

**Gate**

```text
.\mvnw.cmd test
.\mvnw.cmd compile
.\mvnw.cmd -Plive-flowable-tests test
```

Hai lệnh đầu phải pass không cần VPN, Docker hoặc service ngoài. Lệnh thứ ba chỉ chạy khi đủ biến môi trường.

**Tiêu chí hoàn thành**

- Tìm kiếm source không còn IP/database password hard-code trong `src/test`.
- Default test suite pass trên máy chỉ có JDK và Maven dependency cache.

**Không làm trong phase**

- Không sửa logic nghiệp vụ User Task.
- Không dựng full local stack.

### Phase 02 - Workflow Deployment Version Safety

**Mục tiêu**

Đảm bảo publish BPMN mới không xóa deployment đang phục vụ process instance cũ.

**Thiết kế**

1. Save draft chỉ lưu MongoDB, không deploy Flowable.
2. Update chỉ sửa `WorkflowVersionStatus.DRAFT`.
3. Publish thực hiện theo thứ tự:
   - Validate BPMN XML.
   - Deploy XML của draft hiện tại thành deployment mới.
   - Đánh dấu version hiện tại là `PUBLISHED`.
   - Gán `currentPublishedVersionId`.
   - Tạo draft kế tiếp bằng bản sao của published version, tăng version lên 1.
   - Gán `currentDraftVersionId` sang draft mới.
4. Published version bất biến; update trực tiếp version published bị từ chối.
5. `startWorkflow` chỉ dùng `currentPublishedVersionId`; không fallback sang draft.
6. Xóa workflow:
   - Chỉ cho phép khi workflow chưa từng publish.
   - Workflow đã publish trả conflict; không cascade-delete deployment.
7. Loại bỏ `deleteDeployment(..., true)` khỏi luồng update và publish.
8. Deployment cũ được giữ để active instance và historic admin UI tiếp tục hoạt động.

**Đầu ra**

- Lifecycle rõ ràng `DRAFT -> PUBLISHED -> next DRAFT`.
- Nhiều process definition version cùng tồn tại.
- API publish backend khớp với FE `publishWorkflow`.

**Gate**

- Unit test save draft không gọi Flowable deploy/delete.
- Unit test publish tạo deployment mới và draft kế tiếp.
- Engine test:
  - Start instance từ version 1 và dừng ở User Task.
  - Publish version 2.
  - Instance version 1 vẫn query và complete được.
  - Instance mới dùng version 2.

**Tiêu chí hoàn thành**

- Không còn code path update draft nào cascade-delete deployment.
- Process instance cũ không bị mất sau publish version mới.

**Không làm trong phase**

- Không cung cấp force-delete deployment published.
- Không migrate instance giữa hai definition version.

### Phase 03 - Structured Error Contract

**Mục tiêu**

Cho FE xử lý lỗi theo mã ổn định thay vì parse `errorMessage`.

**Thiết kế**

1. Thêm `errorCode` nullable vào `BaseResponse`.
2. Giữ nguyên overload `BaseResponse.error(...)` hiện tại để không phá consumer cũ.
3. Bổ sung overload nhận `errorCode`.
4. `GlobalExceptionHandler.handleBusinessException` trả `BusinessException.errorCode`.
5. Các handler framework dùng mã common tương ứng:
   - Validation: `COMMON_400`
   - Access denied: `COMMON_403`
   - Not found: `COMMON_404`
   - General error: `COMMON_500`
6. Bổ sung mã User Task và workflow deployment vào `BusinessErrorCode`.
7. FE `BaseResponse<T>` bổ sung `errorCode?: string`.
8. FE vẫn hiển thị `errorMessage` thật từ BE; `errorCode` dùng để chọn state hoặc hành vi.

**Đầu ra**

- Contract lỗi backward-compatible.
- Mọi lỗi User Task có HTTP status, `errorCode`, `errorMessage`, `traceId`.

**Gate**

- Core-lib unit test cho business, validation, access denied và general error.
- FE typecheck với field mới.
- Serialization test xác minh success response không bắt buộc có `errorCode`.

**Tiêu chí hoàn thành**

- `BusinessException` không còn mất `errorCode` tại GlobalExceptionHandler.

**Không làm trong phase**

- Không đổi toàn bộ error code của các module khác.

### Phase 04 - Authenticated User Principal

**Mục tiêu**

Tạo user context tin cậy từ JWT đã được Spring Security xác thực.

**Thiết kế**

1. `UserTaskController` nhận `JwtAuthenticationToken`.
2. `UserTaskPrincipalFactory` tạo immutable `UserTaskPrincipal` gồm:
   - `userId` từ `sub`.
   - `username` từ `preferred_username`.
   - `realmRoles` chỉ từ `realm_access.roles`.
   - `admin` từ authority `ROLE_ai_agent_admin`.
3. Thiếu hoặc rỗng `preferred_username` trả `401 USER_TASK_UNAUTHENTICATED`.
4. Candidate matching không dùng:
   - Header `X-Username`.
   - Header `username`.
   - JWT payload tự decode trong `RequestFilter`.
   - Resource roles.
5. `RequestFilter` tiếp tục phục vụ MDC/logging cho code cũ, nhưng không phải security source của User Task.

**Đầu ra**

- Một principal duy nhất được truyền qua service, policy và audit.
- Client không thể claim/action thay username khác bằng request body hoặc header.

**Gate**

- Unit test realm roles.
- Unit test resource roles không lọt vào candidate groups.
- Unit test thiếu username.
- Controller security test với JWT hợp lệ và JWT thiếu claim.

**Tiêu chí hoàn thành**

- User-facing claim API không nhận assignee.
- Không có User Task policy nào đọc `RequestFilter.getUsername()`.

**Không làm trong phase**

- Không refactor toàn bộ `RequestFilter` của hệ thống.

### Phase 05 - User Task Authorization Policy

**Mục tiêu**

Tách toàn bộ quyết định visibility, claim và action thành policy thuần, dễ unit test.

**Thiết kế**

`UserTaskPolicyService` nhận `UserTaskPrincipal` và `UserTaskSnapshot`, trả một decision:

```text
visible
claimable
readOnly
canAct
```

Quy tắc:

1. Admin nhìn thấy mọi task có formKey.
2. Assignee hiện tại nhìn thấy và action active task của mình.
3. Candidate user/group:
   - Task chưa gán: nhìn thấy và claim.
   - Task đã gán người khác: nhìn thấy read-only.
4. User không liên quan nhận `403 TASK_ACCESS_DENIED`; API không trả content.
5. Historic task:
   - Assignee hoặc actor của structured action comment xem read-only.
   - Admin xem read-only.
6. Admin có thể action task active mà không đổi assignee; history ghi actor thực tế.
7. Policy không query Flowable và không dựng DTO.

**Đầu ra**

- Policy table có một implementation duy nhất.
- `allowedActions` luôn dựa trên policy trước khi dựa trên formKey.

**Gate**

- Parameterized unit test toàn bộ authorization matrix.
- Test candidate user, candidate realm-role, assignee khác và admin override.

**Tiêu chí hoàn thành**

- Controller và projector không tự viết điều kiện quyền.

**Không làm trong phase**

- Không thêm role mapping database.

### Phase 06 - Flowable User Task Storage

**Mục tiêu**

Đóng gói toàn bộ truy cập task/history/comment/identity của Flowable.

**Thiết kế**

`UserTaskStorage` cung cấp các operation có kiểu rõ ràng:

```text
findActivePage(query, principal)
findHistoricPage(query, principal)
findActiveById(taskId)
findHistoricById(taskId)
findIdentityLinks(taskId)
getActiveVariables(taskId, variableNames)
getHistoricVariables(processInstanceId, variableNames)
findStructuredComments(taskId)
claim(taskId, username)
addStructuredComment(taskId, processInstanceId, type, message)
complete(taskId, variables)
```

Quy tắc:

1. Query inbox dùng API query chuẩn của Flowable.
2. `MY` query theo assignee.
3. `CLAIMABLE` query task unassigned và candidate user/group.
4. `ALL` không thêm ownership filter, chỉ policy admin được gọi.
5. Storage trả domain snapshot, không trả Flowable `Task` ra service/controller.
6. Variable retrieval nhận whitelist tên biến; không có method user-facing `getAllVariables`.
7. Active và historic lookup là hai path riêng.
8. Storage không quyết định quyền và không map action.

**Đầu ra**

- Service không inject `ProcessEngine`, `TaskService` hoặc `HistoryService`.
- Query logic tập trung ở một storage.

**Gate**

- Mockito unit test các query option.
- In-memory Flowable integration test active/historic lookup.
- Test variable whitelist không gọi `getVariables(taskId)` dạng lấy tất cả.

**Tiêu chí hoàn thành**

- API user-facing không tái sử dụng `WorkflowRunService.getTaskVariables`.

**Không làm trong phase**

- Không thay storage của API admin cũ.

### Phase 07 - User Task List and Detail API

**Mục tiêu**

Cung cấp read path user-facing ổn định cho inbox và deep link.

**Thiết kế**

1. Tạo `UserTaskController` tại `/v1/user-tasks`.
2. `GET /v1/user-tasks`:
   - Validate query.
   - Tạo principal.
   - Chọn active hoặc historic storage query.
   - Áp policy.
   - Trả `BasePageResponse<UserTaskSummaryResponse>`.
3. `GET /v1/user-tasks/{taskId}`:
   - Tìm active trước, historic sau.
   - Task thiếu formKey được coi là không thuộc API mới.
   - Áp policy trước khi đọc content.
   - Trả metadata, permission flags và `content` nullable.
4. Search `keyword` được giới hạn vào task name, process name và business key; không search raw variables.
5. `businessKey` hỗ trợ deep link từ KOC campaign.
6. Sort whitelist:
   - `createdAt`
   - `dueAt`
   - `priority`
7. Giới hạn `size` theo chuẩn backend hiện có, tối đa 100.

**Đầu ra**

- Inbox API không yêu cầu quyền admin.
- Admin API giữ nguyên.
- Detail completed task trả `readOnly=true`.

**Gate**

- Controller contract tests cho MY, CLAIMABLE, ALL.
- Test ALL non-admin trả 403.
- Test active, completed, blank formKey, unknown formKey và access denied.
- Test list response không có `content` hoặc variables.

**Tiêu chí hoàn thành**

- User có thể đọc danh sách và metadata task mà không gọi `/v1/admin/workflows`.

**Không làm trong phase**

- Content projector hoàn chỉnh nằm ở phase 08.

### Phase 08 - FormKey Projectors and Data Redaction

**Mục tiêu**

Trả đúng content cần thiết cho từng màn hình mà không lộ process variables.

**Thiết kế**

Mỗi projector implement contract:

```text
formKey()
requiredVariableNames()
project(taskSnapshot, variables)
```

#### `KOC_CANDIDATE_APPROVAL`

Content:

- `campaignId`, `campaignName`, `niche`.
- `targetCount`, `minScore`.
- Candidate:
  - `externalProfileId`
  - `fullName`
  - `profileUrl`
  - `platform`
  - `followerCount`
  - `engagementRate`
  - `score`
  - `strengths`
  - `risks`
  - `reviewNote`

Không trả prompts, thread ID, raw AI output, account context hoặc credential.

#### `KOC_DISCOVERY_DECISION`

Content:

- `campaignId`, `campaignName`, `niche`.
- `currentRound`, `roundLimit`.
- `qualifiedCount`, `targetCount`.
- `candidatePreview`, tối đa 10 candidate theo DTO an toàn.

#### `MANUAL_2FA_CONFIRMATION`

Content:

- `platform`
- `actionRequired`
- `verificationNumber`
- `message`

Không trả password, OTP secret, backup code, cookie, access token hoặc raw request context. Không tạo code fallback khi `verificationNumber` rỗng.

#### `APPROVAL`

Đọc một biến typed `approvalContext`:

```text
title
summary
reference
requester
submittedAt
fields[]
```

`fields` chỉ cho scalar string/number/boolean, tối đa 20 mục. Nested object bị từ chối để tránh biến generic thành JSON viewer.

Backend dùng hai type cố định `GenericApprovalContext` và `GenericApprovalField`; không nhận `Map<String, Object>` không giới hạn. KOC projectors có thể đọc campaign summary qua `KocCampaignStorage` bằng business key, nhưng vẫn chỉ trả các field đã liệt kê. Projector map whitelist tường minh vì đây là security boundary; `mapperUtil` tiếp tục dùng cho mapping DTO thông thường trong `UserTaskService`.

**Đầu ra**

- `UserTaskDefinitionRegistry` tĩnh có bốn definition.
- Unknown formKey trả unsupported detail.
- Projector explicit whitelist, không serialize toàn bộ `FlowData`.

**Gate**

- Unit test từng projector.
- Secret redaction tests với process variable chứa password/token/OTP secret.
- Historic projector test.
- Generic approval test từ chối nested object và quá 20 fields.

**Tiêu chí hoàn thành**

- Không có endpoint user-facing trả `Map<String, Object>` chứa toàn bộ process variables.

**Không làm trong phase**

- Không xây schema engine.

### Phase 09 - User Task History API

**Mục tiêu**

Hiển thị lịch sử claim và action cho active lẫn completed task.

**Thiết kế**

1. Structured comment types:
   - `USER_TASK_CLAIM`
   - `USER_TASK_ACTION`
2. Message được serialize JSON bằng Jackson, nhưng response map sang typed DTO.
3. `GET /v1/user-tasks/{taskId}/history`:
   - Xác thực principal.
   - Lookup active/historic task.
   - Áp policy.
   - Đọc structured comments.
   - Sort tăng dần theo thời gian.
4. Raw system comments không thuộc hai type trên không hiển thị.
5. Malformed structured comment:
   - Log warning với comment ID.
   - Không fail toàn bộ history.
   - Không trả raw JSON ra client.
6. Comment text được coi là plain text; FE không render HTML.

**Đầu ra**

- Typed `UserTaskHistoryResponse`.
- History hoạt động sau khi active task đã bị complete.

**Gate**

- Test empty history.
- Test claim + action ordering.
- Test malformed comment.
- Test unauthorized historic task.

**Tiêu chí hoàn thành**

- Completed deep link hiển thị được action cuối cùng và actor.

**Không làm trong phase**

- Không cho thêm comment độc lập.

### Phase 10 - Claim and Allowed Actions

**Mục tiêu**

Chuẩn hóa claim, auto-claim contract và action availability.

**Thiết kế**

1. `POST /v1/user-tasks/{taskId}/claim` không nhận body assignee.
2. Claim pipeline:
   - Tạo principal từ JWT.
   - Tìm active task.
   - Áp policy.
   - Nếu đã assignee chính user: trả success idempotent.
   - Nếu đã gán người khác: `409 TASK_ALREADY_CLAIMED`.
   - Nếu unassigned candidate/admin: claim về principal username.
   - Ghi `USER_TASK_CLAIM` comment.
3. `allowedActions` được lấy từ `UserTaskDefinitionRegistry`, sau đó lọc bởi policy:
   - Assignee: action của formKey.
   - Admin: action của formKey.
   - Unassigned candidate: rỗng cho tới khi claim thành công.
   - Assigned-other candidate: rỗng.
   - Completed/unsupported: rỗng.
4. Claim race:
   - Một request thắng.
   - Request thua trả `409 TASK_ALREADY_CLAIMED`.
   - FE reload detail và chuyển read-only nếu assignee là người khác.

**Đầu ra**

- Claim response trả task summary mới sau claim.
- Detail response luôn có permission flags nhất quán.

**Gate**

- Unit test claim same user, candidate, non-candidate, admin và assigned-other.
- Flowable integration test hai claim đồng thời.
- Test allowedActions cho mọi formKey và state.

**Tiêu chí hoàn thành**

- FE không tự suy diễn action từ role, assignee hoặc formKey.

**Không làm trong phase**

- Không có unclaim, delegate hoặc reassign user-facing.

### Phase 11 - Action Validation and Execution

**Mục tiêu**

Thực thi action theo formKey bằng payload tối thiểu, validate tại trust boundary.

**Thiết kế**

`POST /v1/user-tasks/{taskId}/actions` thực hiện:

1. Validate request ID, action, variables và comment.
2. Tìm active task và áp policy.
3. Kiểm tra action thuộc `allowedActions`.
4. Chọn action mapper theo formKey.
5. Action mapper đọc whitelist server-side variables.
6. Action mapper validate và tạo process variables.
7. Ghi structured action comment.
8. Complete task.

Mapper cụ thể:

#### KOC candidate approval

- `APPROVE` yêu cầu `approvedCandidateIds` không rỗng, không trùng và là subset của candidate server-side.
- Backend lấy object candidate thật từ `FlowData`, không nhận object candidate từ FE.
- Ghi `approved=true`, `selectedCandidates=<server-side candidates>`.
- `REJECT` ghi `approved=false`, `selectedCandidates=[]`.

#### KOC discovery decision

- Chỉ nhận `FIND_MORE` hoặc `STOP`.
- Ghi root variable `discoveryDecision`.
- Đồng bộ `flowData.variableData.discoveryDecision`.
- Không catch rồi bỏ qua lỗi đồng bộ.

#### Manual 2FA

- Chỉ nhận `CONFIRM`.
- Không nhận verification code hoặc secret từ FE.
- Ghi `manualApproved=true`.

#### Generic approval

- Ghi `taskOutcome=APPROVE|REJECT|RETURN`.
- `RETURN` chỉ hoàn thành task; BPMN chịu trách nhiệm quay về bước sửa.

**Đầu ra**

- Action mapper nằm trong cùng `UserTaskDefinitionRegistry` với projector và action set.
- Không còn action user-facing gửi arbitrary process variables.

**Gate**

- Unit test từng mapper.
- Test candidate ID giả, trùng, rỗng và object injection.
- Test comment rule và giới hạn 2.000 ký tự.
- Engine test xác minh variables sau complete.

**Tiêu chí hoàn thành**

- Action request không thể ghi biến ngoài contract của formKey.

**Không làm trong phase**

- Idempotency/concurrency hoàn chỉnh nằm ở phase 12.

### Phase 12 - Idempotency and Concurrency

**Mục tiêu**

Chống double-submit, retry network và claim/action race.

**Thiết kế**

1. `UserTaskService.executeAction` chạy trong
   `@Transactional("flowableTransactionManager")`.
2. Trước active lookup, kiểm tra structured action comment theo `taskId + requestId`.
3. Nếu có kết quả cũ:
   - Kiểm tra actor.
   - Kiểm tra user vẫn có quyền xem historic task.
   - Trả response cũ.
4. Nếu task đã completed mà request ID chưa tồn tại: trả `TASK_ALREADY_COMPLETED`.
5. Nếu task active:
   - Validate.
   - Ghi comment chứa action response dự kiến.
   - Complete trong cùng transaction.
6. Optimistic lock hoặc task disappearance:
   - Kết thúc transaction hiện tại.
   - Query lại structured comments.
   - Cùng request ID thì trả response cũ.
   - Không có thì trả `TASK_ACTION_CONFLICT`.
7. FE giữ nguyên request ID khi user bấm retry cho cùng một submission.
8. FE tạo request ID mới khi user thay action hoặc payload.
9. Downstream delegate MongoDB giữ idempotency riêng bằng natural key/unique index.

**Đầu ra**

- Retry không tạo completion thứ hai.
- ActionBar có trạng thái submitting và không gửi song song trong một tab.
- Backend vẫn đúng khi có nhiều tab hoặc nhiều client.

**Gate**

- Integration test cùng request ID tuần tự.
- Integration test cùng request ID đồng thời.
- Integration test hai request ID khác nhau đồng thời.
- Test optimistic lock translation.
- Test comment rollback khi complete thất bại.
- Test KOC candidate duplicate side effect được unique index chặn.

**Tiêu chí hoàn thành**

- Một active task chỉ có một completion thắng.
- Retry hợp lệ trả cùng action response.

**Không làm trong phase**

- Không thêm distributed lock, Redis hoặc audit DB.

### Phase 13 - BPMN FormKey, Assignment and Outcome Contract

**Mục tiêu**

Deploy process version mới tương thích framework mà không ảnh hưởng instance cũ.

**Thiết kế**

#### KOC Candidate Discovery

```text
userTaskDiscoveryDecision
  formKey = KOC_DISCOVERY_DECISION
  assignee = ${flowData.commonData.approverAssignee}

userTaskApproveCandidates
  formKey = KOC_CANDIDATE_APPROVAL
  assignee = ${flowData.commonData.approverAssignee}
```

- Gateway discovery dùng một nguồn chuẩn:
  `flowData.variableData.discoveryDecision`.
- `FIND_MORE` và `STOP` đều có condition rõ ràng.
- Default flow đi nhánh invalid outcome, cập nhật workflow lỗi và kết thúc fail; không mặc định `STOP`.
- Approval gateway có condition explicit cho `approved == true` và `approved == false`.
- Default flow đi nhánh invalid outcome; không mặc định reject.

#### Facebook Login HITL

```text
userTaskManualApprove
  formKey = MANUAL_2FA_CONFIRMATION
  assignee = ${flowData.commonData.approverAssignee}
```

- Parent process phải truyền `flowData` có `approverAssignee`.
- Sau User Task có gateway kiểm tra `manualApproved == true`.
- Missing/false đi nhánh failed, không tự coi là success.

#### Generic approval fixture

- Tạo BPMN test fixture formKey `APPROVAL`.
- Dùng `taskOutcome` cho ba nhánh APPROVE, REJECT, RETURN.
- RETURN quay về một User Task sửa dữ liệu trong fixture để chứng minh routing do BPMN sở hữu.

#### Deployment

- Publish qua lifecycle phase 02.
- Process instance cũ tiếp tục dùng API và admin UI cũ.
- Không thêm fallback taskDefinitionKey.

**Đầu ra**

- Ba production User Task có formKey chuẩn.
- Một generic approval fixture chứng minh contract.

**Gate**

- BPMN XML parse/validation.
- In-memory Flowable tests cho mọi gateway outcome.
- Version coexistence test.
- Test missing/invalid outcome đi fail path.

**Tiêu chí hoàn thành**

- Task từ process version mới được resolver bằng formKey duy nhất.
- Không có hard-coded assignee `admin` trong ba User Task mục tiêu.

**Không làm trong phase**

- Không migrate active instance cũ.

### Phase 14 - Frontend User Task Foundation

**Mục tiêu**

Tạo feature module, typed contracts, API client, registry và i18n.

**Thiết kế**

1. Tạo `UserTaskModule` theo NgModule pattern hiện có.
2. Đăng ký `userTaskRoutes` trước wildcard:
   - `tasks`
   - `tasks/:taskId`
3. `UserTaskApiService` dùng:
   `environment.apiUrl.aiGenerator + '/user-tasks'`.
4. DTO mapper tạo discriminated union theo formKey; không dùng `any`.
5. Registry entry gồm:
   - `formKey`
   - `component`
   - `screenTitleKey`
6. Unknown formKey map đúng `UnsupportedTaskScreen`; blank formKey không có fallback.
7. Tạo `user-task.i18n.json` đủ `vi` và `en`, đăng ký trong `I18nService`.
8. Bổ sung menu User Tasks trỏ `/tasks`.
9. Không import trực tiếp PrimeNG; dùng `SharedModule`.

**Đầu ra**

- Feature compile độc lập.
- API contract typed cho list, detail, history, claim và action.
- Registry có bốn formKey và unsupported state.

**Gate**

- API service unit tests xác minh URL/body/query.
- DTO mapper tests.
- Registry tests exact-match và unknown.
- Route/menu/i18n tests.
- `npm run test`
- `npm run build`
- Playwright route smoke test.

**Tiêu chí hoàn thành**

- `/tasks` và `/tasks/:taskId` resolve được component framework.
- Không có business fallback trong FE.

**Không làm trong phase**

- Inbox và TaskHost UI hoàn chỉnh nằm ở phase 15-16.

### Phase 15 - Task Inbox

**Mục tiêu**

Xây dựng inbox cá nhân tại `/tasks`.

**Thiết kế**

1. Dùng `app-page-shell`, `app-action-toolbar`, `app-filter-panel`, `app-table`.
2. Segmented view:
   - Của tôi (`MY`)
   - Có thể nhận (`CLAIMABLE`)
   - Tất cả (`ALL`) chỉ hiện với admin
3. Filter:
   - Keyword
   - Form key
   - Status
   - Due date range
4. Hỗ trợ `businessKey` trong URL để mở danh sách task của một campaign/process.
5. State filter, page và size được đồng bộ vào query parameters.
6. Row click và action Mở task đi `/tasks/:taskId`.
7. Table columns:
   - Task
   - Workflow/business key
   - Form key
   - Assignee
   - Created/due
   - Status
   - Action
8. Error state hiển thị `errorCode` và `errorMessage` thật; không render mock data.
9. Mobile:
   - Cột phụ được ẩn theo TableConfig.
   - Text có `min-w-0`, truncate và copy control khi cần.
   - Filter xếp một cột.

**Đầu ra**

- Inbox dùng user-facing API.
- Admin task list cũ vẫn tồn tại ở route admin.

**Gate**

- Unit test query state, pagination, filter và admin tab.
- Component integration test loading, empty, error và data.
- Playwright Chromium/WebKit:
  - Mở inbox.
  - Đổi view/filter.
  - Phân trang.
  - Deep link bằng business key.
  - Mobile viewport.
  - Keyboard row/action navigation.

**Tiêu chí hoàn thành**

- User thường không gọi API admin để xem task.

**Không làm trong phase**

- Không claim hoặc action trực tiếp từ inbox.

### Phase 16 - Task Host, Store and Shared Shell

**Mục tiêu**

Xây dựng vòng đời task detail dùng chung tại `/tasks/:taskId`.

**Thiết kế**

`TaskHostStore` state machine:

```text
LOADING
  -> AUTO_CLAIMING
  -> READY | READ_ONLY | UNSUPPORTED | FORBIDDEN
  -> CONFIRMING
  -> SUBMITTING
  -> COMPLETED
```

Store quản lý:

- Task detail.
- History.
- Auto-claim.
- Screen registration.
- Validation và payload builder.
- Confirmation.
- Request ID.
- Action submission.
- Backend error.
- Navigation sau thành công.

Screen con đăng ký một adapter scoped:

```text
validate(action)
buildVariables(action)
```

Quy tắc:

1. Host load detail và history song song sau khi có quyền.
2. `claimable=true` kích hoạt auto-claim một lần.
3. Claim success reload detail.
4. Claim conflict reload detail và chuyển read-only nếu task thuộc người khác.
5. Dynamic screen được chọn bằng exact `formKey`.
6. `TaskShell` chứa:
   - Header
   - Task info
   - Screen content
   - History
   - Action bar
7. Action bar render chính xác `allowedActions`.
8. Submit failure giữ nguyên screen form/selection và request ID.
9. Submit success hiển thị toast, chuyển `/tasks`, refresh inbox khi quay lại.
10. Completed task render read-only.
11. Unsupported task render metadata và hướng dẫn liên hệ quản trị, không có action.
12. Mobile một cột; desktop main/sidebar; action bar sticky nhưng không che content.
13. Focus quay về control hợp lý sau dialog/error; live region thông báo state.

**Đầu ra**

- Shared shell không chứa logic riêng của KOC.
- Screen không tự gọi API claim/action.

**Gate**

- Store unit tests toàn bộ state transitions.
- Component integration:
  - Load -> auto-claim -> ready.
  - Read-only.
  - Unsupported.
  - Historic.
  - Confirm -> action -> completed.
  - Error giữ state.
- Playwright Chromium/WebKit cho desktop/mobile/keyboard.

**Tiêu chí hoàn thành**

- Một mock screen có thể đăng ký adapter và hoàn tất action qua shell.

**Không làm trong phase**

- Nội dung bốn screen thật nằm ở phase 17.

### Phase 17 - Specific Task Screens

Phase này có bốn checkpoint độc lập. Mỗi checkpoint phải pass gate riêng trước checkpoint kế tiếp.

#### Phase 17A - KOC Candidate Approval

**Thiết kế**

- Render campaign context và candidate table bằng `app-table`.
- Candidate mặc định được chọn khi `score >= minScore`.
- User có select all, deselect all và toggle từng candidate.
- `APPROVE` yêu cầu ít nhất một candidate.
- Adapter chỉ trả `approvedCandidateIds`.
- `REJECT` không gửi candidate object.
- External profile link có accessible name và `rel="noopener noreferrer"`.
- Không probe nhiều variable name như màn cũ.

**Gate**

- Unit test selection và payload.
- Component test approve/reject/comment.
- Playwright approve candidate list trên desktop/mobile.

**Tiêu chí hoàn thành**

- Feature parity với phần candidate approval của màn `/koc/approval` cũ.

#### Phase 17B - KOC Discovery Decision

**Thiết kế**

- Hiển thị current round, round limit, qualified count và target count.
- Candidate preview read-only, tối đa 10.
- Action:
  - `FIND_MORE`
  - `STOP`
- Adapter không gửi process variables; action name là quyết định.
- Không suy diễn loại task từ name hoặc taskDefinitionKey.

**Gate**

- Unit test progress display và hai action.
- Playwright FIND_MORE và STOP.

**Tiêu chí hoàn thành**

- Feature parity với decision section của màn cũ.

#### Phase 17C - Manual 2FA Confirmation

**Thiết kế**

- Hiển thị `actionRequired`, `verificationNumber`, `message`.
- Dùng `app-copyable-text` cho verification number khi có giá trị.
- Khi verification number rỗng, hiển thị state thiếu dữ liệu; không tạo số mặc định.
- Chỉ có action `CONFIRM`.
- Không có input password, OTP hoặc secret.

**Gate**

- Unit test có/không có verification number.
- Secret redaction component test.
- Playwright confirm 2FA và no-fallback state.

**Tiêu chí hoàn thành**

- Xóa hành vi fallback code khỏi luồng mới.

#### Phase 17D - Generic Approval

**Thiết kế**

- Render title, summary, reference, requester, submittedAt và scalar fields.
- Dùng `app-key-value-list`; không dùng JSON viewer.
- Action `APPROVE`, `REJECT`, `RETURN`.
- Comment field dùng chung từ TaskActionBar.
- REJECT/RETURN không submit khi comment rỗng.

**Gate**

- Unit test render scalar fields.
- Component test ba action và comment rule.
- Playwright approve, reject và return.

**Tiêu chí hoàn thành**

- BPMN fixture `APPROVAL` xử lý đủ ba outcome qua framework.

**Không làm trong phase**

- Không tạo dynamic form field editor.

### Phase 18 - Legacy Cutover, End-to-End QA and Release Gate

**Mục tiêu**

Chuyển traffic user-facing sang framework mới, giữ admin legacy và chứng minh luồng thật end-to-end.

**Thiết kế cutover**

1. Route `/koc/approval` redirect tới `/tasks`.
2. Query cũ:
   - `campaignId` map sang `businessKey`.
   - `taskId` redirect trực tiếp `/tasks/:taskId`.
3. Xóa menu KOC Candidate Approval cũ; menu User Tasks là entry user-facing duy nhất.
4. Giữ `/ai-agent-mcrs/workflows/tasks` cho admin.
5. Giữ `/v1/admin/workflows/tasks/**` cho process instance cũ và vận hành.
6. Sau khi parity pass:
   - Xóa component KOC approval cũ.
   - Xóa task methods cũ khỏi `KocCampaignService`.
   - Xóa model/config/test chỉ phục vụ màn cũ.
   - Thay E2E cũ bằng user-task E2E.
7. Không xóa API admin hoặc dữ liệu Flowable cũ.

**Thiết kế QA**

Test layers:

1. Core-lib unit tests.
2. Backend unit tests:
   - Principal
   - Policy
   - Storage
   - Projector
   - Action mapper
   - Service
3. Backend Flowable integration:
   - Claim race
   - Action race
   - Idempotency
   - Comment transaction
   - Active/historic detail
   - BPMN outcomes
4. Frontend unit/component integration:
   - API
   - Registry
   - Store
   - Inbox
   - Shell
   - Bốn screens
5. Playwright mock API suite trên Chromium và WebKit.
6. Local live FE-BE-Flowable suite:
   - Authentication dùng `E2E_KEYCLOAK_USERNAME` và `E2E_KEYCLOAK_PASSWORD`; không hard-code credential.
   - Base URLs dùng `E2E_APP_BASE_URL` và `E2E_API_BASE_URL`.
   - Suite chỉ chạy khi `RUN_LIVE_USER_TASK_E2E=true`; release pipeline bắt buộc bật cờ này.
   - Admin deploy/publish/start một BPMN fixture không gọi AI hoặc MongoDB.
   - Fixture tạo User Task `APPROVAL` với `approvalContext`, sau đó kết thúc theo `taskOutcome`.
   - Inbox thấy task.
   - Auto-claim.
   - Action.
   - History.
   - Completed deep link read-only.
   - Suite không dùng `page.route()` cho `/v1/user-tasks`.
   - Bốn projector và bốn action mapper được kiểm tra với Flowable in-memory ở backend integration tests; mock Playwright kiểm tra UI của cả bốn screen.
7. Accessibility:
   - Keyboard-only.
   - Focus visible.
   - Dialog focus trap/return.
   - Live region.
   - Color contrast WCAG AA.
   - Không overlap desktop/mobile.

**Release commands**

Core library:

```text
.\mvnw.cmd test
.\mvnw.cmd compile
```

Backend:

```text
.\mvnw.cmd test
.\mvnw.cmd compile
```

Frontend:

```text
npm run test
npm run build
npx playwright test e2e/user-task.spec.ts --project=chromium
npx playwright test e2e/user-task.spec.ts --project=webkit
```

**Tiêu chí hoàn thành**

- Tất cả gate pass.
- Không còn credential hard-code trong test mới.
- Không còn user-facing call tới `/v1/admin/workflows/tasks`.
- Ba KOC tasks và generic approval chạy qua `/tasks/:taskId`.
- Process cũ vẫn xử lý được ở admin UI.
- Không có fallback từ formKey, mock-on-error hoặc fake success.

**Không làm trong phase**

- Không xóa legacy admin capability.

## 10. Ownership khi triển khai

| Phase | Dedicated subagent chính | Reviewer cần thiết |
|---|---|---|
| 01 | `test-qa-agent` | `dev-be-agent` |
| 02-12 | `dev-be-agent` | `architect-agent`, `test-qa-agent` |
| 13 | `bpmn-agent` | `dev-be-agent`, `test-qa-agent` |
| 14-17 | `dev-fe-agent` | `test-qa-agent` |
| 18 | `test-qa-agent` | `dev-be-agent`, `dev-fe-agent`, `bpmn-agent` |

Subagent phải đọc `docs/note/be-note.md` hoặc `docs/note/fe-note.md` tương ứng trước khi thay đổi code.

## 11. Commit và repository boundaries

Repo dùng git submodules. Khi triển khai:

1. Commit thay đổi core-lib trong `libs/develop-tool-core-lib`.
2. Cập nhật dependency/version core-lib ở backend khi cần.
3. Commit backend trong `services/ai-agent-mcrs`.
4. Commit frontend trong `web/dev-tool-web`.
5. Commit submodule pointers và tài liệu tại root `D:\Code`.

Không gom thay đổi của nhiều submodule vào một commit nội bộ không thể review độc lập.

## 12. Definition of Done tổng

Framework được coi là hoàn thành khi:

1. `/tasks` là inbox user-facing chính thức.
2. `/tasks/:taskId` render theo exact `formKey`.
3. Backend kiểm soát visibility, claim, allowed actions và payload mapping.
4. Bốn formKey mục tiêu hoạt động đầy đủ.
5. Active, completed, unsupported và conflict states có UI rõ ràng.
6. Action retry an toàn trong giới hạn Flowable history retention.
7. BPMN version mới không phá process instance cũ.
8. Unit, integration, Playwright Chromium/WebKit và local live flow đều pass.
9. Legacy admin task management vẫn hoạt động.
10. Không có dynamic schema engine, audit DB hoặc fallback ngoài phạm vi.
