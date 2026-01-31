# SSR Nuxt/Nitro PoC

Multi-region serverless SSR application using Nuxt 3, Nitro, and AWS Lambda with CloudFront origin failover.

**Status**: ✅ **FULLY OPERATIONAL** - [Live Demo](https://d2co4qzae21ivh.cloudfront.net)

---

## 🎯 Goals Achieved

- ✅ Demonstrate true server-side rendering (SSR) on AWS Lambda
- ✅ Achieve scale-to-zero (no idle costs)
- ✅ Implement multi-region resilience with automatic failover
- ✅ Avoid vendor lock-in (no Amplify)
- ✅ Learn cutting-edge serverless patterns

---

## 🏗️ Architecture

```
Users
  │
  ▼
CloudFront Distribution
├── Origin Group (Failover)
│   ├── Primary: Lambda Function URL (us-east-1)
│   └── DR: Lambda Function URL (us-west-2)
│
├── S3: Static Assets (_nuxt/*, favicon.ico)
│
DynamoDB Global Tables (active-active)
```

### Live System

- **CloudFront**: https://d2co4qzae21ivh.cloudfront.net
- **Primary Region**: us-east-1 (N. Virginia)
- **DR Region**: us-west-2 (Oregon)

### Features

- **Server Clock**: SSR-rendered timestamp proving server-side execution
- **Region Indicator**: Shows which AWS region served the request
- **Visit Counter**: Atomic increment in DynamoDB Global Tables
- **Weather Tile**: IP-based geolocation → Open-Meteo weather API
- **Failover Testing**: Manual health check button

---

## 📁 Project Structure

```
ssr-nuxt-nitro-poc/
├── terraform/           # Infrastructure as Code (Terraform)
│   ├── main.tf
│   ├── lambda.tf        # Lambda functions + Function URLs
│   ├── dynamodb.tf      # Global Tables
│   ├── s3.tf            # Static assets bucket
│   ├── cloudfront.tf    # CDN with failover
│   └── modules/
│       └── lambda/
├── app/                 # Nuxt 3 Application
│   ├── pages/index.vue
│   ├── server/api/      # API Routes (health, weather, dashboard)
│   └── nuxt.config.ts
├── TROUBLESHOOTING.md   # Solutions to common issues
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured
- Terraform >= 1.5.0
- Node.js >= 18

### Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply
```

### Build and Deploy Application

```bash
cd app

# Clean build
rm -rf .output .nuxt
NITRO_PRESET=aws-lambda npm run build

# Package Lambda (Python zip - no native zip required)
python3 -c "
import zipfile, os
zf = zipfile.ZipFile('/tmp/lambda.zip', 'w', zipfile.ZIP_DEFLATED)
for root, dirs, files in os.walk('.output/server'):
    for f in files:
        filepath = os.path.join(root, f)
        arcname = os.path.relpath(filepath, '.output/server')
        zf.write(filepath, arcname)
zf.close()
print(f'Created: /tmp/lambda.zip ({os.path.getsize(\"/tmp/lambda.zip\")} bytes)')
"

# Deploy to Lambda (both regions)
aws lambda update-function-code \
  --function-name ssr-poc-primary \
  --zip-file fileb:///tmp/lambda.zip \
  --region us-east-1

aws lambda update-function-code \
  --function-name ssr-poc-dr \
  --zip-file fileb:///tmp/lambda.zip \
  --region us-west-2

# Sync static assets to S3
aws s3 sync .output/public/ \
  s3://ssr-poc-static-137064409667/ \
  --delete \
  --cache-control "public, max-age=31536000, immutable"

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id E2P9VW2SXMZVG0 \
  --paths "/*"
```

---

## 🔧 API Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | SSR Dashboard (server-side rendered) |
| `/api/health` | Health check (region, timestamp) |
| `/api/dashboard` | Server data (time, region, counter, latency) |
| `/api/weather` | Weather by IP geolocation |
| `/api/counter` | Increment visit counter (POST) |

---

## 🔍 Key Issues & Solutions

### 1. Lambda Function URL 403 Forbidden

**Problem**: Function URL returns 403 despite `authorization_type = "NONE"`

**Root Cause**: `aws_lambda_permission` resource using wrong action with incompatible parameter

**Solution**:
```hcl
resource "aws_lambda_permission" "allow_function_url" {
  statement_id  = "AllowFunctionURLInvoke"
  action        = "lambda:InvokeFunction"  # NOT InvokeFunctionUrl
  function_name = aws_lambda_function.my_function.function_name
  principal     = "*"
  # OMIT function_url_auth_type - incompatible with InvokeFunction
}
```

**File**: `terraform/lambda.tf` | **Commit**: `dc4e24a`

---

### 2. S3 Static Assets 403 Forbidden

**Problem**: CloudFront → S3 returns 403 for JS/CSS files

**Root Cause**: S3 bucket policy used OAC format, but CloudFront configured with OAI

**Solution**:
```hcl
resource "aws_s3_bucket_policy" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  policy = jsonencode({
    Statement = [{
      Sid    = "CloudFrontOAIAccess"
      Effect = "Allow"
      Principal = {
        # OAI uses CanonicalUser, NOT Service with SourceArn
        CanonicalUser = aws_cloudfront_origin_access_identity.main.s3_canonical_user_id
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.static_assets.arn}/*"
    }]
  })
}
```

**File**: `terraform/s3.tf` | **Commit**: `c8c1080`

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed debugging methodology.

---

## 📊 Testing Failover

1. **Manual Test**: Click "Test Failover" button in the admin section
2. **Verify**: Check that health check shows serving region and latency
3. **Simulate Failure**: (Advanced) Disable primary Lambda, verify CloudFront routes to DR

---

## 💰 Cost Estimate (Monthly)

| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 100K requests, 512MB, 200ms avg | ~$0.00 |
| DynamoDB | On-demand, light usage | ~$0.00 |
| CloudFront | 10GB transfer | ~$0.85 |
| S3 | < 1GB storage | ~$0.02 |
| **Total** | | **~$0.87** |

*With true scale-to-zero, costs approach $0 during idle periods*

---

## 📝 Key Learnings

### Lambda + Function URLs

- Function URLs with `AuthType NONE` still require resource-based policy
- Use `lambda:InvokeFunction` action (not `InvokeFunctionUrl`)
- Don't use `function_url_auth_type` with `InvokeFunction` action

### CloudFront + S3 (OAI)

- Origin Access Identity (OAI) uses `CanonicalUser` principal
- Origin Access Control (OAC) uses `Service` principal with `SourceArn` condition
- Terraform `aws_cloudfront_origin_access_identity.main.s3_canonical_user_id` provides the ID

### Deployment Pipeline

Every deployment requires:
1. Lambda code update (both regions)
2. S3 static asset sync
3. CloudFront invalidation
4. Wait 30-60 seconds for propagation

### Cold Starts

- Nitro Lambda preset: ~200-500ms cold start with 512MB memory
- Acceptable for SSR demo; consider Provisioned Concurrency for production

---

## 🚧 Future Enhancements (Optional)

- [ ] WebSocket support for live clock ticks
- [ ] Cognito authentication for admin controls
- [ ] CloudWatch dashboard
- [ ] Load testing with Artillery or k6
- [ ] DR failover automation testing

---

## 📚 References

- [Nuxt 3 Documentation](https://nuxt.com/docs)
- [Nitro AWS Lambda Preset](https://nitro.unjs.io/deploy/providers/aws-lambda)
- [DynamoDB Global Tables](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GlobalTables.html)
- [CloudFront Origin Failover](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/high_availability_origin_failover.html)
- [Open-Meteo API](https://open-meteo.com/)

---

Built by [Andre Pitanga](https://linkedin.com/in/apitanga) as a learning exercise in serverless SSR architecture.

**Status**: Complete and operational ✅
