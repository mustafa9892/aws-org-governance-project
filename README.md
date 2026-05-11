# AWS Multi-Account Governance Project

## Overview
This project demonstrates a multi-account AWS environment using AWS Organisations with governance enforced through Service Control Policies.

The setup includes separate Organizational Units (OUs) for Dev, Prod, and Security to enforce isolation, cost control, and security best practices.

---

## Architecture

Root  
├── Security OU  
│   └── Security Account  
├── Dev OU  
│   └── Dev Account  
└── Prod OU  
    └── Prod Account  

<img width="1024" height="558" alt="image" src="https://github.com/user-attachments/assets/680707ea-2015-4d5e-81ab-a96a59f08d0f" />



---

## SCPs Implemented

### Dev OU SCP
- Restricts EC2 instance launches to `t3.micro`  
- Denies EC2 operations outside `us-east-1`  
- Denies creation of Internet Gateway and NAT Gateway  
- Denies usage of global services like CloudFront and Global Accelerator  

**Purpose:**
- Enforce cost control  
- Limit resource usage to a single region  
- Prevent unintended internet exposure  
- Avoid use of global services in development  

---

### Security OU SCP
- Denies delete actions on:
  - CloudTrail  
  - AWS Config  
  - S3 buckets and objects  

**Purpose:**
- Protect logging and audit infrastructure from accidental or malicious deletion  

---

## Testing

- Verified SCP enforcement by logging into Dev account
- Attempted EC2 launches outside `us-east-1` → Denied  
- Attempted restricted services → Denied    

---

## Challenges Faced

- Attempted to provision the setup using IaC via Amazon Q  
- Stack creation failed for SCP resources  
- Rollback issues occurred due to AWS account lifecycle constraints  
- Learned that accounts must be made standalone before deletion  

---

## Future Improvements

- Implement AWS Service Catalogue for controlled provisioning in Prod  
- Add monitoring and logging  
- Refine SCP strategy for production-grade governance

## Stages of the project:



## Stage 1 -  Service Catalog Setup & Portfolio Sharing
<img width="1024" height="559" alt="image" src="https://github.com/user-attachments/assets/d5d4b50c-8159-4934-b905-fb80047fc951" />


## Objective:
Create centralized provisioning using AWS Service Catalog
## What Worked:
 - Created portfolio and product using CloudFormation template
 - Enabled Organizations-based sharing
 - Successfully imported portfolio into PROD account
## What Failed / Challenges:
 - Portfolio visible but not usable (no launch option)
 - Confusion between IAM-based sharing vs Org-based sharing
 - Could not assign PROD principals from management account
## Key Learning:
Portfolio visibility ≠ provisioning entitlement. Service Catalog has its own governance layer beyond IAM.

## Stage 2: Launch Constraint & IAM Debugging

## Objective:
Enable controlled provisioning via launch constraints
## What Worked:
- Created launch constraint role
- Fixed permission issues using combination of custom and generated policies
- Resolved iam:PassRole requirement
## What Failed / Challenges:
- Cross-account role not accepted during constraint creation
- Errors like:
  - “Cross-account pass role is not allowed”
  - “Access denied while assuming role”
- Generated policies (Amazon Q) were incomplete
## Mitigation:
 - Used mirrored role strategy (same role name across accounts)
 - Combined Amazon Q–generated policies with manual fine-tuning
## Key Learning:
 - iam:PassRole is critical because Service Catalog passes the role to AWS CloudFormation for provisioning.

## Stage 3: Identity Context & UI Limitations

## Objective:
 - Enable product provisioning from PROD account
## What Worked:
 - Verified backend access using CLI (search-products)
 - Confirmed product availability
## What Failed / Challenges:
 - Product visible but no “Launch” button
 - Not visible in provisioning view
## Root Cause:
 - Using OrganizationAccountAccessRole (assumed role)
## Mitigation:
 - Switched to direct IAM user in PROD
## Key Learning:
 - Service Catalog UI depends on principal resolution, not just permissions. Assumed roles may break provisioning visibility.

## Stage 4: Infrastructure as Code (CloudFormation Debugging)

## Objective:
 - Deploy infrastructure via Service Catalog product
