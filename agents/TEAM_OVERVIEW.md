# iOS AI Agent Team — Overview & Coordination

## Team Composition (20 Agents)

| # | Role | Agent File | Reports To |
|---|------|-----------|------------|
| 1 | Product Manager | `product_manager.md` | — (top-level) |
| 2 | Scrum Master / Coordinator | `scrum_master.md` | Product Manager |
| 3 | iOS Team Lead / Tech Lead | `ios_team_lead.md` | Product Manager |
| 4 | Business Analyst | `business_analyst.md` | Product Manager |
| 5 | Solution Architect (iOS) | `solution_architect.md` | iOS Team Lead |
| 6 | UI/UX Designer (iOS) | `ios_ui_designer.md` | iOS Team Lead |
| 7 | Senior iOS Developer | `senior_ios_developer.md` | iOS Team Lead |
| 8 | Mid-Level iOS Developer | `mid_ios_developer.md` | Senior iOS Developer |
| 9 | Junior iOS Developer | `junior_ios_developer.md` | Senior iOS Developer |
| 10 | Backend / API Developer | `backend_api_developer.md` | iOS Team Lead |
| 11 | QA Lead | `qa_lead.md` | iOS Team Lead |
| 12 | QA iOS Engineer | `qa_ios_engineer.md` | QA Lead |
| 13 | Automation Test Engineer | `automation_test_engineer.md` | QA Lead |
| 14 | DevOps / iOS Release Engineer | `ios_devops_engineer.md` | iOS Team Lead |
| 15 | Security Specialist (Mobile) | `security_specialist.md` | Solution Architect |
| 16 | Performance Engineer | `performance_engineer.md` | iOS Team Lead |
| 17 | Documentation Specialist | `documentation_specialist.md` | Scrum Master |
| 18 | Support / Info Engineer | `support_engineer.md` | Product Manager |
| 19 | Data / Analytics Engineer | `data_analytics_engineer.md` | iOS Team Lead |
| 20 | Accessibility Specialist | `accessibility_specialist.md` | UI/UX Designer |

---

## Organizational Hierarchy

```
Product Manager
├── Scrum Master / Coordinator
│   └── Documentation Specialist
├── Business Analyst
├── Support / Info Engineer
└── iOS Team Lead / Tech Lead
    ├── Solution Architect (iOS)
    │   └── Security Specialist (Mobile)
    ├── UI/UX Designer (iOS)
    │   └── Accessibility Specialist
    ├── Senior iOS Developer
    │   ├── Mid-Level iOS Developer
    │   └── Junior iOS Developer
    ├── Backend / API Developer
    ├── QA Lead
    │   ├── QA iOS Engineer
    │   └── Automation Test Engineer
    ├── DevOps / iOS Release Engineer
    ├── Performance Engineer
    └── Data / Analytics Engineer
```

---

## Collaboration Workflow

### Phase Model — iOS Project Lifecycle

The team follows a phased lifecycle mapped to realistic iOS development:

```
┌─────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  1. DISCOVER │──▶│  2. DEFINE   │──▶│  3. DESIGN   │──▶│  4. DEVELOP  │
│              │   │              │   │              │   │              │
│ - Market     │   │ - PRD        │   │ - Wireframes │   │ - Sprint dev │
│   research   │   │ - User       │   │ - HIG-based  │   │ - Code       │
│ - Stakeholder│   │   stories    │   │   mockups    │   │   reviews    │
│   interviews │   │ - Acceptance │   │ - Prototypes │   │ - Unit tests │
│ - Competitive│   │   criteria   │   │ - Design     │   │ - API work   │
│   analysis   │   │ - Tech       │   │   system     │   │ - Feature    │
│              │   │   feasibility│   │              │   │   branches   │
└─────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
                                                               │
        ┌──────────────────────────────────────────────────────┘
        ▼
┌─────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  5. TEST     │──▶│  6. RELEASE  │──▶│ 7. MONITOR   │──▶│ 8. MAINTAIN  │
│              │   │              │   │              │   │              │
│ - QA pass    │   │ - TestFlight │   │ - Crash      │   │ - Bug fixes  │
│ - Automation │   │   beta       │   │   reports    │   │ - OS updates │
│   suites     │   │ - App Store  │   │ - Analytics  │   │ - Feature    │
│ - Security   │   │   review     │   │ - User       │   │   iterations │
│   audit      │   │ - Phased     │   │   feedback   │   │ - Tech debt  │
│ - Perf       │   │   rollout    │   │ - Perf       │   │ - Dependency │
│   profiling  │   │ - Release    │   │   dashboards │   │   updates    │
│ - A11y check │   │   notes      │   │              │   │              │
└─────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
```

