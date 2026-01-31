# GitHub Actions Workflows

## Deployment Strategy: Hybrid Mode

This project uses a **hybrid deployment strategy**:

| Component | Managed By | Trigger |
|-----------|-----------|---------|
| **Infrastructure** | Local Terraform → Terraform Cloud | Manual (`terraform apply`) |
| **Application Code** | GitHub Actions | Push to main (app/**) |

### Why Hybrid?

- **Infrastructure changes are rare** after initial setup
- **App deployments are frequent** (code updates)
- **Terraform Cloud** provides state management and locking
- **GitHub Actions** excels at continuous deployment

---

## Workflows

### 1. CI (`ci.yml`) ✅ Active
**Purpose**: Validate code quality before merging

| Trigger | Jobs |
|---------|------|
| Push/PR to main | `lint`, `build`, `terraform-validate` |

### 2. CD - Deploy App (`cd-app.yml`) ✅ Active
**Purpose**: Deploy application code to AWS Lambda

| Trigger | Action |
|---------|--------|
| Push to main (app/**) | Build & deploy to Lambda |
| Manual dispatch | Deploy to specific environment |

**Required Secrets**:
- `AWS_ACCESS_KEY_ID` - CI/CD user access key
- `AWS_SECRET_ACCESS_KEY` - CI/CD user secret key  
- `AWS_ACCOUNT_ID` - AWS account ID

**Note**: These must be set before app deployments work. See setup below.

### 3. CD - Deploy Infrastructure (`cd-infra.yml`) ⏸️ Disabled
**Purpose**: Manage AWS infrastructure with Terraform

**Status**: Disabled by default. Infrastructure managed locally via Terraform Cloud.

To enable:
1. Set AWS secrets in GitHub
2. Uncomment the `on:` section in the workflow file
3. Remove the `if: false` condition

### 4. PR Preview (`pr-preview.yml`) ⏸️ Requires Secrets
**Purpose**: Create preview deployments for PRs

**Status**: Requires AWS secrets to be configured first.

---

## Required Secrets

Configure these in GitHub: **Settings → Secrets and variables → Actions**

| Secret | How to Get It |
|--------|---------------|
| `AWS_ACCESS_KEY_ID` | From Terraform output: `cicd_access_key_id` |
| `AWS_SECRET_ACCESS_KEY` | From Secrets Manager (see below) |
| `AWS_ACCOUNT_ID` | `137064409667` (pitanga account) |

### Setting Up Secrets

1. **Retrieve CI/CD credentials** (from local Terraform deployment):
```bash
aws secretsmanager get-secret-value \
  --secret-id ssr-poc/cicd-credentials \
  --query SecretString --output text | jq -r '
  "AWS_ACCESS_KEY_ID: \(.AWS_ACCESS_KEY_ID)",
  "AWS_SECRET_ACCESS_KEY: \(.AWS_SECRET_ACCESS_KEY)",
  "AWS_ACCOUNT_ID: \(.AWS_ACCOUNT_ID)"
  '
```

2. **Set GitHub secrets**:
```bash
gh secret set AWS_ACCESS_KEY_ID --body "<key>" --repo apitanga/ssr-nuxt-nitro-poc
gh secret set AWS_SECRET_ACCESS_KEY --body "<secret>" --repo apitanga/ssr-nuxt-nitro-poc
gh secret set AWS_ACCOUNT_ID --body "137064409667" --repo apitanga/ssr-nuxt-nitro-poc
```

Or via GitHub web UI: https://github.com/apitanga/ssr-nuxt-nitro-poc/settings/secrets/actions

---

## Deployment Flow

### App Deployment (GitHub Actions)
```
Developer pushes code → GitHub Actions:
  1. Checkout code
  2. npm install
  3. Build with NITRO_PRESET=aws-lambda
  4. Create deployment package
  5. Upload to S3 (both regions)
  6. Update Lambda function code
  7. Smoke test
```

### Infrastructure Changes (Local)
```
Developer changes Terraform → Local:
  1. cd terraform
  2. terraform plan
  3. terraform apply
  4. Changes reflected in Terraform Cloud
```

---

## Current Infrastructure Status

All infrastructure has been deployed:
- ✅ Lambda functions (us-east-1, us-west-2)
- ✅ DynamoDB Global Table
- ✅ S3 buckets with replication
- ✅ CloudFront distribution
- ✅ CI/CD IAM user with credentials in Secrets Manager

**CloudFront URL**: https://d2co4qzae21ivh.cloudfront.net

---

## Switching to Full GitHub Actions

To enable infrastructure deployment via GitHub Actions:

1. Set the AWS secrets (above)
2. Edit `.github/workflows/cd-infra.yml`:
   - Uncomment the `on:` trigger section
   - Comment out `on: workflow_dispatch: {}`
3. Commit and push

Or use OIDC federation (more secure, no long-term keys):
- See `terraform/iam-oidc.tf` for setup
- Update workflows to use `role-to-assume` instead of access keys

---

## Troubleshooting

### Workflow fails with "No credentials found"
Secrets aren't set. Follow "Setting Up Secrets" above.

### Lambda update fails
Check that `lambda-deploy.zip` exists in S3:
```bash
aws s3 ls s3://ssr-poc-lambda-deployments-137064409667-us-east-1/lambda/
```

### Terraform lock issues
If a Terraform Cloud run is stuck, check:
https://app.terraform.io/app/Pitangaville/workspaces/ssr-nuxt-nitro-poc/runs
