# Phase 3 EKS Infrastructure

## Prerequisites

- OpenTofu v1.11.3 (or compatible version)
  ```bash
  tofu --version
  # OpenTofu v1.11.3 on darwin_arm64
  ```

- AWS CLI v2.33.5 (or compatible version)
  ```bash
  aws --version
  # aws-cli/2.33.5 Python/3.13.11 Darwin/25.2.0 source/arm64
  ```

## Setup Instructions

To create infrastructure in the phase-3-eks folder, run the following commands:

```bash
export TF_VAR_iam_role_arn=<<role_used_for_cluster_access>>

tofu init

tofu plan

tofu apply

aws eks update-kubeconfig --profile=<<aws_account_profile>> --name eks-cluster
```

Replace the following placeholders:
- `<<role_used_for_cluster_access>>` - IAM role ARN used for cluster access
- `<<aws_account_profile>>` - Your AWS account profile name
