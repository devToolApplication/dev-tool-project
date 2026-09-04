# Flowable-Native Workflow Run Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Implement Flowable-native Workflow Run APIs (/runs/page, /runs/{runId}, /{workflowId}/start, /runs/{runId}/retry) in i-agent-mcrs Spring Boot backend without creating redundant MongoDB run collections.

**Architecture:** 
- Expose REST endpoints in WorkflowAdminController.
- Delegate business logic to WorkflowRunService (which extends BaseService).
- Query history, activities, and process instance variables via Flowable's HistoryService and trigger new runs via RuntimeService.

**Tech Stack:** Java 21, Spring Boot 3.5.0, Flowable 7.2.0, PostgreSQL, MongoDB (for Definitions/Versions), JUnit 5, Mockito.

---

### Task 1: Create Workflow Run Request and Response DTOs

**Files:**
- Create: services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/api/request/WorkflowStartAdminRequest.java
- Create: services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/api/response/WorkflowRunAdminResponse.java
- Create: services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/api/response/WorkflowNodeExecutionAdminResponse.java

- [ ] **Step 1: Write DTO classes with Jackson & Lombok annotations**
- [ ] **Step 2: Commit DTOs**

---

### Task 2: Implement WorkflowRunService and Flowable Process Mapper

**Files:**
- Create: services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/application/admin/WorkflowRunService.java
- Test: services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/workflowprocess/application/admin/WorkflowRunServiceTest.java

- [ ] **Step 1: Write failing unit test for WorkflowRunServiceTest**
- [ ] **Step 2: Implement WorkflowRunService extending BaseService with HistoryService query, RuntimeService trigger, and node activity mapper**
- [ ] **Step 3: Run mvn test -Dtest=WorkflowRunServiceTest to verify pass**
- [ ] **Step 4: Commit changes**

---

### Task 3: Expose Run Endpoints in WorkflowAdminController

**Files:**
- Modify: services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/workflowprocess/api/admin/WorkflowAdminController.java

- [ ] **Step 1: Add /runs/page, /runs/{runId}, /{workflowId}/start, and /runs/{runId}/retry endpoints**
- [ ] **Step 2: Run mvn clean compile to ensure no compile issues**
- [ ] **Step 3: Commit changes**

---

### Task 4: Full Build & Verification

**Files:**
- Run full tests in services/ai-agent-mcrs
- Verify against sample workflow

- [ ] **Step 1: Run mvn test across i-agent-mcrs**
- [ ] **Step 2: Push changes to GitHub**
