# CLAUDE.md - Aerospace PO & Project Management Platform Brief

## Project Overview
You are assisting in building an AI-native, multi-tenant Project Management Platform tailored for small-to-medium aerospace machinery sales and precision tooling distributors.

### The Legacy Problem (Current State)
The client currently manages operations using physical hard-copy folders containing:
- **Folder Tab Labels**: Client Order #, Internal PO #, Vendor Name, Project Name/Items Purchased.
- **Top Internal Paper Ledger**: Contains top-level summary metrics (Total Billed to Client, Amount Billed from Vendor, Company Commission, Freight Charges). Below this summary is an arbitrarily filled hand-written ledger table (Date, Time, Comments) tracking payments/balances that is difficult to decipher.
- **Folder Document Stack**: Client invoice on top (sometimes with paystubs stapled to it), followed by a variable stack of vendor invoices (ranging from single-line software purchases to multi-million dollar capital machinery orders, tooling, accessories, and freight).
- **Manual Sign-off**: Sticky notes indicating whether a folder/PO should be closed, requiring manual review with management.

### The Vision (Target State)
A secure, white-labeled, cloud/on-prem project management platform that automates paper folder digitization via Multimodal Vision AI, structures PO headers and line items, tracks live shipping and accounting updates, and provides a split-screen Human-in-the-Loop (HITL) verification UI. The platform must be commercializable so other SMBs can deploy it as a customized SaaS or containerized application.

---

## Technical Stack & Architecture

- **Frontend Framework**: Next.js 15 (App Router), TypeScript (Strict Mode), Tailwind CSS v4, Shadcn UI primitives.
- **Backend & Database**: PostgreSQL on Supabase, FastAPI (Python background ingestion service).
- **Security & Compliance**: Database-enforced Row-Level Security (RLS), CMMC/DFARS/ITAR compliance readiness, AES-256 encrypted storage, isolated subdomains, optional Docker packaging for classified/defense environments.
- **Document Ingestion & AI Parsing**: Multimodal Vision Parsing (Anthropic Claude 3.5 Sonnet / Vision API) with Pydantic & Instructor for schema-constrained JSON extraction.
- **External Integrations**:
  - **Logistics**: EasyPost API (real-time tracking webhooks for machinery & freight).
  - **Accounting**: QuickBooks Online REST API (OAuth 2.0 with single-flight refresh locks, CDC incremental sync).

---

## Core Operational Workflow & Requirements

### 1. Ingestion & Digitization Pipeline
- **Scan & Event Trigger**: Scanned paper PDFs/images or native digital uploads land in secure object storage (S3/Supabase Storage), triggering an asynchronous event.
- **Multimodal AI Extraction**: Claude 3.5 Sonnet Vision parses non-standard PO tables, stamps, and handwritten ledger notes without rigid templates.
- **Pydantic Schema Enforcement**: Extracted data must conform to a strict schema separating:
  - **PO Header**: PO #, Client Order #, Client Name, Vendor Name, Total Billed to Client, Vendor Billing Total, Commission, Freight, Overall Status.
  - **PO Line Items**: Array of items categorized by type (, , , , ).
- **Human-in-the-Loop (HITL) Verification**: Split-screen UI displaying the raw scanned document on the left and parsed editable fields on the right, highlighting low-confidence extractions before saving to the database.

### 2. Multi-Tenant Database Security (Government & Defense Grade)
- **Database-Level Isolation**: PostgreSQL Row-Level Security (RLS) policies filter every query by . Application code never queries data without passing tenant context.
- **Classified / Defense Security**: Enforce ITAR/DFARS boundary isolation. For defense clients, support containerized Docker deployment on Azure Government Cloud or local on-prem servers.

### 3. Integrations & Operational Hub
- **Shipping Tracking**: Connect EasyPost trackers to hardware/tooling line items; update statuses (, ) automatically via webhooks.
- **Financial Reconciliation**: Synchronize vendor bills and client invoices bi-directionally with QuickBooks Online using OAuth 2.0 and CDC (Change Data Capture).
- **Central Communication**: Attach email threads, internal notes, and supplier correspondence directly to parent PO records.

### 4. Dynamic White-Labeling & Distribution
- **Dynamic Theming**: Tenant branding (logos, primary hex colors, font parameters) injected at runtime via root CSS variables ().
- **Feature Flag System**: Modular  toggles (e.g., enable/disable QuickBooks, EasyPost, or OCR parsing per client).

---

## Claude Code Rules & Engineering Best Practices

### Operational Rules
1. **Explore First**: Search the codebase, inspect database schemas, and map dependencies before modifying files.
2. **Plan Mode ()**: For any complex feature touching >3 files, activate plan mode first. Create a detailed implementation plan and wait for human approval before writing code.
3. **Atomic Execution**: Break tasks down into 5-to-10-minute work blocks. Focus context on explicit file sets.
4. **Verification Gate**: ALWAYS run build checks () and test suites () before declaring a task done. Show command outputs as evidence.
5. **Git Safety**: Work on dedicated feature branches (). NEVER commit directly to  or refactor unprompted code.

---

## Development Milestones
- **Phase 1: Foundation & Security** (Weeks 1-3) - Supabase schema, RLS policies, base Next.js UI framework, .
- **Phase 2: Ingestion Engine** (Weeks 4-6) - Claude Vision pipeline, Pydantic schemas, split-screen HITL verification UI.
- **Phase 3: Integration Network** (Weeks 7-9) - EasyPost tracking webhooks, QuickBooks OAuth & bill synchronization.
- **Phase 4: Commercial Distribution** (Weeks 10-12) - Dynamic CSS variable theming, feature flags, Docker packaging.
