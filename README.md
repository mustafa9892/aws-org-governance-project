# AWS Multi-Account Governance Project

## Overview
This project demonstrates a multi-account AWS environment using 0 with governance enforced through 1.

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
- Denies EC2 and S3 operations outside `ap-south-1`  
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
- Attempted EC2 launches outside `ap-south-1` → Denied  
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
- Refine SCP strategy for production-grade governa
