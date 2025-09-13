#!/bin/bash

# Verification script for S3 state bucket and DynamoDB table
# This script checks the existence and status of AWS resources used for Terraform remote state

# Copyright 2025, Fred Lackey (https://fredlackey.com)

set -e

# Initialize variables
PROFILE=""
REGION=""
BUCKET_NAME=""
DYNAMODB_TABLE=""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    cat << EOF
Usage: $0 -p|--profile PROFILE -r|--region REGION -n|--name BUCKET_NAME

Verifies the existence and status of AWS resources used for Terraform remote state backend.

Required arguments:
  -p, --profile PROFILE    AWS profile to use
  -r, --region REGION      AWS region where resources should exist
  -n, --name BUCKET_NAME   S3 bucket name to verify (DynamoDB table BUCKET_NAME-locks will also be checked)

Example:
  $0 --profile my-profile --region us-west-2 --name my-terraform-state

This script will check:
  - S3 bucket existence and configuration
  - DynamoDB table existence and status
  - Versioning status on the S3 bucket
  - Encryption status on the S3 bucket

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

echo "================================================"
echo "Terraform State Backend Verification"
echo "================================================"
echo ""
echo "Configuration:"
echo "  AWS Profile: $PROFILE"
echo "  Region: $REGION"
echo "  Bucket name: $BUCKET_NAME"
echo "  DynamoDB table: $DYNAMODB_TABLE"
echo ""
echo "================================================"
echo ""

# Set AWS profile for all AWS CLI commands
export AWS_PROFILE="$PROFILE"

# Function to check if SSO session is valid
check_sso_session() {
    echo "Checking AWS SSO session..."

    # Try to get caller identity to test if credentials are valid
    if aws sts get-caller-identity --output text --query 'Account' --no-cli-pager >/dev/null 2>&1; then
        echo -e "${GREEN}✅ AWS credentials are valid${NC}"
        return 0
    else
        echo -e "${RED}❌ AWS credentials are not valid or expired${NC}"
        return 1
    fi
}

# Function to initiate SSO login
sso_login() {
    echo "Initiating AWS SSO login for profile: $PROFILE"
    aws sso login --profile "$PROFILE" --no-cli-pager

    # Verify login was successful
    if check_sso_session; then
        echo -e "${GREEN}✅ SSO login successful${NC}"
    else
        echo -e "${RED}❌ SSO login failed or credentials still invalid${NC}"
        exit 1
    fi
}

# Check SSO session and login if needed
if ! check_sso_session; then
    echo "SSO session is not active or expired. Initiating login..."
    sso_login
fi

echo ""
echo "Verifying AWS resources..."
echo ""

# Initialize status variables
BUCKET_EXISTS=false
BUCKET_VERSIONING=false
BUCKET_ENCRYPTION=false
TABLE_EXISTS=false
TABLE_STATUS=""
OVERALL_STATUS=true

# Check S3 bucket
echo "1. S3 Bucket Status:"
echo "   ----------------"
if aws s3 ls "s3://$BUCKET_NAME" --no-cli-pager >/dev/null 2>&1; then
    BUCKET_EXISTS=true
    echo -e "   ${GREEN}✅ Bucket exists: $BUCKET_NAME${NC}"

    # Check bucket location
    BUCKET_REGION=$(aws s3api get-bucket-location --bucket "$BUCKET_NAME" --query 'LocationConstraint' --output text --no-cli-pager 2>/dev/null || echo "unknown")
    if [[ "$BUCKET_REGION" == "None" ]]; then
        BUCKET_REGION="us-east-1"
    fi
    echo "   📍 Location: $BUCKET_REGION"

    # Check versioning status
    VERSIONING_STATUS=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --query 'Status' --output text --no-cli-pager 2>/dev/null || echo "Not configured")
    if [[ "$VERSIONING_STATUS" == "Enabled" ]]; then
        BUCKET_VERSIONING=true
        echo -e "   ${GREEN}✅ Versioning: Enabled${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Versioning: $VERSIONING_STATUS (recommended: Enabled)${NC}"
    fi

    # Check encryption status
    if aws s3api get-bucket-encryption --bucket "$BUCKET_NAME" --no-cli-pager >/dev/null 2>&1; then
        BUCKET_ENCRYPTION=true
        echo -e "   ${GREEN}✅ Encryption: Enabled${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Encryption: Not configured (recommended: Enable encryption)${NC}"
    fi

    # Check if bucket has any objects (state files)
    OBJECT_COUNT=$(aws s3 ls "s3://$BUCKET_NAME" --recursive --summarize --no-cli-pager 2>/dev/null | grep "Total Objects:" | awk '{print $3}' || echo "0")
    if [[ -n "$OBJECT_COUNT" ]] && [[ "$OBJECT_COUNT" -gt 0 ]]; then
        echo -e "   ${BLUE}📦 Objects in bucket: $OBJECT_COUNT${NC}"
    else
        echo "   📦 Objects in bucket: 0 (empty)"
    fi

