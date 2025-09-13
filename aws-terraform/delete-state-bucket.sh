#!/bin/bash

# Delete script for S3 state bucket and DynamoDB table
# This script removes the AWS resources used for Terraform remote state

# Copyright 2025, Fred Lackey (https://fredlackey.com)

set -e

# Initialize variables
PROFILE=""
REGION=""
BUCKET_NAME=""
DYNAMODB_TABLE=""

# Function to display usage
usage() {
    cat << EOF
Usage: $0 -p|--profile PROFILE -r|--region REGION -n|--name BUCKET_NAME

Deletes AWS resources used for Terraform remote state backend.

Required arguments:
  -p, --profile PROFILE    AWS profile to use
  -r, --region REGION      AWS region where resources exist
  -n, --name BUCKET_NAME   S3 bucket name to delete (DynamoDB table BUCKET_NAME-locks will also be deleted)

Example:
  $0 --profile my-profile --region us-west-2 --name my-terraform-state

WARNING: This will permanently delete your S3 bucket and DynamoDB table!

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--profile)
            PROFILE="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -n|--name)
            BUCKET_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$PROFILE" || -z "$REGION" || -z "$BUCKET_NAME" ]]; then
    echo "Error: All arguments are required."
    echo ""
    usage
    exit 1
fi

# Set derived values
DYNAMODB_TABLE="${BUCKET_NAME}-locks"

echo "Using AWS profile: $PROFILE"
echo "Using region: $REGION"
echo "Bucket name: $BUCKET_NAME"
echo "DynamoDB table name: $DYNAMODB_TABLE"

# Set AWS profile for all AWS CLI commands
export AWS_PROFILE="$PROFILE"

# Function to check if SSO session is valid
check_sso_session() {
    echo "Checking AWS SSO session..."
    
    # Try to get caller identity to test if credentials are valid
    if aws sts get-caller-identity --output text --query 'Account' --no-cli-pager >/dev/null 2>&1; then
        echo "✅ AWS credentials are valid"
        return 0
    else
        echo "❌ AWS credentials are not valid or expired"
        return 1
    fi
}

# Function to initiate SSO login
sso_login() {                       
    echo "Initiating AWS SSO login for profile: $PROFILE"
    aws sso login --profile "$PROFILE" --no-cli-pager
    
    # Verify login was successful
    if check_sso_session; then
        echo "✅ SSO login successful"
    else
        echo "❌ SSO login failed or credentials still invalid"
        exit 1
    fi
}

# Check SSO session and login if needed
if ! check_sso_session; then
    echo "SSO session is not active or expired. Initiating login..."
    sso_login
fi

# Safety confirmation
echo ""
echo "⚠️  WARNING: This will permanently delete the following resources:"
echo "   - S3 Bucket: $BUCKET_NAME (including ALL contents)"
echo "   - DynamoDB Table: $DYNAMODB_TABLE"
echo ""
read -p "Are you sure you want to proceed? Type 'DELETE' to confirm: " confirmation

if [[ "$confirmation" != "DELETE" ]]; then
    echo "❌ Deletion cancelled."
    exit 0
fi

echo ""
echo "🗑️  Deleting AWS resources for Terraform state backend..."

# Delete S3 bucket (including all contents)
if aws s3 ls "s3://$BUCKET_NAME" --no-cli-pager >/dev/null 2>&1; then
    echo "Deleting S3 bucket contents and bucket: $BUCKET_NAME"
    
    # Remove all objects and versions
    aws s3 rm "s3://$BUCKET_NAME" --recursive --no-cli-pager
    
    # Remove all object versions (for versioned buckets)
    aws s3api delete-objects --bucket "$BUCKET_NAME" \
        --delete "$(aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --output json \
        --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" \
        --no-cli-pager 2>/dev/null || true
    
    # Remove all delete markers (for versioned buckets)
    aws s3api delete-objects --bucket "$BUCKET_NAME" \
        --delete "$(aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --output json \
        --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" \
        --no-cli-pager 2>/dev/null || true
    
    # Delete the bucket
    aws s3 rb "s3://$BUCKET_NAME" --no-cli-pager
    
    echo "✅ S3 bucket deleted: $BUCKET_NAME"
else
    echo "ℹ️  S3 bucket does not exist: $BUCKET_NAME"
fi

# Delete DynamoDB table
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" --no-cli-pager >/dev/null 2>&1; then
    echo "Deleting DynamoDB table: $DYNAMODB_TABLE"
    
    aws dynamodb delete-table \
        --table-name "$DYNAMODB_TABLE" \
        --region "$REGION" \
        --no-cli-pager
    
    echo "Waiting for DynamoDB table to be deleted..."
    aws dynamodb wait table-not-exists --table-name "$DYNAMODB_TABLE" --region "$REGION" --no-cli-pager
    
    echo "✅ DynamoDB table deleted: $DYNAMODB_TABLE"
else
    echo "ℹ️  DynamoDB table does not exist: $DYNAMODB_TABLE"
fi

echo ""
echo "✅ AWS backend resources deleted successfully!"
echo ""
echo "Deletion summary:"
echo "  AWS Profile: $PROFILE"
echo "  S3 Bucket: $BUCKET_NAME (deleted)"
echo "  DynamoDB Table: $DYNAMODB_TABLE (deleted)"
echo "  Region: $REGION"
echo ""
echo "Note: If you had any Terraform state files, they have been permanently deleted."
echo "Make sure to remove any backend configuration from your Terraform files."
