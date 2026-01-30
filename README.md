# SSR Nuxt/Nitro PoC

Multi-region serverless SSR application using Nuxt 3, Nitro, and AWS Lambda with CloudFront origin failover.

## 🎯 Goals

- Demonstrate true server-side rendering (SSR) on AWS Lambda
- Achieve scale-to-zero (no idle costs)
- Implement multi-region resilience with automatic failover
- Avoid vendor lock-in (no Amplify)
- Learn cutting-edge serverless patterns

## 🏗️ Architecture

```
Route53 (Health Checks)
    │
    ▼
CloudFront Distribution
├── Origin Group (Failover)
│   ├── Primary: Lambda us-east-1
│   └── DR: Lambda us-west-2
├── S3: Static Assets (with CRR)
│
DynamoDB Global Tables (active-active)
```

### Features

- **Server Clock**: SSR-rendered timestamp proving server-side execution
- **Region Indicator**: Shows which AWS region served the request
- **Visit Counter**: Atomic increment in DynamoDB Global Tables
- **Weather Tile**: IP-based geolocation → Open-Meteo weather API
- **Failover Testing**: Manual health check and failover simulation

## 📁 Project Structure

```
ssr-nuxt-nitro-poc/
├── terraform/           # Infrastructure as Code
│   ├── main.tf
│   ├── lambda.tf
│   ├── dynamodb.tf
│   ├── s3.tf
│   ├── cloudfront.tf
│   ├── route53.tf
│   └── modules/
│       └── lambda/
├── app/                 # Nuxt 3 Application
│   ├── assets/
│   ├── components/
│   ├── layouts/
│   ├── pages/
│   ├── server/api/      # API Routes
│   ├── nuxt.config.ts
│   └── package.json
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- Node.js >= 18
- npm or yarn

### 1. Deploy Infrastructure

```bash
cd terraform

# Initialize
terraform init

# Plan
terraform plan

# Apply (creates S3 buckets, DynamoDB, Lambda roles)
terraform apply
```

### 2. Build and Deploy App

```bash
cd app

# Install dependencies
npm install

# Deploy (builds and uploads to S3)
./deploy.sh

# Or manually:
NITRO_PRESET=aws-lambda npm run build
cd .output/server && zip -r ../../lambda-deploy.zip .
aws s3 cp lambda-deploy.zip s3://YOUR_BUCKET/lambda/nitro-ssr.zip
```

### 3. Update Lambda

```bash
cd terraform
terraform apply
```

### 4. Access Application

```
https://ssr-poc.pitanga.org
```

## 🔧 Development

### Local Development

```bash
cd app
npm install
npm run dev
```

Local server runs at `http://localhost:3000`

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | SSR Dashboard |
| `/api/health` | GET | Health check for Route53 |
| `/api/dashboard` | GET | Server data (time, region, counter) |
| `/api/weather` | GET | Weather by IP geolocation |
| `/api/counter` | POST | Increment visit counter |

## 📊 Testing Failover

1. **Health Checks**: Monitor Route53 health check status in AWS Console
2. **Manual Test**: Click "Test Failover" button in the admin section
3. **Simulate Failure**: Temporarily disable primary Lambda or modify health endpoint
4. **Verify**: Check that traffic routes to DR region (response shows `us-west-2`)

## 🔍 Monitoring

### CloudWatch Metrics

- Lambda invocations, errors, duration
- DynamoDB consumed capacity
- CloudFront cache hit/miss ratio

### Logs

```bash
# Primary region
aws logs tail /aws/lambda/ssr-poc-primary --follow

# DR region
aws logs tail /aws/lambda/ssr-poc-dr --follow --region us-west-2
```

## 💰 Cost Estimate (Monthly)

| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 100K requests, 512MB, 200ms avg | ~$0.00 |
| DynamoDB | On-demand, light usage | ~$0.00 |
| CloudFront | 10GB transfer | ~$0.85 |
| Route53 | 1 hosted zone + health checks | ~$0.50 |
| S3 | < 1GB storage | ~$0.02 |
| **Total** | | **~$1.37** |

*With true scale-to-zero, costs approach $0 during idle periods*

## 📝 Learnings & Notes

### Cold Starts

- Nitro Lambda preset has ~200-500ms cold start with 512MB memory
- Consider Provisioned Concurrency for production if <1s response required

### DynamoDB Global Tables

- Eventually consistent across regions (replication ~1 second)
- Use for session data, counters, non-critical state
- For strong consistency, consider Aurora Global or single-region with failover

### CloudFront Origin Failover

- Failover triggers on: HTTP 5xx, 4xx (configurable), timeout
- Typically < 5 seconds to detect and route to DR
- Route53 failover can add DNS-level backup (30-60s propagation)

## 🚧 Future Enhancements

- [ ] WebSocket support for live clock ticks
- [ ] Cognito authentication for admin controls
- [ ] CloudWatch dashboard
- [ ] Load testing with Artillery or k6
- [ ] Compare with Lambda@Edge architecture
- [ ] Add OpenTelemetry tracing

## 📚 References

- [Nuxt 3 Documentation](https://nuxt.com/docs)
- [Nitro AWS Lambda Preset](https://nitro.unjs.io/deploy/providers/aws-lambda)
- [DynamoDB Global Tables](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GlobalTables.html)
- [CloudFront Origin Failover](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/high_availability_origin_failover.html)
- [Open-Meteo API](https://open-meteo.com/)

---

Built by Andre Pitanga as a learning exercise in serverless SSR architecture.
