# IAM Resources Lab - Deployment Guide

## Prerequisites

1. AWS CLI configured with administrator credentials
2. Git repository initialized and connected to GitHub
3. AWS account with CloudFormation and IAM permissions

## Step 1: Enable GitSync for CloudFormation

### Option A: Using AWS Console

1. Go to **CloudFormation Console** → **Git repositories**
2. Click **Connect repository**
3. Select **GitHub** as provider
4. Authorize AWS CloudFormation to access your GitHub account
5. Select your repository: `cloudformation-iac`
6. Choose branch: `main` (or your default branch)
7. Configure file path: `security/automate_onetime_password_account_creation_permission.yml`

### Option B: Using AWS CLI

```bash
# First, create a connection to GitHub (one-time setup)
aws cloudformation create-connection \
  --connection-name github-cloudformation-iac \
  --provider-type GitHub

# Note the ConnectionArn from the output
# Complete the GitHub authorization in the console

# Deploy stack with GitSync
aws cloudformation create-stack \
  --stack-name iam-resources-lab \
  --template-body file://automate_onetime_password_account_creation_permission.yml \
  --parameters ParameterKey=EnvType,ParameterValue=dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --tags Key=GitSync,Value=Enabled
```

## Step 2: Deploy the CloudFormation Stack

```bash
aws cloudformation create-stack \
  --stack-name iam-resources-lab \
  --template-body file://automate_onetime_password_account_creation_permission.yml \
  --parameters ParameterKey=EnvType,ParameterValue=dev \
  --capabilities CAPABILITY_NAMED_IAM
```

## Step 3: Retrieve the One-Time Password

```bash
# Get the secret ARN from stack outputs
aws cloudformation describe-stacks \
  --stack-name iam-resources-lab \
  --query 'Stacks[0].Outputs[?OutputKey==`OneTimePasswordSecretArn`].OutputValue' \
  --output text

# Retrieve the password
aws secretsmanager get-secret-value \
  --secret-id iam-resources-lab-IAM-OneTimePassword \
  --query SecretString \
  --output text
```

## Step 4: Test IAM User Access

### Login URLs

- Console: `https://<ACCOUNT_ID>.signin.aws.amazon.com/console`
- Get Account ID: `aws sts get-caller-identity --query Account --output text`

### Test Matrix

| User      | S3 List  | EC2 List | EC2 Create |
| --------- | -------- | -------- | ---------- |
| ec2-user1 | ❌ Deny  | ✅ Allow | ✅ Allow   |
| ec2-user2 | ❌ Deny  | ✅ Allow | ❌ Deny    |
| s3-user   | ✅ Allow | ❌ Deny  | ❌ Deny    |

### Testing Steps

1. **Login as ec2-user1**
   - Navigate to S3 → Should see "Access Denied"
   - Navigate to EC2 → Should see instances
   - Try launching instance → Should succeed

2. **Login as ec2-user2**
   - Navigate to S3 → Should see "Access Denied"
   - Navigate to EC2 → Should see instances
   - Try launching instance → Should fail with explicit deny

3. **Login as s3-user**
   - Navigate to S3 → Should see bucket list
   - Navigate to EC2 → Should see "Access Denied"

## Step 5: Clean Up

```bash
aws cloudformation delete-stack --stack-name iam-resources-lab

# Delete the secret (after recovery window)
aws secretsmanager delete-secret \
  --secret-id iam-resources-lab-IAM-OneTimePassword \
  --force-delete-without-recovery
```

## GitSync Best Practices

1. **Branch Protection**: Enable branch protection on main branch
2. **Code Review**: Require pull request reviews before merging
3. **Automated Testing**: Use cfn-lint to validate templates
4. **Version Control**: Tag releases for production deployments
5. **Secrets Management**: Never commit passwords or credentials

## Troubleshooting

### Issue: Stack creation fails with "User already exists"

**Solution**: Delete existing users or use different usernames

### Issue: Cannot retrieve password from Secrets Manager

**Solution**: Ensure IAM permissions include `secretsmanager:GetSecretValue`

### Issue: GitSync connection pending

**Solution**: Complete GitHub authorization in AWS Console

## Security Notes

- Password is auto-generated with 16 characters
- Users must change password on first login
- Passwords stored securely in Secrets Manager
- Principle of least privilege applied to all policies
- ec2-user2 has explicit deny for RunInstances
