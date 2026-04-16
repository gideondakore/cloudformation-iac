aws secretsmanager get-secret-value \
  --secret-id cloudformation-iac-iam-automation-IAM-OneTimePassword \
  --region eu-west-1 \
  --query "SecretString" \
  --output text