## What Worked:
 - Successfully created product using IaC template
 - Fixed template issues iteratively
## What Failed / Challenges:
 - Initial template generated via Amazon Q failed
## Resource naming constraints:
 - ALB name too long
 - Target group name too long
## Mitigation:
 - Manually adjusted naming conventions
 - Validated resource constraints
## Key Learning:
 - CloudFormation failures are often runtime constraint issues, not syntax errors.

## Stage 5: Networking & Load Balancer Constraints

## Objective:
 - Deploy a functional ALB-backed architecture
## What Worked:
 - ALB provisioning logic mostly correct
## What Failed / Challenges:
 - ALB failed to deploy due to subnet configuration
 - Error: requires subnets across multiple AZs
## Mitigation (in progress):
 - Update template to include subnets in at least 2 Availability Zones
## Key Learning:
 - AWS enforces architectural best practices (like multi-AZ) at deployment time.

## Stage 6: Incident Response & Debug Access Design (Prod + Security Accounts)

<img width="1024" height="559" alt="image" src="https://github.com/user-attachments/assets/b8a421c8-e6b6-43e3-a410-44a2f9094b23" />



In this stage, I focused on designing and testing operational access for debugging and incident response across accounts. The goal was to move from theoretical IAM design to real, testable access patterns under pressure scenarios.

## What was implemented
 - Created a Debugger access flow in the Production account for controlled troubleshooting.
 - Designed and tested an Incident Response (IR) team setup in the Security account, with cross-account access into Production.
 - Built a least-privilege IR role in Production, primarily using:
 - SSM-based access (StartSession, SendCommand)
 - Tag-based scoping (AllowIR=true)
 - Minimal EC2 permissions for containment actions
 - Validated cross-account role assumption flows through both:
 - AWS Console (role switching, multi-session support)
 - AWS CLI (explicit STS workflows)
## Key challenges encountered

1. Role Assumption Debugging (Cross-Account)
    - Faced multiple failures while assuming roles across accounts despite correct trust policies.
    - Root cause was often credential context mismatch (CLI using unintended identity).
    - Learned to consistently validate identity using sts get-caller-identity
    - Understood the difference between:
      - user credentials
      - assumed role sessions
      - MFA-backed session tokens

2. Console vs CLI Identity Behavior
   - In Console, even after role switching, identity still shows the original IAM user.
   - This initially caused confusion when validating access chains.
   - Established that:
     - Authorization is based on the current role
     - Audit trail retains original user identity

3. IAM Policy Precision Issues
   - Encountered failures due to:
   - Misplacement of actions like ssm:ListDocuments
   - Missing supporting read permissions required by AWS Console
   - Learned that:
      - Some APIs require "Resource": "*" regardless of scoping intent
      - AWS Console depends on multiple hidden API calls, not just primary actions

4. Session Manager Visibility Gaps
   - Instances visible to admin were not visible to IR role.
   - Despite correct tagging (AllowIR=true) and SSM setup visibility remained inconsistent
   - Highlighted the gap between:
       - API-level permissions
       - Console-level aggregation behavior
   - Issue still under investigation (possible hidden dependency or constraint)

5. Debugger Workflow Validation (Production)
   - Successfully ran and tested a shell-based debugging script via SSM.
   - Verified that restricted actions (like patching) were explicitly blocked through IAM policies.
   - Confirmed that:
      - Access allowed only intended debugging actions
      - Denied actions behaved as expected (least-privilege enforcement working correctly)
   
6. Incident Response Workflow (Security → Prod)
   - Designed IR workflow and corresponding IAM policies.
   - Eliminated an unnecessary role hop (Security User → Security IR → Prod IR) in favor of a simpler and more direct access pattern.
   - Enforced MFA and user tagging conditions in the Prod IR role trust policy to control who can assume the role.
   - However, unable to fully test the IR script execution end-to-end due to:
   - Session Manager visibility inconsistencies
   - Ongoing MFA + CLI session handling issues
   
   - As a result:
   - IR execution flow remains partially validated
   - Some access and execution paths still require debugging
   
