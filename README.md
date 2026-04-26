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

<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1040 660" font-family="Arial, sans-serif">

  <defs>
    <marker id="ag" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto">
      <path d="M0,0 L0,6 L9,3 z" fill="#666"/>
    </marker>
    <marker id="ag2" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto">
      <path d="M0,0 L0,6 L9,3 z" fill="#27ae60"/>
    </marker>
  </defs>

  <!-- Background -->
  <rect width="1040" height="660" fill="#f4f6f9"/>

  <!-- Title -->
  <text x="520" y="36" text-anchor="middle" font-size="18" font-weight="bold" fill="#1a1a2e">Incident Response Access Model — Before &amp; After</text>

  <!-- Divider -->
  <line x1="520" y1="50" x2="520" y2="630" stroke="#bbb" stroke-width="1.5" stroke-dasharray="6,4"/>

  <!-- Section labels -->
  <text x="255" y="66" text-anchor="middle" font-size="13" font-weight="bold" fill="#c0392b">Before (Role Chaining)</text>
  <text x="785" y="66" text-anchor="middle" font-size="13" font-weight="bold" fill="#27ae60">After (Simplified Access)</text>

  <!-- ═══════════════ LEFT — BEFORE ═══════════════ -->

  <!-- Management Account Box -->
  <rect x="50" y="78" width="410" height="88" rx="6" fill="#fff" stroke="#2563eb" stroke-width="1.8"/>
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAIAAAADnC86AAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAKKADAAQAAAABAAAAKAAAAAB65masAAAEgElEQVRYCWNU0bdjGAjANBCWguwctZhuIT8a1KNBTbMQGE1ckKBVlJftaq46sH3V1VN7DmxbWZybyszMrKGmsnTuRHMTA4gaHw9nINdATwvC9XB1AHL5+fmkJMSn9DSdObj58slda5fMsDI3xhpdLFhFDfV1/v//N2navC9fv9pamWUkx7x7/3H1+q1G+jr+3m4nz1wA6gr29zQzNvB0dbxw6RqQGx7kA7Ty48dPi2b2CQsJdvRP//Tps6a6qqiIMFYrsFu8btN2IIJo2LXvsK21uZW50fwlq06cPg/xATMTE9ARZ85fNjHSAypjZWU1NtRdvnoTkKGuqgR04poN24DiQL1YbQUKYrcYKAF0tbGBDg8Pz4uXr4BuFxTgBwru2X+koapQRlpSSICfjY115rylMya0cnFx6mqpc3Jw7Np76Pfv3wcOnwgN9Aa6YOvOfcdPnfvz5w9Wu7Fb7Opo29tW8+79h7v3Hwnw86ooyV+/eQdk8YEj9ZUFQE/zcHNdvnbz+Kmz//79A3rd1Fj/9Zt35y9dBaopqW7NSo3183IFxsXrN2/L6zoOHzuFaTcj1obAkV1rf/365eoX/fffP6CeDctn//37NzgmA8het2zWw4dPODjZ79572DNp1vJ5k0+dvWBlbnL95u261j64BYyMjMBk2NFY8ePnT4/AOLg4nIElHzMxMQkJ8j9++hxiq4qSgqqyIi8vD0TPnn2HLcyMTA31Tp+7CBQB2upoZ6WrowGPTmAUAMX///8PTBDAoBYXEwE6Am4fnIElqIGht+/gMVcn25kT2799+26or33m/CVg8MrJSj16/AwY2oU5KUA3AVMW0BRgCs9Kjfv0+QvQGiBXWVF+zZLpQPtev36nrCRvaqQ3Y+4SoCPg9sEZ2IOag509OjwA6NG79x9u3Lr758+fQIu37z4A0QZMO9+//9iyYy+QC8zf0WH+Dx8/PXjkJETW2sLEztpcQlwUmLX2HTp+4PBxiDgaid1iNEW04GIJampZAyxPtDRUOTk5bt99cOMWKFMgAywWG+ppX7h8DWvEIOvEzw7wcXOytwZma011FRkpST1LdzT1zEIS8mhCpkb6DVVF3759u/fgEdnW37h1F5gmgEXK/YePjQx0lqxcj2YLFotv3bl39vyl2vK8xJhQPj7et+/ev//wEU0bQa6sjFRsRFBeRuKvX78fPHwMSfPIunAmLmB2TImLSIoNA1Y4N2/fO3zs5JVrt65evwVMwLiCQUxUREdLDVhzWJgaamuq7T90rLV7SllBRk1zD6bTcVoMcR2wHI4JD0yOCxcSFICIAOurV6/efvz8+SMw8375ysbGBiw+gSW5vKw0UDFQDbCMO3T05KLl644cPw0sOhQVZO/dfwTRi0wSsBiilIWFBVgg21mbATOohpoy1pIIWFZfvHLt5OkLW3bsefP2PbIdWNlEWYysE5g9REWERISERESEuLk4P3z8/OHDxxevXj9/8QpZGUE2yRYTNJFIBVgqCSJ1Uqhs1GIKA5B47aNBTXxYUahy5AU1AD0k0AuulD18AAAAAElFTkSuQmCC" x="62" y="86" width="32" height="32"/>
  <text x="260" y="118" text-anchor="middle" font-size="13" font-weight="600" fill="#1a1a2e">Management Account</text>
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAIAAABvFaqvAAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAGKADAAQAAAABAAAAGAAAAADiNXWtAAABj0lEQVQ4EWO8a+LDQA3ARA1DQGYMY4NY0MKIy9ZMMDWSVV7m9/1H72cu+3b8LJoCXFyUMAKaIlKa/m7ygkeece9mLhWpyeE0N8ClE00cxSCgW143T/p++uK/b9+/Hz/3pn2aYEokmgZcXBSDgD76efUmXOnPq7dYFWTgXPwMlDD6/fAxu57m9xPnIXo49DR+P3gCZAvlJjAyoVj59/OXD/NWIRuNIg0MXdHqXC4bU2ZBfm57c+GyjPezlgFV/337/g8qEkqPYWRBcQQjWhbhtDQSTAzlMNT5fubSh3krv5++hGwtnK14fP0D29D/f/7ARVBMBYoCw/jHqYsKR9c+z6yGKyKGgeI1YjTgUoPuIjR1kGB+O3mBUHYcMLyBDIZ//9DUQLgEDAIGMwMovv7DGVhNAQqiGwRyAlJ0MAsLAh0inJsI0Q9nMDIxo5mIbhDQZmSDYA5B08Xwum0ycpQBpdGjHyTEzAyMtfsWAei68fKxxNr////eTZqPVxcWSSwuwqKKCCEsLiJCFxYlg88gAKsxj+QB87dCAAAAAElFTkSuQmCC" x="64" y="122" width="24" height="24"/>
  <text x="76" y="158" text-anchor="middle" font-size="9" fill="#555">IAM</text>

  <!-- Security Account Box (before) -->
  <rect x="50" y="192" width="410" height="175" rx="6" fill="#fff" stroke="#2563eb" stroke-width="1.8"/>
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAIAAAADnC86AAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAKKADAAQAAAABAAAAKAAAAAB65masAAAEgElEQVRYCWNU0bdjGAjANBCWguwctZhuIT8a1KNBTbMQGE1ckKBVlJftaq46sH3V1VN7DmxbWZybyszMrKGmsnTuRHMTA4gaHw9nINdATwvC9XB1AHL5+fmkJMSn9DSdObj58slda5fMsDI3xhpdLFhFDfV1/v//N2navC9fv9pamWUkx7x7/3H1+q1G+jr+3m4nz1wA6gr29zQzNvB0dbxw6RqQGx7kA7Ty48dPi2b2CQsJdvRP//Tps6a6qqiIMFYrsFu8btN2IIJo2LXvsK21uZW50fwlq06cPg/xATMTE9ARZ85fNjHSAypjZWU1NtRdvnoTkKGuqgR04poN24DiQL1YbQUKYrcYKAF0tbGBDg8Pz4uXr4BuFxTgBwru2X+koapQRlpSSICfjY115rylMya0cnFx6mqpc3Jw7Np76Pfv3wcOnwgN9Aa6YOvOfcdPnfvz5w9Wu7Fb7Opo29tW8+79h7v3Hwnw86ooyV+/eQdk8YEj9ZUFQE/zcHNdvnbz+Kmz//79A3rd1Fj/9Zt35y9dBaopqW7NSo3183IFxsXrN2/L6zoOHzuFaTcj1obAkV1rf/365eoX/fffP6CeDctn//37NzgmA8het2zWw4dPODjZ79572DNp1vJ5k0+dvWBlbnL95u261j64BYyMjMBk2NFY8ePnT4/AOLg4nIElHzMxMQkJ8j9++hxiq4qSgqqyIi8vD0TPnn2HLcyMTA31Tp+7CBQB2upoZ6WrowGPTmAUAMX///8PTBDAoBYXEwE6Am4fnIElqIGht+/gMVcn25kT2799+26or33m/CVg8MrJSj16/AwY2oU5KUA3AVMW0BRgCs9Kjfv0+QvQGiBXWVF+zZLpQPtev36nrCRvaqQ3Y+4SoCPg9sEZ2IOag509OjwA6NG79x9u3Lr758+fQIu37z4A0QZMO9+//9iyYy+QC8zf0WH+Dx8/PXjkJETW2sLEztpcQlwUmLX2HTp+4PBxiDgaid1iNEW04GIJampZAyxPtDRUOTk5bt99cOMWKFMgAywWG+ppX7h8DWvEIOvEzw7wcXOytwZma011FRkpST1LdzT1zEIS8mhCpkb6DVVF3759u/fgEdnW37h1F5gmgEXK/YePjQx0lqxcj2YLFotv3bl39vyl2vK8xJhQPj7et+/ev//wEU0bQa6sjFRsRFBeRuKvX78fPHwMSfPIunAmLmB2TImLSIoNA1Y4N2/fO3zs5JVrt65evwVMwLiCQUxUREdLDVhzWJgaamuq7T90rLV7SllBRk1zD6bTcVoMcR2wHI4JD0yOCxcSFICIAOurV6/efvz8+SMw8375ysbGBiw+gSW5vKw0UDFQDbCMO3T05KLl644cPw0sOhQVZO/dfwTRi0wSsBiilIWFBVgg21mbATOohpoy1pIIWFZfvHLt5OkLW3bsefP2PbIdWNlEWYysE5g9REWERISERESEuLk4P3z8/OHDxxevXj9/8QpZGUE2yRYTNJFIBVgqCSJ1Uqhs1GIKA5B47aNBTXxYUahy5AU1AD0k0AuulD18AAAAAElFTkSuQmCC" x="62" y="200" width="32" height="32"/>
  <text x="260" y="230" text-anchor="middle" font-size="13" font-weight="600" fill="#1a1a2e">Security Account</text>

  <!-- Security User -->
  <image href="data:image/png;base64,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" x="72" y="248" width="48" height="48"/>
  <text x="96" y="308" text-anchor="middle" font-size="9" fill="#333">Security User</text>
  <text x="96" y="319" text-anchor="middle" font-size="9" fill="#333">(IR Team)</text>
  <!-- Permissions icon below Security User -->
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAMKADAAQAAAABAAAAMAAAAADbN2wMAAAEBElEQVRoBe2aTUwTQRTHZ7ZQoFIETh5MpKU1xgMKFJR4ABO/SGijRo5y0IMRPaiRo4HozcSExKhXT15IDIIL4lUvBNqAHCAptCRy8CJ4sClYOuN721Y3S7fMkv3gwCTLzL55O/P7v3nT7AeEHBRnI0D1pl86F/GWb7Fh6L8OR62en4X2TRj7K3GR/sbpj3G9eSS9jjz8Leh3Ah6xKuG4QLJkjPf2utBQrJQVM+ZtGHkiUdbsm5mYK+FnSVfy9NVaVrY9D4OfSCRSJ6FeKDaR7gqAsxJ5J+AR1Dc3+osQuoptKpE6rIuVUgKK+e9qi5/pPrqrk4kOpgpIhHqeS1nXfDwUaTaRseRQpglAeE7IACy410WZbatQahOXVK7uVMFnKGE3/DPyuLrfyrbwCsRbwy0roZ5BLcwO+Fl5TOtj5bmQgB9Nlw5JlE8AyBACF4CchkcOoRQ68u1zKh4K3wG1I5zwAQBXNORzPpc2Nke+EEShFUDn4Oz4B0ZIL2zSDILvB3jkEhagFYFClA3rUOSRB4shAXgBroSLsVN4+B2GRx6hPYCO6tIQkxfV5062Da+Ak7DF5t7TChQbCG3x9p4OidOHbGP7ZnB5ckvPz0y7aQIUeEamCOFe12FpGiBfmAmqN5YpKfQfnngJJe98fs+w3oRm24UFJLu6KhMtkSYtgBbe31DVR0dGslo/q86FBMQD3RXZVPUol9iXZEv4bAHGaXjkENoDgebq7cRq+if41zCJTwH4FbxYUnI+lzZ2Rx7nxyK0ApgSCIj5DdfUAPin/QAvLAAdtSLApGxYpyKPTFiEUijnmhMBrzj6kqvpBNp8DVVDdm7YAoe6NiQAL8wDP1EGmVEP5UxbaA84gyY264EAsThZ52VoBZZD4e6VtnC/FgefmcH++nvH5Xptn9XnwgLwjRsl/D3h/BU8E98vgCH8b7dbBvvdP5nytwW7XbWwgOD05BpAPgIwDs/DL1FEAR7e0XeCfY0zCfttLcICkKoxKr8B/HvQVESk3O6YCv58IDa2bCs9TGZIAMLlRJDHedDjUK9D5B2BRwbDAjBtOCWRvACs6iWJKTd3KpttTUMCtDkPifQUSP/tCduoVRMJC9DCY9pAOg2q94T610k1h6VNYQFbvNxNKakGmjXGs12FDave2Ixz3S8pVqkQFnBsQd4o2+QXs5R3BqOTK2ogFMEZbwtE5Wdqux1tQ3ejKAKg8NhRAjE5usNog0F4BWxg2dMU+itAIdKc1OGHjUC01fbPrEvt83WEZXyoinG6rqdOXwCH+x5Cb8OHjWgiNKt3vWV2N7zLxwK3LYuNPs8i0UHQFbCZ9jyo8KS5xMk1GMT2XxdgV/7VgPNsv9OPrUokD/7oROAv/pOIrL11Gm8AAAAASUVORK5CYII=" x="72" y="325" width="32" height="32"/>
  <text x="88" y="366" text-anchor="middle" font-size="8" fill="#555">Permissions</text>

  <!-- IAM Role (hard hat) — Security -->
  <image href="data:image/png;base64,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" x="328" y="248" width="48" height="48"/>
  <text x="352" y="308" text-anchor="middle" font-size="9" fill="#333">IAM Role</text>
  <text x="352" y="319" text-anchor="middle" font-size="9" fill="#333">IncidentResponseRole</text>
  <!-- Permissions icon below IAM Role -->
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAMKADAAQAAAABAAAAMAAAAADbN2wMAAAEBElEQVRoBe2aTUwTQRTHZ7ZQoFIETh5MpKU1xgMKFJR4ABO/SGijRo5y0IMRPaiRo4HozcSExKhXT15IDIIL4lUvBNqAHCAptCRy8CJ4sClYOuN721Y3S7fMkv3gwCTLzL55O/P7v3nT7AeEHBRnI0D1pl86F/GWb7Fh6L8OR62en4X2TRj7K3GR/sbpj3G9eSS9jjz8Leh3Ah6xKuG4QLJkjPf2utBQrJQVM+ZtGHkiUdbsm5mYK+FnSVfy9NVaVrY9D4OfSCRSJ6FeKDaR7gqAsxJ5J+AR1Dc3+osQuoptKpE6rIuVUgKK+e9qi5/pPrqrk4kOpgpIhHqeS1nXfDwUaTaRseRQpglAeE7IACy410WZbatQahOXVK7uVMFnKGE3/DPyuLrfyrbwCsRbwy0roZ5BLcwO+Fl5TOtj5bmQgB9Nlw5JlE8AyBACF4CchkcOoRQ68u1zKh4K3wG1I5zwAQBXNORzPpc2Nke+EEShFUDn4Oz4B0ZIL2zSDILvB3jkEhagFYFClA3rUOSRB4shAXgBroSLsVN4+B2GRx6hPYCO6tIQkxfV5062Da+Ak7DF5t7TChQbCG3x9p4OidOHbGP7ZnB5ckvPz0y7aQIUeEamCOFe12FpGiBfmAmqN5YpKfQfnngJJe98fs+w3oRm24UFJLu6KhMtkSYtgBbe31DVR0dGslo/q86FBMQD3RXZVPUol9iXZEv4bAHGaXjkENoDgebq7cRq+if41zCJTwH4FbxYUnI+lzZ2Rx7nxyK0ApgSCIj5DdfUAPin/QAvLAAdtSLApGxYpyKPTFiEUijnmhMBrzj6kqvpBNp8DVVDdm7YAoe6NiQAL8wDP1EGmVEP5UxbaA84gyY264EAsThZ52VoBZZD4e6VtnC/FgefmcH++nvH5Xptn9XnwgLwjRsl/D3h/BU8E98vgCH8b7dbBvvdP5nytwW7XbWwgOD05BpAPgIwDs/DL1FEAR7e0XeCfY0zCfttLcICkKoxKr8B/HvQVESk3O6YCv58IDa2bCs9TGZIAMLlRJDHedDjUK9D5B2BRwbDAjBtOCWRvACs6iWJKTd3KpttTUMCtDkPifQUSP/tCduoVRMJC9DCY9pAOg2q94T610k1h6VNYQFbvNxNKakGmjXGs12FDave2Ixz3S8pVqkQFnBsQd4o2+QXs5R3BqOTK2ogFMEZbwtE5Wdqux1tQ3ejKAKg8NhRAjE5usNog0F4BWxg2dMU+itAIdKc1OGHjUC01fbPrEvt83WEZXyoinG6rqdOXwCH+x5Cb8OHjWgiNKt3vWV2N7zLxwK3LYuNPs8i0UHQFbCZ9jyo8KS5xMk1GMT2XxdgV/7VgPNsv9OPrUokD/7oROAv/pOIrL11Gm8AAAAASUVORK5CYII=" x="336" y="325" width="32" height="32"/>
  <text x="352" y="366" text-anchor="middle" font-size="8" fill="#555">Permissions</text>

  <!-- Arrow: User → Role -->
  <line x1="122" y1="272" x2="324" y2="272" stroke="#666" stroke-width="1.5" marker-end="url(#ag)"/>

  <!-- Role chaining note -->
  <text x="232" y="292" text-anchor="middle" font-size="8" fill="#888">Role chaining for centralized</text>
  <text x="232" y="302" text-anchor="middle" font-size="8" fill="#888">access and separation of duties</text>

  <!-- Production Account Box (before) -->
  <rect x="50" y="392" width="410" height="175" rx="6" fill="#fff" stroke="#2563eb" stroke-width="1.8"/>
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAIAAAADnC86AAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAKKADAAQAAAABAAAAKAAAAAB65masAAAEgElEQVRYCWNU0bdjGAjANBCWguwctZhuIT8a1KNBTbMQGE1ckKBVlJftaq46sH3V1VN7DmxbWZybyszMrKGmsnTuRHMTA4gaHw9nINdATwvC9XB1AHL5+fmkJMSn9DSdObj58slda5fMsDI3xhpdLFhFDfV1/v//N2navC9fv9pamWUkx7x7/3H1+q1G+jr+3m4nz1wA6gr29zQzNvB0dbxw6RqQGx7kA7Ty48dPi2b2CQsJdvRP//Tps6a6qqiIMFYrsFu8btN2IIJo2LXvsK21uZW50fwlq06cPg/xATMTE9ARZ85fNjHSAypjZWU1NtRdvnoTkKGuqgR04poN24DiQL1YbQUKYrcYKAF0tbGBDg8Pz4uXr4BuFxTgBwru2X+koapQRlpSSICfjY115rylMya0cnFx6mqpc3Jw7Np76Pfv3wcOnwgN9Aa6YOvOfcdPnfvz5w9Wu7Fb7Opo29tW8+79h7v3Hwnw86ooyV+/eQdk8YEj9ZUFQE/zcHNdvnbz+Kmz//79A3rd1Fj/9Zt35y9dBaopqW7NSo3183IFxsXrN2/L6zoOHzuFaTcj1obAkV1rf/365eoX/fffP6CeDctn//37NzgmA8het2zWw4dPODjZ79572DNp1vJ5k0+dvWBlbnL95u261j64BYyMjMBk2NFY8ePnT4/AOLg4nIElHzMxMQkJ8j9++hxiq4qSgqqyIi8vD0TPnn2HLcyMTA31Tp+7CBQB2upoZ6WrowGPTmAUAMX///8PTBDAoBYXEwE6Am4fnIElqIGht+/gMVcn25kT2799+26or33m/CVg8MrJSj16/AwY2oU5KUA3AVMW0BRgCs9Kjfv0+QvQGiBXWVF+zZLpQPtev36nrCRvaqQ3Y+4SoCPg9sEZ2IOag509OjwA6NG79x9u3Lr758+fQIu37z4A0QZMO9+//9iyYy+QC8zf0WH+Dx8/PXjkJETW2sLEztpcQlwUmLX2HTp+4PBxiDgaid1iNEW04GIJampZAyxPtDRUOTk5bt99cOMWKFMgAywWG+ppX7h8DWvEIOvEzw7wcXOytwZma011FRkpST1LdzT1zEIS8mhCpkb6DVVF3759u/fgEdnW37h1F5gmgEXK/YePjQx0lqxcj2YLFotv3bl39vyl2vK8xJhQPj7et+/ev//wEU0bQa6sjFRsRFBeRuKvX78fPHwMSfPIunAmLmB2TImLSIoNA1Y4N2/fO3zs5JVrt65evwVMwLiCQUxUREdLDVhzWJgaamuq7T90rLV7SllBRk1zD6bTcVoMcR2wHI4JD0yOCxcSFICIAOurV6/efvz8+SMw8375ysbGBiw+gSW5vKw0UDFQDbCMO3T05KLl644cPw0sOhQVZO/dfwTRi0wSsBiilIWFBVgg21mbATOohpoy1pIIWFZfvHLt5OkLW3bsefP2PbIdWNlEWYysE5g9REWERISERESEuLk4P3z8/OHDxxevXj9/8QpZGUE2yRYTNJFIBVgqCSJ1Uqhs1GIKA5B47aNBTXxYUahy5AU1AD0k0AuulD18AAAAAElFTkSuQmCC" x="62" y="400" width="32" height="32"/>
  <text x="260" y="430" text-anchor="middle" font-size="13" font-weight="600" fill="#1a1a2e">Production Account</text>

  <!-- IAM Role (hard hat) — Production -->
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAMKADAAQAAAABAAAAMAAAAADbN2wMAAAHsUlEQVRoBe1Xe2yT1xW/59omdhpgPBtKKLHjjFG2jmI7WUbXpg+1hdgQ1qHu1TFtazWmAao6dZq0R4W2dZqial1VtfzRTVsfiEVt1jiPvdoVLRsjtksfFJZiOyFsJFAYKYEkjv3ds9+1/aVWcHAI+WeSj3S/e++553HPueeecz8hilD0QNEDRQ8UPVD0QNEDRQ/M2AM0Y84pGP9aX2+tGCnzkSHukETrWfB1IF0qBC0SxOcEi0HMB5n5bfQdQ2KwyxuJJKcQVxA9awb037TpuqSVdwrBD2KTCwpq/pDgPBG1MBk/rerueO9D9PRGV21AzHPnfCLHz+Hpr0LlHK2WhTiK7lUhxWsyJWNkSZ0+q06dna+WfkRKKmcplpOQtwolNggSn9Q8AAOntNcixQ8ru4O9GVTh71UZEPM13CmYfgU1KzIbEM2suMn9RnuksOoMRe+nGiuVYTwimL8OjHbAMJN4wB1q2zcdGTM2IOr1PwLmn0GJlvEPVvQDSeomJrkW8+txDtqo5WgJtDNo/wHhAeC7bLbSP6840DwK3AQcq91QYTEsTTi9+7LIZ87xwM5C92NGBsQ9DQ8zUVNWEeKWcDH5ZszlxI4uPxjCRp8nqZ6cHPdxn/8BZvEE2B2QudcV9n2ZxKNqKnFXbEDM59+FIP9FHoHvQ+HLRKLLEPKQ3To+UFEx74MjR4TDMefiIiEtq5i4DsZuAF1thp+SCJdfskztrj7Yed6UGavZ6BXK8hfQzRdET1eFgt8y1yb3V2RA1LfxHmLZOUkI0iHtdjntv6fmZlzEwtC3rmF1iughGPs1UFvQjpMUm13dbW+Z3DFP4Gak3T9iXoqUu9MdaX/SXMvtp23AibqtjmRy9DCO3pUj4ClXuG0HhAB95RD1NnycBD0Lzhq0ESXoi9Xh4CumpGiNfwsp8TLmF8lQa1yHOo6ba2Y/3ZgVieTY9ydt/vGqcNu3Z7p5vQF3uP3w2KjjMzpMMC2Vgn8XXRe43dycu7utBSniRcyvUVa5x8Tn9tM6gei6TW6SfASOtmlmGPKcO9z2lVxBVzuO+gJNxPww5JyXTLXOSPBfWubRmi2L5qjkUQyXoLLXO0PB/RpvwrROQFrUNnPzYBy0JXiXKWC2enco+J2st+cp4mdZPJre2+rulrPQ8ZTWg7uwfbK+aRmAtPZ5kxFHtmPlO+3nzPls9koa27HLPsj8dNwTftCUjfqC8EHGEvTZeO2ma0287gsakE5pCNcsU68z3PZSroDZHKdTqRQ6jAD8XfMUnKEOXWdadRQogxsz65mvNXeSb4wK22heFDy6nsf4shmnt77erkZKr5dsWWYILifFC5EuF6BCzyPBSTw9xpRQMQvLNysjwZ7J8hxK/mGU+D1c7I/GvZH73h3d+tKad5vHET77of9eEsqHfU5c6IIGIM1VmYYhpemMcAnovG5I2o3j96oLhGeEkAp2pg3H7tMWIw4zlms8tkEs4t7AQFyIIAzdi6SwP+4LPDbK/BD49ZsIwC/aHaPjMQ+Kp0UdABNwUqfcCUjrmJjlGcS8DV2Iv/U6Bl1hjz1fWe+p8y+3JsW/M+yk3/b9KEInwTMIo85i57gz/AGRtKIal8GWG0DjhXL9r2BCPwb6/aTtzFZlWJ+uxuI0MtQTMP0nWDNwOnWoziGMM07Sg6kg5vX3YW2lvlxVkXbnVHRxr/9zxHS4b+5w9LbXX09NRZeL7/VtXMtC3guD7k/ryCz2or649LDHE1hsJcYT5RI443I6ynXlv+wJ6BvPBp+AF2ww9W9VobZbLhFVAHGi7u6FiZT9GsNqKJuSKefB1tParblsmFCsxt+Yrboj0PVaep3ToXQXxhfweNyDjKP/5H6EeRme4EurD3W+n9eAWK2/Whi6qNA2ENu1MCg5CQG7nE5HS743T/TGLUupZBwvUvKB2AuWarRytBK0XLgIaW9CcYfBal91pDOmF7UReImGMPDkEmfHz+BU0jUAEaFPZHFeA47Vbr5BpowfwwObQYT94p9JiFYIXwWFqzHW0A8lLYzKLA1xVElyYu1LwN+Bph9mk0H/Cwxjf3jq8Fzw4v94AiCa8eqUe/rLhl9xJ5bYxlMj64Uh005LU5EYckWCf4cO0AoxpQExb+ALWP8N6PRzYQxx+RxZVJN+r4c9HttCUb4Tx7gDayvR8sEYlPwTWvZLxQdYWvpstpL+yT8uxz/RsGC8RN5iIbEF4bAVgkozwmgAuvewki+432iNapyuA7Eb31pMtsS1JCzLkLnKoUNX5bIU05JVkeAZzDOAd/6ptHfgXbLK7a6DrafMNbPv89y9TMk5j0HxNhOHPoQE+TgPqZbqaGciB19wmPmftt8Po78J4jU5DEPZ8Vz0l5wq6E9Whb0rdEbMNeBVGHA7GHQKfweb6kHhuIBwsiMDLUEIfAxrOs1lgQaY1feQmX4LIZB5ddDrC9yqWHwDou6BpMVZaVqufgsNosGhOCXCrynTr13h1h5NM2GAPtpUSfo3UYeSQy/mgQsoQl0we19ZItFc/vafcCFnF7Bj6lvbOF9Lray2DedLGLkaJwwwkSc9gdIRUi5cuAqcHrIIj0qW/0UhOVHpsh8rJNCUU+yLHih6oOiBogeKHih6oOiB/wMP/A+Txu2nI1459wAAAABJRU5ErkJggg==" x="216" y="448" width="48" height="48"/>
  <text x="240" y="508" text-anchor="middle" font-size="9" fill="#333">IAM Role</text>
  <text x="240" y="519" text-anchor="middle" font-size="9" fill="#333">IncidentResponseRole</text>
  <!-- Permissions icon below prod role -->
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAMKADAAQAAAABAAAAMAAAAADbN2wMAAAEBElEQVRoBe2aTUwTQRTHZ7ZQoFIETh5MpKU1xgMKFJR4ABO/SGijRo5y0IMRPaiRo4HozcSExKhXT15IDIIL4lUvBNqAHCAptCRy8CJ4sClYOuN721Y3S7fMkv3gwCTLzL55O/P7v3nT7AeEHBRnI0D1pl86F/GWb7Fh6L8OR62en4X2TRj7K3GR/sbpj3G9eSS9jjz8Leh3Ah6xKuG4QLJkjPf2utBQrJQVM+ZtGHkiUdbsm5mYK+FnSVfy9NVaVrY9D4OfSCRSJ6FeKDaR7gqAsxJ5J+AR1Dc3+osQuoptKpE6rIuVUgKK+e9qi5/pPrqrk4kOpgpIhHqeS1nXfDwUaTaRseRQpglAeE7IACy410WZbatQahOXVK7uVMFnKGE3/DPyuLrfyrbwCsRbwy0roZ5BLcwO+Fl5TOtj5bmQgB9Nlw5JlE8AyBACF4CchkcOoRQ68u1zKh4K3wG1I5zwAQBXNORzPpc2Nke+EEShFUDn4Oz4B0ZIL2zSDILvB3jkEhagFYFClA3rUOSRB4shAXgBroSLsVN4+B2GRx6hPYCO6tIQkxfV5062Da+Ak7DF5t7TChQbCG3x9p4OidOHbGP7ZnB5ckvPz0y7aQIUeEamCOFe12FpGiBfmAmqN5YpKfQfnngJJe98fs+w3oRm24UFJLu6KhMtkSYtgBbe31DVR0dGslo/q86FBMQD3RXZVPUol9iXZEv4bAHGaXjkENoDgebq7cRq+if41zCJTwH4FbxYUnI+lzZ2Rx7nxyK0ApgSCIj5DdfUAPin/QAvLAAdtSLApGxYpyKPTFiEUijnmhMBrzj6kqvpBNp8DVVDdm7YAoe6NiQAL8wDP1EGmVEP5UxbaA84gyY264EAsThZ52VoBZZD4e6VtnC/FgefmcH++nvH5Xptn9XnwgLwjRsl/D3h/BU8E98vgCH8b7dbBvvdP5nytwW7XbWwgOD05BpAPgIwDs/DL1FEAR7e0XeCfY0zCfttLcICkKoxKr8B/HvQVESk3O6YCv58IDa2bCs9TGZIAMLlRJDHedDjUK9D5B2BRwbDAjBtOCWRvACs6iWJKTd3KpttTUMCtDkPifQUSP/tCduoVRMJC9DCY9pAOg2q94T610k1h6VNYQFbvNxNKakGmjXGs12FDave2Ixz3S8pVqkQFnBsQd4o2+QXs5R3BqOTK2ogFMEZbwtE5Wdqux1tQ3ejKAKg8NhRAjE5usNog0F4BWxg2dMU+itAIdKc1OGHjUC01fbPrEvt83WEZXyoinG6rqdOXwCH+x5Cb8OHjWgiNKt3vWV2N7zLxwK3LYuNPs8i0UHQFbCZ9jyo8KS5xMk1GMT2XxdgV/7VgPNsv9OPrUokD/7oROAv/pOIrL11Gm8AAAAASUVORK5CYII=" x="224" y="525" width="32" height="32"/>
  <text x="240" y="566" text-anchor="middle" font-size="8" fill="#555">Permissions</text>

  <!-- Arrow: Role Security → Role Prod -->
  <path d="M352,297 L352,380 L258,445" stroke="#666" stroke-width="1.5" fill="none" marker-end="url(#ag)"/>

  <!-- STS icon -->
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAMKADAAQAAAABAAAAMAAAAADbN2wMAAAG/ElEQVRoBe1ZaWxURRyfmfd22XLYAoHWcthuS7gMSnfLETABQlTsLgIKYoIQ/IBoiCJoAhoJHkSEYBSNCib4wQ8QawTacgpeiErZ5QwUZEvBIrcFIqXtvn0z/mbZR2B9b4/XUv3QSWbnzf/+z/xn5j+zhLSV/3YEqJX6YyPGd3I08Q+An4SaZUV3F+E3IHsnV/QX+uzZcsZKj2qFiBn/rBW+FeDtocNPudIN7XArfZYzUO31XQFTFqN8cP7ezQesBNwt+Mmh47OFzo9JGxSh5eYFt50z02U5A5JRMqRrfMDjcWSRnJGEkT5MsG6CkiuE89MdNO2HnEPb682MMIO595RdCHl95zDCWZrq6gyatB0wk2sJCw2a2J04tTcooc8QIjKJwO/NH0IoJfVOZyNmdQNRyKKCPRUnLAWliWBp0puSh4b4JlKnFsJozYkaT8gBOLIaDiwhQnwCpp9RnahTiU6OVnt880wF2QAmCqGUxIW8/ucoF5+CmGLQy1QuFuTt21QVz/zH4PG5mqIvAtksQskKONG7IFgxN54u3X6zZiDkKRlNifhYGo9omV8YqHjcMB64GQiZ2pC35B1pVO/9ZWcLAptmC0HlttwAjpek8xLXnGLbge9HjVIRJqugXKWUvo3RfP92QxilHdHviWmRC/BWKQyWb0BoRbdneL08unZuYdP/sO1Ar/pO0zCKfRA2Vfl5rjfTUV0Y2LQO9BtQOzGn9ko6vPG0th2gQkyWwrDBLKelpXq84GR9LPh3JY2IyUlGb4W37QAEjpZCw9RRZiU8ETw/ULEX+PMYgbxTQ/z5iWgT4Ww5UDv8kS4QmoFa179y/V9mCgSVm5J1wQxIfEhS6DrpYUaJWU4oQ/LY2kYbOWsf81wmXNFS7S35DAE1wegjNmQuk6xE+eGMKS0GARGauNiagWuRixcgFqNDswVZHJNBMwHLvq12Sqw6is2N/gp6PgVaUxJbDniDQQ3SjsMHR03R3hE3jWicTRWWE181l7LATPOJweNkljkAtdFFRTSUzOiSwWyFUFQopRsRJv0EozPR31UQ3HENrawpFUVVZyDEGbbiHbmB8luhmBLzbUS2ZkDyK5TIQyyMOj1UVOKRsFRLTfFjOTB+oaSngq1Mlc+MzrYDeZXlNVhkH0GoQhldf2LouJ5mCuJhRwZO7qgTth5wuZNtcQfKvo2nSadv2wGp5Co/uxAhsAufvZiuVoaK/GMSKUdedL8ro/EXbLDDQFcTEXR6IvpUcPbXAKTLxVzz4ITxXI2UYkGPpYzsRAK3HTOzVjBWySP8oqqKzkSng4B/EixT0MpBO6Iw6i+oLL+cipGJaJo1A1Jw/oENV935GY8SQRHTVC7ih3EAfcF0/YhKxSXk/7/D6K8Bn4oaweb7odaODZchiH6zS7NmwNAey4WW4oRerUUcT3BBfHCiEGlCdxh8BSv1FBzcKphSWhjYWGvwtUTbIg4YhvT6dVsdvj+PVQNsu42mEknO4maHkG3rWoixzYEWGkjbYtpmwPbQtRBji8xA7IKTtklVQyZ2TcQk7wOJ8BLXrG20utg3E/v8e2GNZOK7HtnpV/LpBKfxQRxq9/1bOa8E/uFQccksKugSwrV7QHsddGsLAhV4FEu/2Hbg+HBfD6KRNciFprnzMtaFQte7KA4lekEJM8cYVWtkyPJkuv0TJayfrmt1zgiL1AybkMcjkVXY46fku9t/U3080pWpek76pt/ksO2AqvN7CWGCMrYjdhJfgkhZiXFPPlHs785wrW1iyuX+gbLo3Rmj3x/vSXqT4vwuxncRLLLaKrbXgLtycxAaD4oI31XtKXkeSV30NTuZFQV7i38DzTEn13bLUKr2jJVXUdvFtgNYXaJDODwSr2urkPPMRUZ65qSnZH4ySyhZzGUyhwv1GqyDVwl11YY8/heT8VnhbTsgBcr3fndw0wp3oKIf1sLr2DWWyT8mrJQZ8H67y/7GO+oyd8DbFxvNW3iBWZFsRzJ449tmOWAIk7ORwalM4qguuNuAJ2vlbAjeIPlURyScl4zeDG97EWOBDmSCv4zwOUy4CN+g4insLFWkju8zU2TATg7xPYB0ew7h9DAuQLgfiKeBO3SVnj9k0KTT2nZA1ZQ/hcpPCkJHIAScMOTHsOJc2T+0vskwALeuy4KLpZl6pMGAORSttinsOA2eh+CwA/w71Cax0ns4+lRjkKXcWp50OGCwzgjBAWNJk7IWm4TY3Y5ghgdwRRnYZ8/Go2ZiWmQNmAluLViiEJKHUrfqIr8v0k7sby2DDD0sTLNxFY2mI/JxwIDHt4kc+BLE83DYlqtaPFsr9GOP2zi1t/YNWr9eWDrQ2JCx0OW6cR0xOAkJW+dWMPlOFfhnFrp3Uk157U5EW+//NQL/AAyTY89Wss/pAAAAAElFTkSuQmCC" x="52" y="578" width="40" height="40"/>
  <text x="72" y="626" text-anchor="middle" font-size="9" fill="#555">AWS STS</text>

  <!-- ═══════════════ RIGHT — AFTER ═══════════════ -->

  <!-- Management Account Box (after) -->
  <rect x="580" y="78" width="410" height="88" rx="6" fill="#fff" stroke="#2563eb" stroke-width="1.8"/>
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAIAAAADnC86AAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAKKADAAQAAAABAAAAKAAAAAB65masAAAEgElEQVRYCWNU0bdjGAjANBCWguwctZhuIT8a1KNBTbMQGE1ckKBVlJftaq46sH3V1VN7DmxbWZybyszMrKGmsnTuRHMTA4gaHw9nINdATwvC9XB1AHL5+fmkJMSn9DSdObj58slda5fMsDI3xhpdLFhFDfV1/v//N2navC9fv9pamWUkx7x7/3H1+q1G+jr+3m4nz1wA6gr29zQzNvB0dbxw6RqQGx7kA7Ty48dPi2b2CQsJdvRP//Tps6a6qqiIMFYrsFu8btN2IIJo2LXvsK21uZW50fwlq06cPg/xATMTE9ARZ85fNjHSAypjZWU1NtRdvnoTkKGuqgR04poN24DiQL1YbQUKYrcYKAF0tbGBDg8Pz4uXr4BuFxTgBwru2X+koapQRlpSSICfjY115rylMya0cnFx6mqpc3Jw7Np76Pfv3wcOnwgN9Aa6YOvOfcdPnfvz5w9Wu7Fb7Opo29tW8+79h7v3Hwnw86ooyV+/eQdk8YEj9ZUFQE/zcHNdvnbz+Kmz//79A3rd1Fj/9Zt35y9dBaopqW7NSo3183IFxsXrN2/L6zoOHzuFaTcj1obAkV1rf/365eoX/fffP6CeDctn//37NzgmA8het2zWw4dPODjZ79572DNp1vJ5k0+dvWBlbnL95u261j64BYyMjMBk2NFY8ePnT4/AOLg4nIElHzMxMQkJ8j9++hxiq4qSgqqyIi8vD0TPnn2HLcyMTA31Tp+7CBQB2upoZ6WrowGPTmAUAMX///8PTBDAoBYXEwE6Am4fnIElqIGht+/gMVcn25kT2799+26or33m/CVg8MrJSj16/AwY2oU5KUA3AVMW0BRgCs9Kjfv0+QvQGiBXWVF+zZLpQPtev36nrCRvaqQ3Y+4SoCPg9sEZ2IOag509OjwA6NG79x9u3Lr758+fQIu37z4A0QZMO9+//9iyYy+QC8zf0WH+Dx8/PXjkJETW2sLEztpcQlwUmLX2HTp+4PBxiDgaid1iNEW04GIJampZAyxPtDRUOTk5bt99cOMWKFMgAywWG+ppX7h8DWvEIOvEzw7wcXOytwZma011FRkpST1LdzT1zEIS8mhCpkb6DVVF3759u/fgEdnW37h1F5gmgEXK/YePjQx0lqxcj2YLFotv3bl39vyl2vK8xJhQPj7et+/ev//wEU0bQa6sjFRsRFBeRuKvX78fPHwMSfPIunAmLmB2TImLSIoNA1Y4N2/fO3zs5JVrt65evwVMwLiCQUxUREdLDVhzWJgaamuq7T90rLV7SllBRk1zD6bTcVoMcR2wHI4JD0yOCxcSFICIAOurV6/efvz8+SMw8375ysbGBiw+gSW5vKw0UDFQDbCMO3T05KLl644cPw0sOhQVZO/dfwTRi0wSsBiilIWFBVgg21mbATOohpoy1pIIWFZfvHLt5OkLW3bsefP2PbIdWNlEWYysE5g9REWERISERESEuLk4P3z8/OHDxxevXj9/8QpZGUE2yRYTNJFIBVgqCSJ1Uqhs1GIKA5B47aNBTXxYUahy5AU1AD0k0AuulD18AAAAAElFTkSuQmCC" x="592" y="86" width="32" height="32"/>
  <text x="785" y="118" text-anchor="middle" font-size="13" font-weight="600" fill="#1a1a2e">Management Account</text>
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAIAAABvFaqvAAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAGKADAAQAAAABAAAAGAAAAADiNXWtAAABj0lEQVQ4EWO8a+LDQA3ARA1DQGYMY4NY0MKIy9ZMMDWSVV7m9/1H72cu+3b8LJoCXFyUMAKaIlKa/m7ygkeece9mLhWpyeE0N8ClE00cxSCgW143T/p++uK/b9+/Hz/3pn2aYEokmgZcXBSDgD76efUmXOnPq7dYFWTgXPwMlDD6/fAxu57m9xPnIXo49DR+P3gCZAvlJjAyoVj59/OXD/NWIRuNIg0MXdHqXC4bU2ZBfm57c+GyjPezlgFV/337/g8qEkqPYWRBcQQjWhbhtDQSTAzlMNT5fubSh3krv5++hGwtnK14fP0D29D/f/7ARVBMBYoCw/jHqYsKR9c+z6yGKyKGgeI1YjTgUoPuIjR1kGB+O3mBUHYcMLyBDIZ//9DUQLgEDAIGMwMovv7DGVhNAQqiGwRyAlJ0MAsLAh0inJsI0Q9nMDIxo5mIbhDQZmSDYA5B08Xwum0ycpQBpdGjHyTEzAyMtfsWAei68fKxxNr////eTZqPVxcWSSwuwqKKCCEsLiJCFxYlg88gAKsxj+QB87dCAAAAAElFTkSuQmCC" x="594" y="122" width="24" height="24"/>
  <text x="606" y="158" text-anchor="middle" font-size="9" fill="#555">IAM</text>

  <!-- Security Account Box (after) -->
  <rect x="580" y="192" width="410" height="175" rx="6" fill="#fff" stroke="#2563eb" stroke-width="1.8"/>
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAIAAAADnC86AAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAKKADAAQAAAABAAAAKAAAAAB65masAAAEgElEQVRYCWNU0bdjGAjANBCWguwctZhuIT8a1KNBTbMQGE1ckKBVlJftaq46sH3V1VN7DmxbWZybyszMrKGmsnTuRHMTA4gaHw9nINdATwvC9XB1AHL5+fmkJMSn9DSdObj58slda5fMsDI3xhpdLFhFDfV1/v//N2navC9fv9pamWUkx7x7/3H1+q1G+jr+3m4nz1wA6gr29zQzNvB0dbxw6RqQGx7kA7Ty48dPi2b2CQsJdvRP//Tps6a6qqiIMFYrsFu8btN2IIJo2LXvsK21uZW50fwlq06cPg/xATMTE9ARZ85fNjHSAypjZWU1NtRdvnoTkKGuqgR04poN24DiQL1YbQUKYrcYKAF0tbGBDg8Pz4uXr4BuFxTgBwru2X+koapQRlpSSICfjY115rylMya0cnFx6mqpc3Jw7Np76Pfv3wcOnwgN9Aa6YOvOfcdPnfvz5w9Wu7Fb7Opo29tW8+79h7v3Hwnw86ooyV+/eQdk8YEj9ZUFQE/zcHNdvnbz+Kmz//79A3rd1Fj/9Zt35y9dBaopqW7NSo3183IFxsXrN2/L6zoOHzuFaTcj1obAkV1rf/365eoX/fffP6CeDctn//37NzgmA8het2zWw4dPODjZ79572DNp1vJ5k0+dvWBlbnL95u261j64BYyMjMBk2NFY8ePnT4/AOLg4nIElHzMxMQkJ8j9++hxiq4qSgqqyIi8vD0TPnn2HLcyMTA31Tp+7CBQB2upoZ6WrowGPTmAUAMX///8PTBDAoBYXEwE6Am4fnIElqIGht+/gMVcn25kT2799+26or33m/CVg8MrJSj16/AwY2oU5KUA3AVMW0BRgCs9Kjfv0+QvQGiBXWVF+zZLpQPtev36nrCRvaqQ3Y+4SoCPg9sEZ2IOag509OjwA6NG79x9u3Lr758+fQIu37z4A0QZMO9+//9iyYy+QC8zf0WH+Dx8/PXjkJETW2sLEztpcQlwUmLX2HTp+4PBxiDgaid1iNEW04GIJampZAyxPtDRUOTk5bt99cOMWKFMgAywWG+ppX7h8DWvEIOvEzw7wcXOytwZma011FRkpST1LdzT1zEIS8mhCpkb6DVVF3759u/fgEdnW37h1F5gmgEXK/YePjQx0lqxcj2YLFotv3bl39vyl2vK8xJhQPj7et+/ev//wEU0bQa6sjFRsRFBeRuKvX78fPHwMSfPIunAmLmB2TImLSIoNA1Y4N2/fO3zs5JVrt65evwVMwLiCQUxUREdLDVhzWJgaamuq7T90rLV7SllBRk1zD6bTcVoMcR2wHI4JD0yOCxcSFICIAOurV6/efvz8+SMw8375ysbGBiw+gSW5vKw0UDFQDbCMO3T05KLl644cPw0sOhQVZO/dfwTRi0wSsBiilIWFBVgg21mbATOohpoy1pIIWFZfvHLt5OkLW3bsefP2PbIdWNlEWYysE5g9REWERISERESEuLk4P3z8/OHDxxevXj9/8QpZGUE2yRYTNJFIBVgqCSJ1Uqhs1GIKA5B47aNBTXxYUahy5AU1AD0k0AuulD18AAAAAElFTkSuQmCC" x="592" y="200" width="32" height="32"/>
  <text x="785" y="230" text-anchor="middle" font-size="13" font-weight="600" fill="#1a1a2e">Security Account</text>

  <!-- Security User (after) -->
  <image href="data:image/png;base64,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" x="600" y="248" width="48" height="48"/>
  <text x="624" y="308" text-anchor="middle" font-size="9" fill="#333">Security User</text>
  <text x="624" y="319" text-anchor="middle" font-size="9" fill="#333">(IR Team)</text>
  <!-- Permissions icon below Security User -->
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAMKADAAQAAAABAAAAMAAAAADbN2wMAAAEBElEQVRoBe2aTUwTQRTHZ7ZQoFIETh5MpKU1xgMKFJR4ABO/SGijRo5y0IMRPaiRo4HozcSExKhXT15IDIIL4lUvBNqAHCAptCRy8CJ4sClYOuN721Y3S7fMkv3gwCTLzL55O/P7v3nT7AeEHBRnI0D1pl86F/GWb7Fh6L8OR62en4X2TRj7K3GR/sbpj3G9eSS9jjz8Leh3Ah6xKuG4QLJkjPf2utBQrJQVM+ZtGHkiUdbsm5mYK+FnSVfy9NVaVrY9D4OfSCRSJ6FeKDaR7gqAsxJ5J+AR1Dc3+osQuoptKpE6rIuVUgKK+e9qi5/pPrqrk4kOpgpIhHqeS1nXfDwUaTaRseRQpglAeE7IACy410WZbatQahOXVK7uVMFnKGE3/DPyuLrfyrbwCsRbwy0roZ5BLcwO+Fl5TOtj5bmQgB9Nlw5JlE8AyBACF4CchkcOoRQ68u1zKh4K3wG1I5zwAQBXNORzPpc2Nke+EEShFUDn4Oz4B0ZIL2zSDILvB3jkEhagFYFClA3rUOSRB4shAXgBroSLsVN4+B2GRx6hPYCO6tIQkxfV5062Da+Ak7DF5t7TChQbCG3x9p4OidOHbGP7ZnB5ckvPz0y7aQIUeEamCOFe12FpGiBfmAmqN5YpKfQfnngJJe98fs+w3oRm24UFJLu6KhMtkSYtgBbe31DVR0dGslo/q86FBMQD3RXZVPUol9iXZEv4bAHGaXjkENoDgebq7cRq+if41zCJTwH4FbxYUnI+lzZ2Rx7nxyK0ApgSCIj5DdfUAPin/QAvLAAdtSLApGxYpyKPTFiEUijnmhMBrzj6kqvpBNp8DVVDdm7YAoe6NiQAL8wDP1EGmVEP5UxbaA84gyY264EAsThZ52VoBZZD4e6VtnC/FgefmcH++nvH5Xptn9XnwgLwjRsl/D3h/BU8E98vgCH8b7dbBvvdP5nytwW7XbWwgOD05BpAPgIwDs/DL1FEAR7e0XeCfY0zCfttLcICkKoxKr8B/HvQVESk3O6YCv58IDa2bCs9TGZIAMLlRJDHedDjUK9D5B2BRwbDAjBtOCWRvACs6iWJKTd3KpttTUMCtDkPifQUSP/tCduoVRMJC9DCY9pAOg2q94T610k1h6VNYQFbvNxNKakGmjXGs12FDave2Ixz3S8pVqkQFnBsQd4o2+QXs5R3BqOTK2ogFMEZbwtE5Wdqux1tQ3ejKAKg8NhRAjE5usNog0F4BWxg2dMU+itAIdKc1OGHjUC01fbPrEvt83WEZXyoinG6rqdOXwCH+x5Cb8OHjWgiNKt3vWV2N7zLxwK3LYuNPs8i0UHQFbCZ9jyo8KS5xMk1GMT2XxdgV/7VgPNsv9OPrUokD/7oROAv/pOIrL11Gm8AAAAASUVORK5CYII=" x="608" y="325" width="32" height="32"/>
  <text x="624" y="366" text-anchor="middle" font-size="8" fill="#555">Permissions</text>

  <!-- MFA badge -->
  <image href="data:image/png;base64,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" x="668" y="250" width="36" height="36"/>
  <text x="686" y="298" text-anchor="middle" font-size="8.5" fill="#c0392b" font-weight="bold">MFA enforced</text>

  <!-- User tag label -->
  <text x="800" y="272" text-anchor="middle" font-size="9" fill="#555">User tag: Role=IR</text>

  <!-- Production IR Role (after) -->
  <rect x="580" y="392" width="410" height="175" rx="6" fill="#fff" stroke="#2563eb" stroke-width="1.8"/>
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAIAAAADnC86AAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAKKADAAQAAAABAAAAKAAAAAB65masAAAEgElEQVRYCWNU0bdjGAjANBCWguwctZhuIT8a1KNBTbMQGE1ckKBVlJftaq46sH3V1VN7DmxbWZybyszMrKGmsnTuRHMTA4gaHw9nINdATwvC9XB1AHL5+fmkJMSn9DSdObj58slda5fMsDI3xhpdLFhFDfV1/v//N2navC9fv9pamWUkx7x7/3H1+q1G+jr+3m4nz1wA6gr29zQzNvB0dbxw6RqQGx7kA7Ty48dPi2b2CQsJdvRP//Tps6a6qqiIMFYrsFu8btN2IIJo2LXvsK21uZW50fwlq06cPg/xATMTE9ARZ85fNjHSAypjZWU1NtRdvnoTkKGuqgR04poN24DiQL1YbQUKYrcYKAF0tbGBDg8Pz4uXr4BuFxTgBwru2X+koapQRlpSSICfjY115rylMya0cnFx6mqpc3Jw7Np76Pfv3wcOnwgN9Aa6YOvOfcdPnfvz5w9Wu7Fb7Opo29tW8+79h7v3Hwnw86ooyV+/eQdk8YEj9ZUFQE/zcHNdvnbz+Kmz//79A3rd1Fj/9Zt35y9dBaopqW7NSo3183IFxsXrN2/L6zoOHzuFaTcj1obAkV1rf/365eoX/fffP6CeDctn//37NzgmA8het2zWw4dPODjZ79572DNp1vJ5k0+dvWBlbnL95u261j64BYyMjMBk2NFY8ePnT4/AOLg4nIElHzMxMQkJ8j9++hxiq4qSgqqyIi8vD0TPnn2HLcyMTA31Tp+7CBQB2upoZ6WrowGPTmAUAMX///8PTBDAoBYXEwE6Am4fnIElqIGht+/gMVcn25kT2799+26or33m/CVg8MrJSj16/AwY2oU5KUA3AVMW0BRgCs9Kjfv0+QvQGiBXWVF+zZLpQPtev36nrCRvaqQ3Y+4SoCPg9sEZ2IOag509OjwA6NG79x9u3Lr758+fQIu37z4A0QZMO9+//9iyYy+QC8zf0WH+Dx8/PXjkJETW2sLEztpcQlwUmLX2HTp+4PBxiDgaid1iNEW04GIJampZAyxPtDRUOTk5bt99cOMWKFMgAywWG+ppX7h8DWvEIOvEzw7wcXOytwZma011FRkpST1LdzT1zEIS8mhCpkb6DVVF3759u/fgEdnW37h1F5gmgEXK/YePjQx0lqxcj2YLFotv3bl39vyl2vK8xJhQPj7et+/ev//wEU0bQa6sjFRsRFBeRuKvX78fPHwMSfPIunAmLmB2TImLSIoNA1Y4N2/fO3zs5JVrt65evwVMwLiCQUxUREdLDVhzWJgaamuq7T90rLV7SllBRk1zD6bTcVoMcR2wHI4JD0yOCxcSFICIAOurV6/efvz8+SMw8375ysbGBiw+gSW5vKw0UDFQDbCMO3T05KLl644cPw0sOhQVZO/dfwTRi0wSsBiilIWFBVgg21mbATOohpoy1pIIWFZfvHLt5OkLW3bsefP2PbIdWNlEWYysE5g9REWERISERESEuLk4P3z8/OHDxxevXj9/8QpZGUE2yRYTNJFIBVgqCSJ1Uqhs1GIKA5B47aNBTXxYUahy5AU1AD0k0AuulD18AAAAAElFTkSuQmCC" x="592" y="400" width="32" height="32"/>
  <text x="785" y="430" text-anchor="middle" font-size="13" font-weight="600" fill="#1a1a2e">Production Account</text>

  <!-- Production IR Role icon -->
  <image href="data:image/png;base64,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" x="760" y="448" width="48" height="48"/>
  <text x="784" y="508" text-anchor="middle" font-size="9" fill="#333">Production IR Role</text>
  <!-- Permissions icon below prod IR role -->
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAMKADAAQAAAABAAAAMAAAAADbN2wMAAAEBElEQVRoBe2aTUwTQRTHZ7ZQoFIETh5MpKU1xgMKFJR4ABO/SGijRo5y0IMRPaiRo4HozcSExKhXT15IDIIL4lUvBNqAHCAptCRy8CJ4sClYOuN721Y3S7fMkv3gwCTLzL55O/P7v3nT7AeEHBRnI0D1pl86F/GWb7Fh6L8OR62en4X2TRj7K3GR/sbpj3G9eSS9jjz8Leh3Ah6xKuG4QLJkjPf2utBQrJQVM+ZtGHkiUdbsm5mYK+FnSVfy9NVaVrY9D4OfSCRSJ6FeKDaR7gqAsxJ5J+AR1Dc3+osQuoptKpE6rIuVUgKK+e9qi5/pPrqrk4kOpgpIhHqeS1nXfDwUaTaRseRQpglAeE7IACy410WZbatQahOXVK7uVMFnKGE3/DPyuLrfyrbwCsRbwy0roZ5BLcwO+Fl5TOtj5bmQgB9Nlw5JlE8AyBACF4CchkcOoRQ68u1zKh4K3wG1I5zwAQBXNORzPpc2Nke+EEShFUDn4Oz4B0ZIL2zSDILvB3jkEhagFYFClA3rUOSRB4shAXgBroSLsVN4+B2GRx6hPYCO6tIQkxfV5062Da+Ak7DF5t7TChQbCG3x9p4OidOHbGP7ZnB5ckvPz0y7aQIUeEamCOFe12FpGiBfmAmqN5YpKfQfnngJJe98fs+w3oRm24UFJLu6KhMtkSYtgBbe31DVR0dGslo/q86FBMQD3RXZVPUol9iXZEv4bAHGaXjkENoDgebq7cRq+if41zCJTwH4FbxYUnI+lzZ2Rx7nxyK0ApgSCIj5DdfUAPin/QAvLAAdtSLApGxYpyKPTFiEUijnmhMBrzj6kqvpBNp8DVVDdm7YAoe6NiQAL8wDP1EGmVEP5UxbaA84gyY264EAsThZ52VoBZZD4e6VtnC/FgefmcH++nvH5Xptn9XnwgLwjRsl/D3h/BU8E98vgCH8b7dbBvvdP5nytwW7XbWwgOD05BpAPgIwDs/DL1FEAR7e0XeCfY0zCfttLcICkKoxKr8B/HvQVESk3O6YCv58IDa2bCs9TGZIAMLlRJDHedDjUK9D5B2BRwbDAjBtOCWRvACs6iWJKTd3KpttTUMCtDkPifQUSP/tCduoVRMJC9DCY9pAOg2q94T610k1h6VNYQFbvNxNKakGmjXGs12FDave2Ixz3S8pVqkQFnBsQd4o2+QXs5R3BqOTK2ogFMEZbwtE5Wdqux1tQ3ejKAKg8NhRAjE5usNog0F4BWxg2dMU+itAIdKc1OGHjUC01fbPrEvt83WEZXyoinG6rqdOXwCH+x5Cb8OHjWgiNKt3vWV2N7zLxwK3LYuNPs8i0UHQFbCZ9jyo8KS5xMk1GMT2XxdgV/7VgPNsv9OPrUokD/7oROAv/pOIrL11Gm8AAAAASUVORK5CYII=" x="768" y="525" width="32" height="32"/>
  <text x="784" y="566" text-anchor="middle" font-size="8" fill="#555">Permissions</text>

  <!-- Arrow: Security User → Prod IR Role -->
  <path d="M640,297 L752,445" stroke="#27ae60" stroke-width="2" stroke-dasharray="6,3" fill="none" marker-end="url(#ag2)"/>

  <!-- Simplified access label -->
  <text x="670" y="385" text-anchor="middle" font-size="8.5" fill="#27ae60" font-weight="bold">Simplified access path</text>

  <!-- SSM visibility warning -->
  <rect x="588" y="578" width="185" height="34" rx="4" fill="#fff8e1" stroke="#f39c12" stroke-width="1.2"/>
  <text x="595" y="593" font-size="8.5" fill="#e67e22">⚠ SSM visibility issue</text>
  <text x="595" y="606" font-size="8.5" fill="#e67e22">   under investigation</text>

  <!-- Bottom labels -->
  <text x="255" y="644" text-anchor="middle" font-size="11" font-weight="bold" fill="#c0392b">Before (Role Chaining)</text>
  <text x="785" y="644" text-anchor="middle" font-size="11" font-weight="bold" fill="#27ae60">After (Simplified Access)</text>

</svg>



## Current state
 - Debugger access in Production: working and validated (including script execution)
 - IR role access and permissions: designed but partially tested
 - Cross-account assumption flow: validated
 -MFA-based CLI workflow: partially working (needs cleanup)
 -Session Manager visibility inconsistency: under investigation
