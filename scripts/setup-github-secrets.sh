#!/bin/bash
# Setup GitHub Secrets for CI/CD
# Usage: ./setup-github-secrets.sh

set -e

echo "🔐 Setting up GitHub Secrets for SSR Nuxt/Nitro PoC"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed"
    echo "Install from: https://cli.github.com/"
    exit 1
fi

# Check if logged in
if ! gh auth status &> /dev/null; then
    echo "❌ Not logged into GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

# Check AWS credentials
echo "☁️ Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured"
    echo "Run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IDENTITY=$(aws sts get-caller-identity --query Arn --output text)

echo "✅ AWS Account: $ACCOUNT_ID"
echo "✅ Identity: $IDENTITY"
echo ""

# Get AWS credentials
echo "📋 AWS Credential Configuration"
echo "--------------------------------"
echo "This script will configure GitHub secrets for AWS access."
echo ""
echo "You have two options:"
echo ""
echo "1. Use existing AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
echo "   (from ~/.aws/credentials)"
echo ""
echo "2. Create new IAM user/keys for GitHub Actions (recommended)"
echo ""
read -p "Enter option (1 or 2): " OPTION

if [ "$OPTION" = "1" ]; then
    # Try to get from environment or prompt
    if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "✅ Found credentials in environment variables"
        ACCESS_KEY="$AWS_ACCESS_KEY_ID"
        SECRET_KEY="$AWS_SECRET_ACCESS_KEY"
    else
        echo ""
        echo "Please enter your AWS credentials:"
        read -p "AWS Access Key ID: " ACCESS_KEY
        read -s -p "AWS Secret Access Key: " SECRET_KEY
        echo ""
    fi
elif [ "$OPTION" = "2" ]; then
    echo ""
    echo "📝 IAM Policy for GitHub Actions:"
    echo "--------------------------------"
    cat << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:UpdateFunctionCode",
        "lambda:GetFunction",
        "lambda:GetFunctionUrlConfig",
        "lambda:InvokeFunction"
      ],
      "Resource": "arn:aws:lambda:*:*:function:ssr-poc-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::ssr-poc-lambda-deployments-*",
        "arn:aws:s3:::ssr-poc-lambda-deployments-*/*",
        "arn:aws:s3:::ssr-poc-preview-deployments",
        "arn:aws:s3:::ssr-poc-preview-deployments/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/ssr-poc-*"
    }
  ]
}
EOF
    echo ""
    echo "Create a new IAM user with this policy, then enter the credentials:"
    read -p "AWS Access Key ID: " ACCESS_KEY
    read -s -p "AWS Secret Access Key: " SECRET_KEY
    echo ""
else
    echo "❌ Invalid option"
    exit 1
fi

# Validate credentials
echo ""
echo "🔍 Validating credentials..."
export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Invalid AWS credentials"
    exit 1
fi

echo "✅ Credentials validated"
echo ""

# Set secrets
echo "🔐 Setting GitHub Secrets..."
echo ""

cd "$(dirname "$0")/.."

REPO="apitanga/ssr-nuxt-nitro-poc"

echo "Repository: $REPO"
echo ""

# Set secrets
gh secret set AWS_ACCESS_KEY_ID --body "$ACCESS_KEY" --repo "$REPO"
echo "✅ Set AWS_ACCESS_KEY_ID"

gh secret set AWS_SECRET_ACCESS_KEY --body "$SECRET_KEY" --repo "$REPO"
echo "✅ Set AWS_SECRET_ACCESS_KEY"

gh secret set AWS_ACCOUNT_ID --body "$ACCOUNT_ID" --repo "$REPO"
echo "✅ Set AWS_ACCOUNT_ID"

echo ""
echo "🎉 All secrets configured!"
echo ""
echo "Next steps:"
echo "  1. Trigger CI: git push"
echo "  2. Deploy infrastructure: gh workflow run cd-infra.yml -f action=apply"
echo "  3. Deploy app: gh workflow run cd-app.yml"
echo ""
echo "View workflows: https://github.com/$REPO/actions"
