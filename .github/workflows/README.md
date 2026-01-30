# GitHub Actions Workflows

## Workflows Overview

### 1. CI (`ci.yml`)
**Triggers**: Push/PR to main branch
**Purpose**: Validate code quality before merging

| Job | Description |
|-----|-------------|
| `lint` | Type checking and dependency install |
| `build` | Build Lambda package and upload artifact |
| `terraform` | Validate Terraform configuration |

### 2. CD - Deploy App (`cd-app.yml`)
**Triggers**: Push to main (app changes) or manual dispatch
**Purpose**: Deploy application code to AWS Lambda

Steps:
1. Build Nuxt app with Lambda preset
2. Upload to S3 (both regions)
3. Update Lambda function code
4. Smoke test health endpoint

### 3. CD - Deploy Infrastructure (`cd-infra.yml`)
**Triggers**: Push to main (terraform changes) or manual dispatch
**Purpose**: Manage AWS infrastructure with Terraform

Actions:
- `plan` - Preview changes (default)
- `apply` - Deploy infrastructure
- `destroy` - Remove all infrastructure (⚠️ destructive)

### 4. PR Preview (`pr-preview.yml`)
**Triggers**: PR opened/updated with app changes
**Purpose**: Create preview deployment package for manual testing

## Required Secrets

Configure these in GitHub repo settings (Settings → Secrets and variables → Actions):

| Secret | Description | How to get |
|--------|-------------|------------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key | IAM User → Security credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key | IAM User → Security credentials |
| `AWS_ACCOUNT_ID` | Your AWS account ID | `aws sts get-caller-identity` |

### Setting up Secrets

```bash
# Using GitHub CLI
gh secret set AWS_ACCESS_KEY_ID --body "your-access-key"
gh secret set AWS_SECRET_ACCESS_KEY --body "your-secret-key"
gh secret set AWS_ACCOUNT_ID --body "123456789012"
```

## Environments

GitHub Environments provide deployment protection rules:

- **dev**: Auto-deploy on main branch merges
- **prod**: Requires manual approval (recommended)

## IAM Permissions Required

The AWS credentials need these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:UpdateFunctionCode",
        "lambda:GetFunction",
        "lambda:GetFunctionUrlConfig",
        "lambda:WaitForFunctionUpdated"
      ],
      "Resource": "arn:aws:lambda:*:*:function:ssr-poc-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::ssr-poc-lambda-deployments-*/*",
        "arn:aws:s3:::ssr-poc-preview-deployments/*"
      ]
    }
  ]
}
```

## Deployment Flow

```
Developer pushes to main
        │
        ▼
┌───────────────┐
│  CI Workflow  │ → Lint, Build, Validate
└───────┬───────┘
        │
        ▼
┌───────────────┐
│  CD-Infra     │ → Deploy/update infrastructure
└───────┬───────┘
        │
        ▼
┌───────────────┐
│  CD-App       │ → Build & deploy to Lambda
└───────┬───────┘
        │
        ▼
   Smoke Test
        │
        ▼
   🚀 Live!
```

## Manual Deployments

### Deploy Infrastructure Only

```bash
gh workflow run cd-infra.yml -f action=plan
gh workflow run cd-infra.yml -f action=apply
```

### Deploy App Only

```bash
gh workflow run cd-app.yml -f environment=dev
```

## Troubleshooting

### Workflow fails on Lambda update

Check that:
1. S3 buckets exist (`ssr-poc-lambda-deployments-*`)
2. Lambda functions exist (run terraform first)
3. IAM permissions are correct

### Terraform state lock

If a previous run failed and left a lock:

```bash
aws dynamodb delete-item \
  --table-name terraform-locks-ssr-poc \
  --key '{"LockID": {"S": "terraform-state-ssr-poc/infrastructure/terraform.tfstate-md5-hash"}}'
```

### Build fails

Check Node.js version compatibility:
- Nuxt 3 requires Node.js 18+
- GitHub Actions uses Node.js 20
