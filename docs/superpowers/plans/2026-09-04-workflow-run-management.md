# Workflow Run Management & Debugger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Build the Workflow Run Management screen (List + Filters + Trigger modal) and the Workflow Run Live Debugger screen (BPMN Canvas Runtime with dynamic green Sequence Flow traversal paths, Node Execution Inspector with Input/Output/Evidence JSON viewer, and Polling support).

**Architecture:** 
- List view (WorkflowRunListPageComponent) handles search, filter by workflow & status, table rendering with TableConfig<WorkflowRun>, and triggers new runs via WorkflowRunTriggerDialogComponent.
- Debugger view (WorkflowRunDetailPageComponent) coordinates BPMN XML fetching, runtime visual state computation (highlighting executed nodes and traversed sequence flow edges in green), node inspector detail panel, and polling for active runs.
- Canvas enrichment (WorkflowBpmnCanvasComponent / CSS) to support green line highlight & animated active path for traversed sequence flows.

**Tech Stack:** Angular 19, TypeScript, RxJS, bpmn-js, SharedModule (pp-page-shell, pp-table, pp-dialog, pp-drawer, pp-json-viewer), Vitest, Playwright.

---

### Task 1: Sequence Flow Traversal Calculation & Visual Edge Markers

**Files:**
- Modify: web/dev-tool-web/src/app/features/workflow-studio/model/workflow-studio.model.ts
- Modify: web/dev-tool-web/src/app/features/workflow-studio/bpmn/workflow-bpmn-canvas.component.ts
- Modify: web/dev-tool-web/src/app/features/workflow-studio/bpmn/workflow-bpmn-canvas.component.scss
- Test: web/dev-tool-web/src/app/features/workflow-studio/bpmn/workflow-bpmn-canvas.component.spec.ts

- [ ] **Step 1: Write unit test for runtime edge marker styling & sequence flow traversal helper**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement edge traversal helper and CSS styles for green highlight on sequence flows**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit changes**

---

### Task 2: Trigger Workflow Dialog Component

**Files:**
- Create: web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-trigger-dialog.component.ts
- Create: web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-trigger-dialog.component.html
- Create: web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-trigger-dialog.component.css
- Test: web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-trigger-dialog.component.spec.ts

- [ ] **Step 1: Write failing unit test for Trigger Dialog component**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement Trigger Dialog with Workflow selection & JSON payload validation**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit changes**

---

### Task 3: Workflow Run List Page Component

**Files:**
- Create: web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-list-page.component.ts
- Create: web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-list-page.component.html
- Create: web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-list-page.component.css
- Test: web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-list-page.component.spec.ts
- Modify: web/dev-tool-web/src/app/features/workflow-studio/workflow-studio.module.ts
- Modify: web/dev-tool-web/src/app/features/workflow-studio/workflow-studio.routes.ts

- [ ] **Step 1: Write failing unit test for Run List Page**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement Run List Page with filters, pagination, TableConfig and navigation**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit changes**

---

### Task 4: Workflow Run Detail & Live Debugger Page Component

**Files:**
- Create: web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-detail-page.component.ts
- Create: web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-detail-page.component.html
- Create: web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-detail-page.component.css
- Test: web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-detail-page.component.spec.ts
- Modify: web/dev-tool-web/src/app/features/workflow-studio/workflow-studio.module.ts
- Modify: web/dev-tool-web/src/app/features/workflow-studio/workflow-studio.routes.ts

- [ ] **Step 1: Write failing unit test for Debugger Detail Page**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement Debugger Page with BPMN canvas runtime overlay, green traversal edges, Step Inspector and Auto-polling**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit changes**

---

### Task 5: Integration & E2E Validation

**Files:**
- Create: web/dev-tool-web/e2e/workflow-runs.spec.ts
- Verify: Full unit test suite 
pm run test & build 
pm run build

- [ ] **Step 1: Write E2E Playwright test for Workflow Run list & debugger interaction**
- [ ] **Step 2: Run unit test suite & build check**
- [ ] **Step 3: Run Playwright tests**
- [ ] **Step 4: Final verification and commit**
