# SSR Nuxt/Nitro PoC - Troubleshooting Guide

**Last updated**: 2026-01-31

---

## Lambda Function URL 403 Forbidden Error

**Status**: Root cause identified, fix pending testing

### Problem

Lambda Function URL returns `403 AccessDeniedException` when accessed via HTTP, despite:
- AuthType set to NONE (public access)
- Resource policy with `lambda:InvokeFunctionUrl` permission
- Principal: "*"
- Direct Lambda invocation working perfectly

### Symptoms

```bash
$ curl https://<function-url>.lambda-url.us-east-1.on.aws/
# Returns: 403 Forbidden
# Headers: x-amzn-ErrorType: AccessDeniedException
```

**CloudWatch Logs**: No invocation logs from Function URL requests (blocked at service level)

**Direct Invocation**: Works perfectly via `aws lambda invoke`

### Root Cause

**Missing `lambda:InvokeFunction` permission in resource-based policy.**

According to [AWS re:Post](https://repost.aws/questions/QUS4tqgsJnSRSQWrCKkAd_sw/public-function-url-returning-a-403-forbidden):

> "If a function's resource-based policy doesn't grant **lambda:invokeFunctionUrl AND lambda:InvokeFunction** permissions, users will get a 403 Forbidden error"

AWS announced that starting November 1, 2026, Function URLs will require `lambda:InvokeFunction`. This requirement may already be enforced.

### Current vs. Required Configuration

**Current (Incorrect):**
```terraform
resource "aws_lambda_permission" "allow_function_url_primary" {
  statement_id           = "AllowFunctionURLInvoke"
  action                 = "lambda:InvokeFunctionUrl"  # Only this
  function_name          = module.lambda_primary.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
```

**Required (Fix):**
```terraform
resource "aws_lambda_permission" "allow_function_url_primary" {
  statement_id           = "AllowFunctionURLInvoke"
  action                 = "lambda:InvokeFunction"  # Use this instead
  function_name          = module.lambda_primary.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
```

**Note**: The action should be `lambda:InvokeFunction`, not `lambda:InvokeFunctionUrl`. The `function_url_auth_type` parameter ensures it applies to Function URL invocations.

### Testing the Fix

**1. Manual test (CLI):**
```bash
# Add permission
aws lambda add-permission \
  --function-name ssr-poc-primary \
  --statement-id AllowPublicInvoke \
  --action lambda:InvokeFunction \
  --principal "*" \
  --function-url-auth-type NONE \
  --region us-east-1

# Test Function URL
curl -I https://<function-url>.lambda-url.us-east-1.on.aws/
# Should return: 200 OK
```

**2. Verify in CloudWatch Logs:**
```bash
aws logs tail /aws/lambda/ssr-poc-primary --since 5m --region us-east-1
# Should show invocation logs from Function URL requests
```

**3. Test CloudFront:**
```bash
curl -I https://d2co4qzae21ivh.cloudfront.net
# Should return: 200 OK (after cache invalidation if needed)
```

### Terraform Update Required

Update both primary and DR regions in `terraform/lambda.tf`:

```terraform
# Primary Region
resource "aws_lambda_permission" "allow_function_url_primary" {
  provider               = aws.primary
  statement_id           = "AllowFunctionURLInvoke"
  action                 = "lambda:InvokeFunction"  # Changed
  function_name          = module.lambda_primary.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

# DR Region
resource "aws_lambda_permission" "allow_function_url_dr" {
  provider               = aws.dr
  statement_id           = "AllowFunctionURLInvoke"
  action                 = "lambda:InvokeFunction"  # Changed
  function_name          = module.lambda_dr.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
```

Then apply:
```bash
cd terraform
terraform apply
```

### Related Issues

- [Terraform AWS Provider Issue #38260](https://github.com/hashicorp/terraform-provider-aws/issues/38260) - FunctionURLAllowPublicAccess policy creation
- [Terraform AWS Provider Issue #44829](https://github.com/hashicorp/terraform-provider-aws/issues/44829) - Add `invoked_via_function_url` context key

### Research Sources

- [AWS re:Post - Public Function URL 403](https://repost.aws/questions/QUS4tqgsJnSRSQWrCKkAd_sw/public-function-url-returning-a-403-forbidden)
- [AWS Lambda - Control Access to Function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html)
- [Nitro AWS Lambda Documentation](https://nitro.build/deploy/providers/aws)
- [Deploy Nuxt 3 on AWS Lambda](https://medium.com/@michaelbouvy/deploy-nuxt-3-on-aws-lambda-a53991f0ad7e)

---

## Other Common Issues

### CloudFront Cache Serving Stale Errors

**Problem**: After fixing Lambda, CloudFront still returns cached errors

**Solution**:
```bash
# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id E2P9VW2SXMZVG0 \
  --paths "/*"
```

### Lambda Cold Start Times

**Observation**: First request after deployment shows ~2.6s duration (INIT + execution)

**Expected**: Normal for Nuxt/Nitro on Lambda, subsequent requests faster

**Monitoring**:
```bash
# Check recent invocation durations
aws logs tail /aws/lambda/ssr-poc-primary --since 1h --region us-east-1 | grep "REPORT"
```

---

## Debugging Checklist

When troubleshooting Lambda Function URL issues:

- [ ] Check CloudWatch Logs - are requests reaching Lambda?
- [ ] Test direct Lambda invocation - does the function work?
- [ ] Verify Function URL config - AuthType, CORS settings
- [ ] Check resource-based policy - both actions present?
- [ ] Test Function URL directly - bypass CloudFront
- [ ] Check for AWS Config rules blocking public access
- [ ] Verify Nitro preset in nuxt.config.ts
- [ ] Check deployed code - is it the latest build?

**Key diagnostic**: If CloudWatch shows no logs, request is blocked at AWS service level (permissions), not Lambda code issue.

---

## Lessons Learned

**Debugging Methodology:**
1. Don't "spray and pray" - step back and research
2. Check CloudWatch Logs to see WHERE failure occurs
3. Test direct invocation to isolate Lambda vs. infrastructure issues
4. Question assumptions (AuthType NONE ≠ no permissions needed)
5. Research systematically across multiple sources

**AWS Gotchas:**
- Function URL AuthType NONE still requires resource-based policy
- Policy needs BOTH actions for Function URLs (as of 2026)
- Terraform provider documentation may lag actual requirements
- Always check AWS re:Post for recent issues

---

**Session**: 2026-01-31 | Claude Code troubleshooting session