### Agent Involvement per Phase

| Phase | Primary Agents | Supporting Agents |
|-------|---------------|-------------------|
| 1. Discover | Product Manager, Business Analyst, Support Engineer | Data/Analytics Engineer |
| 2. Define | Product Manager, Business Analyst, Solution Architect | iOS Team Lead, Scrum Master |
| 3. Design | UI/UX Designer, Accessibility Specialist | Solution Architect, Senior iOS Dev |
| 4. Develop | Senior/Mid/Junior iOS Devs, Backend Dev | Solution Architect, DevOps Engineer |
| 5. Test | QA Lead, QA Engineer, Automation Tester | Security Specialist, Performance Engineer, Accessibility Specialist |
| 6. Release | DevOps Engineer, iOS Team Lead | QA Lead, Product Manager, Documentation Specialist |
| 7. Monitor | Data/Analytics Engineer, Support Engineer | Performance Engineer, Product Manager |
| 8. Maintain | Senior/Mid iOS Devs, DevOps Engineer | Security Specialist, QA Lead |

---

## Communication Rules

### 1. Channels

| Channel | Purpose | Participants |
|---------|---------|-------------|
| `#standup` | Daily async status updates | All agents |
| `#architecture` | Technical design decisions | Architect, Team Lead, Senior Dev, Security, Performance |
| `#design-review` | UI/UX review & feedback | Designer, Accessibility, Product Manager, iOS Devs |
| `#code-review` | Pull request discussions | All developers, Team Lead |
| `#qa-testing` | Bug reports, test results | QA Lead, QA Engineer, Automation Tester, Devs |
| `#releases` | Build status, deployment | DevOps, Team Lead, QA Lead, Product Manager |
| `#incidents` | Production issues | All relevant agents |
| `#retrospective` | Sprint retro discussions | All agents |

### 2. Communication Protocols

- **Standup format**: Each agent posts: (1) What was completed, (2) What is in progress, (3) Blockers.
- **Escalation path**: Agent → Direct Report Lead → iOS Team Lead → Product Manager.
- **Decision authority**: Technical decisions owned by Team Lead + Architect. Product decisions owned by Product Manager. Quality gates owned by QA Lead.
- **Response SLA**: Blocking requests must be acknowledged within 1 sprint cycle. Non-blocking within 2 cycles.
- **Handoff protocol**: Every deliverable must include a structured handoff document specifying: what was done, acceptance criteria met, known issues, and next steps.

### 3. Conflict Resolution

1. **Level 1** — Direct discussion between involved agents.
2. **Level 2** — Escalate to shared lead (e.g., iOS Team Lead for dev conflicts).
3. **Level 3** — Scrum Master facilitates mediation session.
4. **Level 4** — Product Manager makes final call.

### 4. Progress Reporting

- **Sprint reviews**: Scrum Master compiles status from all agents.
- **Burndown tracking**: Scrum Master maintains velocity and burndown.
- **Quality dashboards**: QA Lead reports defect density, test coverage, pass rates.
- **Release readiness**: DevOps provides build health, signing status, review compliance.

---

## Coordination of Deliverables

### Dependency Chain