else
    echo -e "   ${RED}❌ Bucket does not exist: $BUCKET_NAME${NC}"
    OVERALL_STATUS=false
fi

echo ""
echo "2. DynamoDB Table Status:"
echo "   ---------------------"
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" --no-cli-pager >/dev/null 2>&1; then
    TABLE_EXISTS=true

    # Get table status
    TABLE_STATUS=$(aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" --query 'Table.TableStatus' --output text --no-cli-pager 2>/dev/null || echo "UNKNOWN")

    if [[ "$TABLE_STATUS" == "ACTIVE" ]]; then
        echo -e "   ${GREEN}✅ Table exists: $DYNAMODB_TABLE${NC}"
        echo -e "   ${GREEN}✅ Status: $TABLE_STATUS${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Table exists but status is: $TABLE_STATUS${NC}"
    fi

    # Get table details
    ITEM_COUNT=$(aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" --query 'Table.ItemCount' --output text --no-cli-pager 2>/dev/null || echo "0")
    TABLE_SIZE=$(aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" --query 'Table.TableSizeBytes' --output text --no-cli-pager 2>/dev/null || echo "0")

    echo "   📊 Item count: $ITEM_COUNT"
    echo "   💾 Table size: $TABLE_SIZE bytes"

    # Check billing mode
    BILLING_MODE=$(aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" --query 'Table.BillingModeSummary.BillingMode' --output text --no-cli-pager 2>/dev/null || echo "PROVISIONED")
    echo "   💳 Billing mode: $BILLING_MODE"
else
    echo -e "   ${RED}❌ Table does not exist: $DYNAMODB_TABLE${NC}"
    OVERALL_STATUS=false
fi

echo ""
echo "================================================"
echo "Verification Summary:"
echo "================================================"

if [[ "$BUCKET_EXISTS" == true ]] && [[ "$TABLE_EXISTS" == true ]] && [[ "$TABLE_STATUS" == "ACTIVE" ]]; then
    echo -e "${GREEN}✅ All resources exist and are properly configured!${NC}"
    echo ""
    echo "Your Terraform backend is ready to use with:"
    echo "  bucket         = \"$BUCKET_NAME\""
    echo "  key            = \"<your-state-file-path>/terraform.tfstate\""
    echo "  region         = \"$REGION\""
    echo "  dynamodb_table = \"$DYNAMODB_TABLE\""
    echo "  encrypt        = true"
    if [[ "$BUCKET_VERSIONING" == true ]]; then
        echo "  versioning     = true"
    fi
else
    echo -e "${RED}❌ Some resources are missing or misconfigured!${NC}"
    echo ""
    echo "Issues found:"
    if [[ "$BUCKET_EXISTS" != true ]]; then
        echo -e "  ${RED}• S3 bucket does not exist${NC}"
    fi
    if [[ "$TABLE_EXISTS" != true ]]; then
        echo -e "  ${RED}• DynamoDB table does not exist${NC}"
    elif [[ "$TABLE_STATUS" != "ACTIVE" ]]; then
        echo -e "  ${YELLOW}• DynamoDB table is not active (status: $TABLE_STATUS)${NC}"
    fi

    echo ""
    echo "To create missing resources, run:"
    echo "  ./setup-state-bucket.sh -p $PROFILE -r $REGION -n $BUCKET_NAME"
fi

echo ""
echo "================================================"