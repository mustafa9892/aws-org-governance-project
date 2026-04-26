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

    <img width="1024" height="558" alt="image" src="https://github.com/user-attachments/assets/c0f68b80-da1a-47b9-a0ae-0c3c44255758" />


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
<img width="1024" height="559" alt="image_137778ae-c62c-4894-bfd2-f736657aaf2e" src="https://github.com/user-attachments/assets/cdb56e11-7ecd-4ba5-9c2b-90d90bfc8be4" />

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

<img width="1024" height="559" alt="image_8d07b512-9be1-4e63-9044-71402366987a" src="https://github.com/user-attachments/assets/81d4ecb4-96a6-403b-84ae-c87f2cef5bee" />


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
