# Design Specification: Workflow Run Management & Debugger UI

## 1. Overview
H? th?ng màn hình qu?n tr? và g? l?i (debug) quá trình th?c thi Workflow trong dev-tool-web (Angular).
Cung c?p 3 tính nang c?t lõi:
1. **Qu?n lý danh sách Run:** Xem l?ch s? ch?y các workflow, l?c theo Workflow Definition & Tr?ng thái (Status).
2. **Kích ho?t ch?y Workflow (Run Workflow):** Modal nh?p payload d?u vào JSON và trigger ch?y workflow.
3. **Tr?c quan hóa & Debug quá trình ch?y (Live Debugger):**
   - BPMN Canvas hi?n th? tr?c quan tr?ng thái t?ng node (Start/End/AI Gate/Code Gate...).
   - **Tô màu xanh các du?ng dây k?t n?i (Sequence Flow)** mà workflow dã di qua.
   - Node Inspector hi?n th? chi ti?t Input Snapshot, Output Payload, Evidence, Logs và Reason/Error.
   - Co ch? Polling t? d?ng khi workflow dang ? tr?ng thái RUNNING.

---

## 2. Architecture & Routing

### 2.1 Route Mapping (Tích h?p vào workflowStudioRoutes)
- **List Page:** /ai-agent-mcrs/workflows/runs -> WorkflowRunListPageComponent
- **Detail / Debug Page:** /ai-agent-mcrs/workflows/runs/:runId -> WorkflowRunDetailPageComponent

### 2.2 Component Hierarchy & Shared UI Compliance
Tuân th? 100% tài li?u quy chu?n docs/note/fe-note.md:
- S? d?ng pp-page-shell, pp-section-panel, pp-action-toolbar, pp-filter-panel.
- B?ng d? li?u: pp-table v?i TableConfig<WorkflowRun>.
- Drawer & Inspector: pp-drawer, pp-json-viewer, pp-badge, pp-copyable-text, pp-key-value-list.
- Dialog Trigger: pp-dialog, pp-button.
- BPMN Engine: Tái s? d?ng WorkflowBpmnCanvasComponent ? ch? d? mode="runtime".

---

## 3. Detailed Feature Specifications

### 3.1 Workflow Run List (WorkflowRunListPageComponent)
- **Filters:**
  - workflowId: Dropdown ch?n Workflow (l?y t? WorkflowApiService.getWorkflowPage()).
  - status: Dropdown l?c theo WorkflowRunStatus (RUNNING, COMPLETED, ERROR, TIMED_OUT, CANCELLED, PENDING).
- **Toolbar Actions:**
  - Ch?y workflow: M? modal WorkflowRunTriggerDialogComponent.
  - Làm m?i: Refresh danh sách.
- **Table Columns (TableConfig<WorkflowRun>):**
  - ID: Truncate + pp-copyable-text.
  - Workflow: Tên ho?c ID workflow definition.
  - Tr?ng thái: Badge màu (Success: COMPLETED, Warning: RUNNING, Danger: ERROR/CANCELLED/TIMED_OUT).
  - K?t qu? (Outcome): PASS / FAIL / BLOCKED.
  - B?t d?u lúc & K?t thúc lúc: Ð?nh d?ng ngày gi? chu?n.
  - Thao tác: Button action "Xem Debug" -> Ði?u hu?ng sang trang Debug theo unId.

### 3.2 Trigger Workflow Dialog (WorkflowRunTriggerDialogComponent)
- Ch?n Workflow Definition c?n ch?y (n?u chua ch?n t? tru?c).
- JSON Input Editor v?i validate cú pháp JSON tru?c khi submit.
- Khi submit thành công:
  - G?i WorkflowApiService.startWorkflow(workflowId, input).
  - Hi?n th? Toast thông báo thành công.
  - T? d?ng di?u hu?ng sang /ai-agent-mcrs/workflows/runs/:runId.

### 3.3 Workflow Run Debugger (WorkflowRunDetailPageComponent)
- **Header Summary Panel:**
  - Run ID, Status Badge, Outcome, Start/End Time, Execution Duration.
  - Action buttons: Quay l?i, Làm m?i, Retry Run (khi Run b? l?i), Toggle Auto-polling (2s interval khi status là RUNNING).
- **Visual BPMN Canvas Overlay (WorkflowBpmnCanvasComponent):**
  - T?i BPMN XML tuong ?ng c?a version th?c thi.
  - Render marker highlight màu node theo WorkflowNodeExecutionStatus:
    - COMPLETED -> Xanh lá (workflow-bpmn-canvas__marker--completed).
    - RUNNING -> Xanh duong / Vàng (workflow-bpmn-canvas__marker--running).
    - ERROR / TIMED_OUT -> Ð? (workflow-bpmn-canvas__marker--failed).
  - **Edge Traversal Path Highlight:**
    - Tính toán du?ng di gi?a các node liên ti?p trong un.nodes.
    - Tô xanh nét v? (stroke: #16a34a) và d?u mui tên cho các pmn:SequenceFlow dã di qua.
  - Khi click vào 1 node trên canvas -> T? d?ng focus node tuong ?ng trong Node Inspector.
- **Step Timeline & Node Inspector:**
  - Danh sách th? t? các bu?c th?c thi (Timeline steps).
  - Chi ti?t node du?c ch?n:
    - Metadata: Node ID, Node Type, Status, Attempt, Reason, Error Code, Error Message.
    - JSON Viewer: **Input Snapshot** (Ð?u vào c?a node).
    - JSON Viewer: **Output Payload** (Ð?u ra c?a node).
    - JSON Viewer: **Evidence** (D? li?u b?ng ch?ng/AI logs).

---

## 4. Internationalization (i18n)
- Khai báo file i18n t?i src/app/core/i18n/features/workflow-studio.i18n.json (ho?c m? r?ng file tuong ?ng) v?i d?y d? 2 ngôn ng? i và en.
- Dùng pipe | translateContent và dang ký trong I18nService.

---

## 5. Testing Strategy
1. **Unit Tests (*.spec.ts):**
   - WorkflowRunListPageComponent: test load danh sách, filter, trigger dialog opening.
   - WorkflowRunDetailPageComponent: test load run details, edge traversal computation, node selection, polling interval.
   - WorkflowBpmnCanvasComponent: test marker edge traversal highlight.
   - Ch?y 
pm run test d?t 100% PASS.
2. **Playwright E2E Tests (e2e/workflow-runs.spec.ts):**
   - Ki?m th? m? danh sách run, áp d?ng b? l?c.
   - Ki?m th? trigger run và m? trang debug hi?n th? canvas cùng màu dây xanh n?i các node.
