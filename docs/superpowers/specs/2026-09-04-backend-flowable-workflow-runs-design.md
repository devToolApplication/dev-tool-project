# Design Specification: Flowable-Native Workflow Run Management & Execution API

## 1. Overview
H? th?ng backend i-agent-mcrs (Spring Boot 3.5.0, Flowable 7.2.0, PostgreSQL) cung c?p các API qu?n lý và g? l?i lu?t ch?y Workflow tr?c ti?p t? Flowable Engine mà không c?n luu trùng l?p vào MongoDB.

- **MongoDB (Metadata & Design)**: Luu tr? workflow_definitions và workflow_versions (BPMN 2.0 XML).
- **Flowable Engine / PostgreSQL (Runtime & Execution History)**:
  - Qu?n lý quá trình th?c thi: RuntimeService
  - Qu?n lý l?ch s? lu?t ch?y: HistoryService (HistoricProcessInstance, HistoricActivityInstance, HistoricVariableInstance).

---

## 2. API Endpoints & Contracts

### 2.1 API Route Mapping trong WorkflowAdminController
T?t c? các endpoint n?m du?i prefix 1/admin/workflows và du?c b?o v? b?i @PreAuthorize(UserRole.HAS_AI_AGENT_ADMIN):

1. **GET /v1/admin/workflows/runs/page**
   - **Query Params**: page (int, default 0), size (int, default 20), workflowId (optional), status (optional: RUNNING, COMPLETED, ERROR, TIMED_OUT, CANCELLED).
   - **X? lý**: Query t? HistoryService.createHistoricProcessInstanceQuery().
   - **Response**: BaseResponse<BasePageResponse<WorkflowRunAdminResponse>>.

2. **GET /v1/admin/workflows/runs/{runId}**
   - **Path Variable**: unId (Process Instance ID c?a Flowable).
   - **X? lý**:
     - L?y HistoricProcessInstance theo unId.
     - L?y danh sách HistoricActivityInstance c?a unId theo th? t? startTime tang d?n d? ánh x? thành danh sách 
odes.
     - L?y bi?n d?u vào/ra t? HistoricVariableInstance.
   - **Response**: BaseResponse<WorkflowRunAdminResponse> (kèm m?ng 
odes: List<WorkflowNodeExecutionAdminResponse>).

3. **POST /v1/admin/workflows/{workflowId}/start**
   - **Path Variable**: workflowId
   - **Request Body**: WorkflowStartAdminRequest (ch?a input: Map<String, Object>).
   - **X? lý**:
     - Tra c?u WorkflowVersionEntity (uu tiên b?n PUBLISHED ho?c b?n draft m?i nh?t n?u có deploymentId).
     - Ð?m b?o version dã du?c deploy lên Flowable (engineDeploymentId & engineDefinitionKey).
     - G?i untimeService.startProcessInstanceByKey(engineDefinitionKey, businessKey, inputVariables).
   - **Response**: BaseResponse<WorkflowRunAdminResponse>.

4. **POST /v1/admin/workflows/runs/{runId}/retry**
   - **Path Variable**: unId
   - **X? lý**: L?y input variables c?a HistoricProcessInstance cu và trigger m?t process instance m?i.
   - **Response**: BaseResponse<WorkflowRunAdminResponse>.

---

## 3. Data Transfer Objects (DTO)

### 3.1 Response Models
- **WorkflowRunAdminResponse**:
  - id: String (Flowable Process Instance ID)
  - workflowDefinitionId: String (Id c?a definition trong Mongo ho?c business key)
  - workflowVersionId: String (Id c?a version ho?c deployment Id)
  - status: String (RUNNING, COMPLETED, ERROR, TIMED_OUT, CANCELLED, PENDING)
  - input: Map<String, Object> (Input variables)
  - inalOutput: Map<String, Object> (Output variables)
  - inalOutcome: String (PASS, FAIL, BLOCKED)
  - engineInstanceId: String (Flowable Process Instance ID)
  - startedAt: Instant
  - completedAt: Instant
  - 
odes: List<WorkflowNodeExecutionAdminResponse>

- **WorkflowNodeExecutionAdminResponse**:
  - 
odeId: String (Activity ID / Element ID trong BPMN)
  - 
odeType: String (Activity Type: START_EVENT, SERVICE_TASK, EXCLUSIVE_GATEWAY, END_EVENT, ...)
  - executionStatus: String (PENDING, RUNNING, COMPLETED, ERROR, SKIPPED)
  - outcome: String (PASS, FAIL, BLOCKED)
  - ttempt: Integer
  - inputSnapshot: Object
  - output: Object
  - evidence: Object
  - eason: String
  - errorCode: String
  - errorMessage: String (Trích xu?t t? exception message n?u activity b? l?i)

---

## 4. Architecture & Standards Compliance
Tuân th? 100% docs/note/be-note.md:
1. WorkflowRunService k? th?a BaseService và s? d?ng MapperUtil.
2. Không c?n t?o thêm b?ng Mongo cho Runs vì Flowable PostgreSQL dã qu?n lý toàn di?n.
3. X? lý chu?n BusinessException và BusinessErrorCode.
4. Vi?t Unit Tests WorkflowRunServiceTest.java d?t 100% pass v?i Mockito.
