# Workflow Run Detail - Input/Output Modal Popup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (\- [ ]\) syntax for tracking.

**Goal:** Chuyen cac khoi xem JSON Input, Output, Evidence trong man hinh Workflow Run Detail sang dang popup Dialog dung \pp-dialog\ va \pp-json-viewer\.

**Architecture:** Cap nhat template, state signals trong \WorkflowRunDetailPageComponent\, them toolbar action \"runPayload\" de xem payload tong the, them dialog xem payload tung node voi \pp-dialog\ va \pp-json-viewer\, bo sung i18n keys cho tieng Viet va tieng Anh, sua unit test spec de import \@angular/compiler\ va mock can thiet.

**Tech Stack:** Angular 21, Signals, Shared UI Components (\pp-dialog\, \pp-json-viewer\, \pp-action-toolbar\, \pp-button\), Vitest.

---

### Task 1: Bo sung i18n keys

**Files:**
- Modify: \web/dev-tool-web/src/app/core/i18n/features/workflow-studio.i18n.json\

- [ ] **Step 1: Cap nhat translation keys cho vi va en**

Them cac keys:
\workflowStudio.lifecycle.runPayloads\, \workflowStudio.runtime.viewInputSnapshot\, \workflowStudio.runtime.viewOutput\, \workflowStudio.runtime.viewEvidence\, \workflowStudio.lifecycle.initialInput\, \workflowStudio.lifecycle.finalOutput\.

- [ ] **Step 2: Verify file JSON hop le**

Run: \
ode -e \"JSON.parse(require('fs').readFileSync('web/dev-tool-web/src/app/core/i18n/features/workflow-studio.i18n.json', 'utf8'))\"\
Expected: Khong bao loi.

---

### Task 2: Cap nhat Component Logic & Template

**Files:**
- Modify: \web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-detail-page.component.ts\
- Modify: \web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-detail-page.component.html\

- [ ] **Step 1: Cap nhat TypeScript logic**
Them state:
- \payloadDialogVisible = signal(false)\
- \payloadDialogTitle = signal('')\
- \payloadDialogData = signal<unknown>(null)\
- \openPayloadDialog(titleKeyOrText: string, data: unknown): void\
- \openRunPayloadsDialog(): void\
Them action \unPayload\ vao danh sach \ctions\ tren toolbar.

- [ ] **Step 2: Cap nhat HTML template**
- Thay 3 khoi JSON viewer tinh trong Inspector bang cac Action Card/Button gon gang.
- Them \pp-dialog\ popup chua \pp-json-viewer\ de hien thi du lieu khi click.

- [ ] **Step 3: Chay build de kiem tra template binding**

Run: \
px ng build --watch=false\
Expected: Build SUCCESS.

---

### Task 3: Cap nhat va chay Unit Tests

**Files:**
- Modify: \web/dev-tool-web/src/app/features/workflow-studio/pages/workflow-run-detail-page.component.spec.ts\

- [ ] **Step 1: Cap nhat unit test spec**
- Import \@angular/compiler\ o dau file.
- Mock \@bpmn-io/properties-panel\ va \pmn-js-properties-panel\ giong nhu \workflow-builder-page.component.spec.ts\.
- Viet unit test kiem tra viec mo / dong dialog payload node va run.

- [ ] **Step 2: Chay test verify pass 100%**

Run: \
px ng test --include src/app/features/workflow-studio/pages/workflow-run-detail-page.component.spec.ts --watch=false\
Expected: 1 passed test file.
