#!/bin/bash

# ============================================================
# CloudFormation Orphaned Resource Cleanup Script
# Stack: cloudformation-iac-iam-automation
# ============================================================

set -e

STACK_PREFIX="cloudformation-iac-iam-automation"
EC2_GROUP="${STACK_PREFIX}-EC2-Users"
S3_GROUP="${STACK_PREFIX}-S3-Users"
EC2_USERS=("ec2-user1" "ec2-user2")
S3_USERS=("s3-user")

echo "============================================================"
echo " Starting Cleanup of Orphaned CloudFormation Resources"
echo "============================================================"

# ─────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────

delete_user() {
  local USERNAME=$1
  local GROUP=$2

  echo ""
  echo ">>> Processing user: $USERNAME"

  # Check if user exists
  if ! aws iam get-user --user-name "$USERNAME" &>/dev/null; then
    echo "    [SKIP] User $USERNAME does not exist."
    return
  fi

  # Detach inline policies
  echo "    Checking inline policies..."
  INLINE_POLICIES=$(aws iam list-user-policies --user-name "$USERNAME" --query "PolicyNames[]" --output text)
  for POLICY in $INLINE_POLICIES; do
    echo "    Deleting inline policy: $POLICY"
    aws iam delete-user-policy --user-name "$USERNAME" --policy-name "$POLICY"
  done

  # Detach managed policies
  echo "    Checking managed policies..."
  MANAGED_POLICIES=$(aws iam list-attached-user-policies --user-name "$USERNAME" --query "AttachedPolicies[].PolicyArn" --output text)
  for POLICY_ARN in $MANAGED_POLICIES; do
    echo "    Detaching managed policy: $POLICY_ARN"
    aws iam detach-user-policy --user-name "$USERNAME" --policy-arn "$POLICY_ARN"
  done

  # Remove from group
  echo "    Removing from group: $GROUP"
  aws iam remove-user-from-group --group-name "$GROUP" --user-name "$USERNAME" 2>/dev/null \
    && echo "    Removed from $GROUP" \
    || echo "    [SKIP] User was not in group $GROUP"

  # Delete login profile
  echo "    Deleting login profile..."
  aws iam delete-login-profile --user-name "$USERNAME" 2>/dev/null \
    && echo "    Login profile deleted" \
    || echo "    [SKIP] No login profile found"

  # Delete user
  echo "    Deleting user: $USERNAME"
  aws iam delete-user --user-name "$USERNAME"
  echo "    [DONE] User $USERNAME deleted."
}

delete_group() {
  local GROUP=$1

  echo ""
  echo ">>> Processing group: $GROUP"

  # Check if group exists
  if ! aws iam get-group --group-name "$GROUP" &>/dev/null; then
    echo "    [SKIP] Group $GROUP does not exist."
    return
  fi

  # Detach managed policies from group
  echo "    Checking attached policies..."
  ATTACHED_POLICIES=$(aws iam list-attached-group-policies --group-name "$GROUP" --query "AttachedPolicies[].PolicyArn" --output text)
  for POLICY_ARN in $ATTACHED_POLICIES; do
    echo "    Detaching policy: $POLICY_ARN"
    aws iam detach-group-policy --group-name "$GROUP" --policy-arn "$POLICY_ARN"
  done

  # Delete group
  echo "    Deleting group: $GROUP"
  aws iam delete-group --group-name "$GROUP"
  echo "    [DONE] Group $GROUP deleted."
}

delete_managed_policies() {
  echo ""
  echo ">>> Processing managed policies with prefix: $STACK_PREFIX"

  POLICY_ARNS=$(aws iam list-policies --scope Local \
    --query "Policies[?contains(PolicyName, '${STACK_PREFIX}')].Arn" \
    --output text)

  if [ -z "$POLICY_ARNS" ]; then
    echo "    [SKIP] No orphaned managed policies found."
    return
  fi

  for POLICY_ARN in $POLICY_ARNS; do
    echo "    Processing policy: $POLICY_ARN"

    # Detach from any groups
    GROUPS=$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" --query "PolicyGroups[].GroupName" --output text)
    for GROUP in $GROUPS; do
      echo "    Detaching from group: $GROUP"
      aws iam detach-group-policy --group-name "$GROUP" --policy-arn "$POLICY_ARN"
    done

    # Detach from any users
    USERS=$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" --query "PolicyUsers[].UserName" --output text)
    for USER in $USERS; do
      echo "    Detaching from user: $USER"
      aws iam detach-user-policy --user-name "$USER" --policy-arn "$POLICY_ARN"
    done

    # Detach from any roles
    ROLES=$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" --query "PolicyRoles[].RoleName" --output text)
    for ROLE in $ROLES; do
      echo "    Detaching from role: $ROLE"
      aws iam detach-role-policy --role-name "$ROLE" --policy-arn "$POLICY_ARN"
    done

    # Delete non-default policy versions first
    VERSIONS=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
      --query "Versions[?IsDefaultVersion==\`false\`].VersionId" --output text)
    for VERSION in $VERSIONS; do
      echo "    Deleting policy version: $VERSION"
      aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$VERSION"
    done

    # Delete the policy
    echo "    Deleting policy: $POLICY_ARN"
    aws iam delete-policy --policy-arn "$POLICY_ARN"
    echo "    [DONE] Policy deleted."
  done
}

delete_secrets() {
  echo ""
  echo ">>> Processing Secrets Manager secrets with prefix: $STACK_PREFIX"

  SECRET_ARNS=$(aws secretsmanager list-secrets \
    --query "SecretList[?contains(Name, '${STACK_PREFIX}')].ARN" \
    --output text)

  if [ -z "$SECRET_ARNS" ]; then
    echo "    [SKIP] No orphaned secrets found."
    return
  fi

  for SECRET_ARN in $SECRET_ARNS; do
    echo "    Deleting secret: $SECRET_ARN"
    aws secretsmanager delete-secret \
      --secret-id "$SECRET_ARN" \
      --force-delete-without-recovery
    echo "    [DONE] Secret deleted."
  done
}

# ─────────────────────────────────────────────
# RUN CLEANUP
# ─────────────────────────────────────────────

echo ""
echo "------------------------------------------------------------"
echo " Step 1: Deleting EC2 Users"
echo "------------------------------------------------------------"
for USER in "${EC2_USERS[@]}"; do
  delete_user "$USER" "$EC2_GROUP"
done

echo ""
echo "------------------------------------------------------------"
echo " Step 2: Deleting S3 Users"
echo "------------------------------------------------------------"
for USER in "${S3_USERS[@]}"; do
  delete_user "$USER" "$S3_GROUP"
done

echo ""
echo "------------------------------------------------------------"
echo " Step 3: Deleting Groups"
echo "------------------------------------------------------------"
delete_group "$EC2_GROUP"
delete_group "$S3_GROUP"

echo ""
echo "------------------------------------------------------------"
echo " Step 4: Deleting Managed Policies"
echo "------------------------------------------------------------"
delete_managed_policies

echo ""
echo "------------------------------------------------------------"
echo " Step 5: Deleting Secrets"
echo "------------------------------------------------------------"
delete_secrets

echo ""
echo "============================================================"
echo " Cleanup Complete! You can now retry the CloudFormation deployment."
echo "============================================================"