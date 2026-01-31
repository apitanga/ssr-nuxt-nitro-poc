# SSR Nuxt/Nitro PoC - Agent Quickstart

## TL;DR

Multi-region serverless SSR using Nuxt 3 + Nitro on AWS Lambda. True scale-to-zero with CloudFront origin failover.

**Live URL**: https://d2co4qzae21ivh.cloudfront.net  
**GitHub**: https://github.com/apitanga/ssr-nuxt-nitro-poc  
**Status**: ✅ Deployed, ready for testing

---

## Architecture

```
CloudFront (Origin Group Failover)
├── Primary: Lambda@us-east-1
└── DR: Lambda@us-west-2
    
DynamoDB Global Tables (active-active)
S3 + CRR (static assets)
```

**Regions**: us-east-1 (primary), us-west-2 (DR)

---

## Quick Commands

```bash
# Local development
cd app && npm install && npm run dev

# Build for Lambda
cd app && NITRO_PRESET=aws-lambda npm run build

# Deploy locally (manual)
cd app && ./deploy.sh

# Terraform changes
cd terraform && terraform plan && terraform apply
```

---

## Project Structure

```
.
├── app/                    # Nuxt 3 application
│   ├── pages/index.vue    # Main dashboard
│   ├── server/api/        # API routes
│   └── nuxt.config.ts     # Nitro Lambda preset
├── terraform/             # Infrastructure
│   ├── main.tf           # TFC backend
│   ├── lambda.tf         # Lambda functions
│   ├── dynamodb.tf       # Global table
│   └── cloudfront.tf     # CDN with failover
└── .github/workflows/     # CI/CD
```

---

## Key Features

1. **Server Clock**: SSR timestamp proving server-side execution
2. **Region Indicator**: Shows which AWS region served request
3. **Visit Counter**: Atomic increment in DynamoDB Global Tables
4. **Weather Tile**: IP-based geolocation → weather API
5. **Failover Test**: Health check endpoint

---

## Deployment Strategy

**Hybrid Mode**:
- **Infrastructure**: Local Terraform → Terraform Cloud
- **App Code**: GitHub Actions (auto-deploy on push)

GitHub secrets configured: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ACCOUNT_ID`

---

## Current Status

### ✅ Completed
- [x] All AWS resources deployed (36 resources)
- [x] Lambda functions (primary + DR)
- [x] DynamoDB Global Table with replica
- [x] CloudFront distribution
- [x] CI/CD IAM user with credentials
- [x] GitHub secrets configured
- [x] GitHub Actions workflows

### ⏳ Next Steps
- [ ] Test app deployment via GitHub Actions
- [ ] Validate failover behavior
- [ ] Document findings

---

## Testing Failover

```bash
# Test health endpoint
PRIMARY_URL=$(aws lambda get-function-url-config \
  --function-name ssr-poc-primary \
  --query 'FunctionUrl' --output text)
curl $PRIMARY_URL/api/health

# Watch CloudWatch logs
aws logs tail /aws/lambda/ssr-poc-primary --follow
aws logs tail /aws/lambda/ssr-poc-dr --follow --region us-west-2
```

---

## Notes

- CI/CD user: `ssr-poc-cicd`
- Access key: `AKIAR72NM5JBSRBWZJL6` (in GitHub secrets)
- Terraform Cloud: `Pitangaville/ssr-nuxt-nitro-poc`

---

## Related

- **Vault notes**: `~/andre/Documents/Projects/ssr-nuxt-nitro-poc/`
- **Previous project**: Vue-AppSync (theme switcher issues led to this)
- **Learning goal**: True SSR vs static hosting
