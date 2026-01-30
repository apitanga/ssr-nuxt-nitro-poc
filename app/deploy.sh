#!/bin/bash
# Deploy script for SSR Nuxt/Nitro Lambda

set -e

echo "🚀 Building Nuxt app for AWS Lambda..."

# Clean previous build
rm -rf .output

# Build with Lambda preset
NITRO_PRESET=aws-lambda npm run build

# Check if build succeeded
if [ ! -d ".output/server" ]; then
  echo "❌ Build failed - .output/server not found"
  exit 1
fi

echo "✅ Build complete"

# Create deployment package
echo "📦 Creating deployment package..."
cd .output/server
zip -r ../../lambda-deploy.zip .
cd ../..

# Get file size
SIZE=$(du -h lambda-deploy.zip | cut -f1)
echo "📦 Package size: $SIZE"

# Upload to S3 (primary region)
echo "☁️ Uploading to S3..."
aws s3 cp lambda-deploy.zip s3://ssr-poc-lambda-deployments-$(aws sts get-caller-identity --query Account --output text)-us-east-1/lambda/nitro-ssr.zip

# Upload to S3 (DR region)
aws s3 cp lambda-deploy.zip s3://ssr-poc-lambda-deployments-$(aws sts get-caller-identity --query Account --output text)-us-west-2/lambda/nitro-ssr.zip

echo "✅ Deployment package uploaded to both regions"
echo ""
echo "Next steps:"
echo "  1. Run 'terraform apply' to update Lambda functions"
echo "  2. Test the deployment at the CloudFront URL"