```
Business Analyst (requirements)
        │
        ▼
Product Manager (PRD approval)
        │
        ├──▶ Solution Architect (technical design)
        │           │
        │           ├──▶ Security Specialist (threat model)
        │           └──▶ Senior iOS Dev (implementation plan)
        │
        └──▶ UI/UX Designer (design specs)
                    │
                    └──▶ Accessibility Specialist (a11y audit)
                                │
                                ▼
                    iOS Developers (implementation)
                                │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
              Backend Dev   DevOps    QA Lead
              (API work)   (CI/CD)   (test plan)
                    │           │           │
                    └───────────┼───────────┘
                                ▼
                        QA Engineers (testing)
                                │
                                ▼
                    Performance Engineer (profiling)
                                │
                                ▼
                    DevOps (TestFlight / App Store)
                                │
                                ▼
                    Data/Analytics (monitoring)
                                │
                                ▼
                    Documentation Specialist (release notes, docs)
                                │
                                ▼
                    Support Engineer (user-facing support)
```

### Decision Matrix (RACI)

| Decision | Responsible | Accountable | Consulted | Informed |
|----------|------------|-------------|-----------|----------|
| Feature prioritization | Product Manager | Product Manager | BA, Team Lead | All |
| Architecture decisions | Solution Architect | iOS Team Lead | Senior Dev, Security | All devs |
| UI/UX standards | UI/UX Designer | iOS Team Lead | Accessibility, PM | All devs |
| Code merge approval | Senior iOS Dev | iOS Team Lead | Reviewer | QA |
| Release go/no-go | QA Lead | Product Manager | DevOps, Team Lead | All |
| Security sign-off | Security Specialist | Solution Architect | Team Lead | PM, DevOps |
| Performance targets | Performance Engineer | iOS Team Lead | Architect | PM |
| Sprint planning | Scrum Master | Product Manager | Team Lead, Devs | All |

---

## iOS-Specific Standards

### Required Apple Ecosystem Knowledge (All Agents)

- **Xcode**: Project configuration, build settings, schemes, workspace management
- **Swift / SwiftUI / UIKit**: Primary development languages and frameworks
- **Human Interface Guidelines (HIG)**: Apple's design standards
- **TestFlight**: Beta distribution and testing
- **App Store Connect**: Submission, review, metadata, analytics
- **Provisioning & Signing**: Certificates, profiles, entitlements
- **CI/CD**: Xcode Cloud, Fastlane, GitHub Actions for iOS
- **Device Compatibility**: iPhone, iPad, various screen sizes, iOS versions
- **Accessibility**: VoiceOver, Dynamic Type, color contrast, assistive technologies
- **Performance**: Instruments, MetricKit, Energy diagnostics

### Quality Gates

Every release must pass:

1. All unit tests green (minimum 80% code coverage)
2. All UI tests passing on target devices
3. Zero P0/P1 bugs open
4. Security audit completed with no critical findings
5. Performance benchmarks met (launch time < 2s, memory < threshold, no frame drops)
6. Accessibility audit passed (WCAG 2.1 AA equivalent)
7. App Store Review Guidelines compliance verified
8. Documentation updated
9. Release notes prepared

---

## File Index

All agent definitions are in the `agents/` directory:

```
agents/
├── TEAM_OVERVIEW.md                  ← This file
├── product_manager.md
├── scrum_master.md
├── ios_team_lead.md
├── business_analyst.md
├── solution_architect.md
├── ios_ui_designer.md
├── senior_ios_developer.md
├── mid_ios_developer.md
├── junior_ios_developer.md
├── backend_api_developer.md
├── qa_lead.md
├── qa_ios_engineer.md
├── automation_test_engineer.md
├── ios_devops_engineer.md
├── security_specialist.md
├── performance_engineer.md
├── documentation_specialist.md
├── support_engineer.md
├── data_analytics_engineer.md
└── accessibility_specialist.md
```