7. MFA-Based Role Assumption (CLI Challenges)
  - Attempted to enforce MFA for IR access.
  - Successfully generated session tokens using MFA.
  - However, faced ongoing issues with:
    - Correctly applying session credentials in CLI
    - Ensuring role assumption uses MFA-backed identity
    - This remains partially unresolved and requires further refinement.

## Key learnings
 - IAM failures are often caused by execution context issues, not just policy misconfiguration.
 - AWS Console behavior can be misleading during debugging, especially with role chaining.
 - Designing for incident response requires balancing:
    - security (least privilege, MFA)
    - operational simplicity (fast access during incidents)
 - Tag-based access control works well for resource scoping, but not for identity enforcement.

<img width="1040" height="660" alt="image" src="https://github.com/user-attachments/assets/fe7519f1-039d-4770-a0ce-96ac4a72e733" />


## Current state
 - Debugger access in Production: working and validated (including script execution)
 - IR role access and permissions: designed but partially tested
 - Cross-account assumption flow: validated
 -MFA-based CLI workflow: partially working (needs cleanup)
 -Session Manager visibility inconsistency: under investigation

---

## Stage 7 — Incident Response Automation & Human-in-the-Loop Containment

<img width="1024" height="559" alt="image" src="https://github.com/user-attachments/assets/887e0a18-e56b-43a8-ae88-2b502513fdd4" />


This stage focused on evolving the project from basic governance controls into a lightweight cloud incident response workflow capable of:

- detecting suspicious EC2 activity
- calculating contextual severity scores
- notifying responders through Slack
- requiring explicit approval before containment
- automatically isolating impacted instances

---

## Architecture Flow

```text
EC2 Detection Script
→ Severity Scoring & Signal Correlation
→ Lambda Alerting
→ Slack Incident Notification
→ Human Approval Button
→ API Gateway
→ Containment Lambda
→ Security Group Isolation
```

---

## Detection Layer

A host-based Bash detection script was deployed on EC2 instances to collect lightweight forensic telemetry including:

- running processes
- outbound network connections
- login activity
- execution context

The script evaluates indicators such as:

- suspicious process patterns
- reverse shell heuristics
- outbound connection activity
- root user execution

Detection results are packaged into structured JSON payloads and sent to AWS Lambda for downstream processing.

---

## Severity Scoring Refinement

The initial implementation treated isolated indicators too aggressively, causing false-positive HIGH severity alerts during normal administrative operations.

To reduce operational noise, the scoring model was refined to become more context-aware through:

- lower weighting for weak standalone signals
- signal correlation before escalation
- contextual severity calculation

Example:

```text
Root activity alone → LOW
Suspicious process alone → MEDIUM
Root + suspicious process correlation → HIGH
```

This refinement improved alert confidence while maintaining responsiveness to suspicious behavior.

---

## Slack Alerting Workflow

An AWS Lambda function was implemented to:

- parse incident payloads
- format structured incident alerts
- send notifications into Slack channels

Slack interactive approval buttons were added to support responder-driven containment decisions.

Example actions:

- Approve Containment
- Reject

---

## API Gateway Integration

Slack interactivity requests were routed through Amazon API Gateway to securely invoke backend containment logic.

This enabled:

- external Slack interaction handling
- Lambda invocation through HTTPS endpoints
- structured action payload processing

---

## Containment Lambda

A dedicated containment Lambda was implemented to:

- validate Slack responder identity
- authorize containment actions
- modify EC2 Security Groups dynamically

Upon approval, the instance is moved into a quarantine Security Group to isolate it from production traffic.

---

## Key Challenges Encountered

During implementation, several integration and debugging challenges were encountered, including:

- IAM permission refinement
- Slack interactivity configuration
- Lambda payload parsing
- authorization validation logic
- false-positive severity escalation

These iterations significantly improved understanding of:

- cloud-native incident response workflows
- event-driven automation
- detection engineering concepts
- operational alert design

---

## Current State

Current implementation provides:

- lightweight heuristic-based detection
- context-aware severity scoring
- Slack-driven human approval workflow
- automated EC2 containment orchestration

---

## Planned Improvements

Future iterations will focus on:

- behavior-based detection
- anomaly-aware scoring
- threat intelligence enrichment
- persistence detection
- improved forensic collection
- reducing heuristic dependence
