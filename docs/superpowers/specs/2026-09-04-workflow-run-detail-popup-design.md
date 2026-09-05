# Spec: Workflow Run Detail - Input/Output Modal Popup

## 1. Muc tieu & Boi canh
Man hinh chi tiet luot chay Workflow (workflow-run-detail-page tai route /ai-agent-mcrs/workflows/runs/:runId) hien dang hien thi cac khoi JSON inputSnapshot, output, evidence truc tiep trong panel Inspector ben phai lam panel dai va che khuat khong gian.

Yeu cau: Chuyen toan bo viec xem du lieu Input / Output / Evidence sang dang Popup (Modal Dialog) su dung Shared Component app-dialog va app-json-viewer.

## 2. Thiet ke chi tiet UI/UX

### 2.1. Panel Inspector ben phai (Node Execution Details)
- Thu gon cac khoi JSON co dinh thanh cac Action Button/Card truc quan:
  - Button "Input Snapshot": Kem icon pi pi-sign-in, click de mo popup xem payload dau vao cua node duoc chon.
  - Button "Output Payload": Kem icon pi pi-sign-out, click de mo popup xem ket qua thuc thi cua node.
  - Button "Evidence": Chi hien thi khi node co du lieu evidence.
- Giu lai thong tin tom tat nhanh tren Inspector: Node ID, NodeType, Outcome Badge (PASS/FAIL), Attempt count, Error message box (neu co loi).

### 2.2. Toolbar Action: "Run Payloads"
- Bo sung nut action tren app-action-toolbar:
  - ID: runPayload
  - Icon: pi pi-code
  - Label: workflowStudio.lifecycle.runPayloads (Du lieu Run)
  - Khi click: Mo Modal xem Initial Input (run.input) & Final Output (run.finalOutput).

### 2.3. Cau hinh Dialog Popup (app-dialog)
- Dung Shared UI Component app-dialog:
  - [modal]="true"
  - [width]="'min(90vw, 48rem)'"
  - [dismissableMask]="true"
  - Header: Ten node / Run ID + Loai du lieu.
  - Body: Su dung app-json-viewer (ho tro search, copy, raw mode).
  - Footer: Nut Close.

## 3. Quan ly State & i18n
- State: payloadDialogVisible, payloadDialogTitle, payloadDialogData.
- Bo sung translation keys trong workflow-studio.i18n.json (vi & en).

## 4. Ke hoach kiem thu (Testing)
- Unit Test workflow-run-detail-page.component.spec.ts.
- Chay npm test tren web/dev-tool-web pass 100%.
