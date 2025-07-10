#!/bin/bash

# ==============================================================================
# DEPLOY TO AWS CLOUDFRONT (WITH FULL AUTOMATION)
# ==============================================================================
#
# Description:
# This script automates the complete setup and deployment of the Vite static
# website to AWS. It is idempotent, meaning it can be run multiple times.
#
# On its first run, it will provision the necessary AWS resources:
#   - A private S3 bucket.
#   - A CloudFront Origin Access Control (OAC).
#   - A CloudFront distribution configured to serve files from the S3 bucket.
#
# On subsequent runs, it will find the existing resources, deploy the latest
# version of the application, and invalidate the CloudFront cache.
#
# NOTE ON UPGRADING FROM PREVIOUS SCRIPT VERSIONS:
# This script uses the modern S3 REST API endpoint with OAC. Older versions
# used the S3 website endpoint. If an old distribution is found, this script
# will halt and instruct you to delete it manually from the AWS Console to
# ensure a clean, secure setup.
#
# Prerequisites:
# - AWS CLI must be installed.
# - Node.js and npm must be installed.
#
# Usage:
# ./cloudfront-deploy-react.sh
#
# ==============================================================================

# --- Helper Function ---
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Main Function ---
main() {
    # --- Section 1: Configuration ---
    echo "🚀 Starting AWS Full Deployment Script"

    # Check for Vite config in the current directory. If not found, prompt for the path.
    if ! [ -f "vite.config.js" ] && ! [ -f "vite.config.ts" ]; then
        echo "🔎 Vite configuration not found in the current directory."
        read -p "Please enter the path to your Vite project: " VITE_PROJECT_PATH
        
        if [[ -z "${VITE_PROJECT_PATH}" ]]; then
            echo "❌ Project path cannot be empty. Aborting."
            exit 1
        fi

        if ! cd "${VITE_PROJECT_PATH}"; then
            echo "❌ Could not change to directory '${VITE_PROJECT_PATH}'. Aborting."
            exit 1
        fi

        if ! [ -f "vite.config.js" ] && ! [ -f "vite.config.ts" ]; then
            echo "❌ Vite configuration not found in '${VITE_PROJECT_PATH}'. Aborting."
            exit 1
        fi
        echo "✅ Located Vite project at: $(pwd)"
    else
        echo "✅ Found Vite configuration in current directory: $(pwd)"
    fi
    
    echo "This script will create or update AWS resources for a live deployment."
    echo "------------------------------------------------------------------"

    # Check for prerequisites
    if ! command_exists aws; then
        echo "❌ AWS CLI is not installed. Please install it to continue."
        exit 1
    fi

    # Gather user input
    read -p "Enter your AWS Access Key ID: " AWS_ACCESS_KEY_ID
    if [[ -z "${AWS_ACCESS_KEY_ID}" ]]; then echo "❌ AWS Access Key ID cannot be empty. Aborting."; exit 1; fi
    read -p "Enter your AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    if [[ -z "${AWS_SECRET_ACCESS_KEY}" ]]; then echo "❌ AWS Secret Access Key cannot be empty. Aborting."; exit 1; fi
    read -p "Enter your AWS Region (e.g., 'us-east-1'): " AWS_REGION
    if [[ -z "${AWS_REGION}" ]]; then echo "❌ AWS Region cannot be empty. Aborting."; exit 1; fi
    read -p "Enter a unique S3 Bucket Name for hosting: " S3_BUCKET_NAME
    if [[ -z "${S3_BUCKET_NAME}" ]]; then echo "❌ S3 Bucket Name cannot be empty. Aborting."; exit 1; fi
    echo "------------------------------------------------------------------"
    echo

    # --- Section 2: AWS CLI Configuration ---
    echo "🔐 Step 1: Configuring AWS credentials for this session..."
    export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
    export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
    export AWS_DEFAULT_REGION=${AWS_REGION}

    if ! aws sts get-caller-identity > /dev/null; then
        echo "❌ AWS credentials are invalid. Aborting."; exit 1
    fi
    echo "✅ AWS credentials configured successfully."

    # Fetch AWS Account ID from the configured credentials.
    echo "Fetching AWS Account ID..."
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        echo "❌ Could not fetch AWS Account ID from credentials. Aborting."
        exit 1
    fi
    echo "✅ AWS Account ID (${AWS_ACCOUNT_ID}) fetched successfully."
    echo

    # --- Section 3: Ensure S3 Bucket Exists and is Configured ---
    echo "🪣 Step 2: Checking and configuring S3 bucket..."
    if ! aws s3api head-bucket --bucket "${S3_BUCKET_NAME}" > /dev/null 2>&1; then
        echo "S3 bucket '${S3_BUCKET_NAME}' not found. Creating it..."
        if [ "$AWS_REGION" == "us-east-1" ]; then
            aws s3api create-bucket --bucket "${S3_BUCKET_NAME}" --region "${AWS_REGION}"
        else
            aws s3api create-bucket --bucket "${S3_BUCKET_NAME}" --region "${AWS_REGION}" --create-bucket-configuration LocationConstraint="${AWS_REGION}"
        fi
        if [ $? -ne 0 ]; then echo "❌ Failed to create S3 bucket. Aborting."; exit 1; fi
    else
        echo "✅ S3 bucket '${S3_BUCKET_NAME}' already exists."
    fi

    echo "Updating S3 public access block settings to enforce privacy..."
    if ! aws s3api put-public-access-block --bucket "${S3_BUCKET_NAME}" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"; then
        echo "❌ Failed to update public access block settings. Aborting."; exit 1
    fi
    echo "✅ S3 bucket configured for private access via CloudFront OAC."
    echo

    # --- Section 4: Build the Vite Application ---
    echo "📦 Step 3: Building the Vite application..."
    if ! npm run build; then
        echo "❌ Build failed. Aborting deployment."; exit 1
    fi
    echo "✅ Application built successfully."
    echo
    
    # --- Section 5: Check for and/or Create CloudFront Distribution ---
    echo "☁️ Step 4: Checking and configuring CloudFront distribution..."
    
    # Define origins for both old and new configurations
    S3_WEBSITE_ENDPOINT="${S3_BUCKET_NAME}.s3-website-${AWS_REGION}.amazonaws.com"
    S3_REST_ENDPOINT="${S3_BUCKET_NAME}.s3.${AWS_REGION}.amazonaws.com"

    # First, check for an outdated distribution pointing to the public website endpoint
    OLD_CLOUDFRONT_DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[0].DomainName=='${S3_WEBSITE_ENDPOINT}'].Id" --output text)
    if [ ! -z "$OLD_CLOUDFRONT_DISTRIBUTION_ID" ]; then
        echo "❌ ERROR: An outdated CloudFront distribution (ID: ${OLD_CLOUDFRONT_DISTRIBUTION_ID}) was found."
        echo "This distribution is configured to use the old S3 public website endpoint."
        echo "Please delete this distribution in the AWS Console and run this script again."
        exit 1
    fi

    # Now, check for a correctly configured distribution
    CLOUDFRONT_DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[0].DomainName=='${S3_REST_ENDPOINT}'].Id" --output text)

    if [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
        echo "CloudFront distribution not found. Creating a new one..."
        echo "Creating Origin Access Control (OAC)..."
        OAC_ID=$(aws cloudfront create-origin-access-control --origin-access-control-config "Name=OAC_${S3_BUCKET_NAME}",OriginAccessControlOriginType=s3,SigningBehavior=always,SigningProtocol=sigv4 --query 'OriginAccessControl.Id' --output text)
        if [ -z "$OAC_ID" ]; then echo "❌ Failed to create Origin Access Control. Aborting."; exit 1; fi
        echo "✅ Origin Access Control created with ID: ${OAC_ID}"

        echo "Creating new distribution... (This can take 10-15 minutes, please be patient...)"
        CALLER_REFERENCE=$(date +%s)
        DISTRIBUTION_CONFIG_JSON=$(printf '{
            "Comment": "Distribution for %s", "CacheBehaviors": { "Quantity": 0 }, "IsIPV6Enabled": true,
            "Logging": { "IncludeCookies": false, "Enabled": false, "Bucket": "", "Prefix": "" },
            "Origins": { "Items": [ { "Id": "S3-%s", "DomainName": "%s", "OriginPath": "", "CustomHeaders": { "Quantity": 0 },
                "S3OriginConfig": { "OriginAccessIdentity": "" }, "OriginAccessControlId": "%s" } ], "Quantity": 1 },
            "DefaultCacheBehavior": { "TargetOriginId": "S3-%s", "ViewerProtocolPolicy": "redirect-to-https",
                "AllowedMethods": { "Items": ["GET", "HEAD", "OPTIONS"], "Quantity": 3, "CachedMethods": { "Items": ["GET", "HEAD", "OPTIONS"], "Quantity": 3 } },
                "TrustedSigners": { "Enabled": false, "Quantity": 0 }, "ForwardedValues": { "QueryString": false, "Cookies": { "Forward": "none" }, "Headers": { "Quantity": 0 } },
                "MinTTL": 0, "DefaultTTL": 86400 },
            "CallerReference": "%s", "PriceClass": "PriceClass_100", "Enabled": true, "DefaultRootObject": "index.html" }' \
            "$S3_BUCKET_NAME" "$S3_BUCKET_NAME" "$S3_REST_ENDPOINT" "$OAC_ID" "$S3_BUCKET_NAME" "$CALLER_REFERENCE")
        
        CREATION_OUTPUT=$(aws cloudfront create-distribution --distribution-config "${DISTRIBUTION_CONFIG_JSON}")
        CLOUDFRONT_DISTRIBUTION_ID=$(echo "$CREATION_OUTPUT" | grep '"Id":' | head -1 | awk -F'"' '{print $4}')
        CLOUDFRONT_DOMAIN_NAME=$(echo "$CREATION_OUTPUT" | grep '"DomainName":' | head -1 | awk -F'"' '{print $4}')

        if [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then echo "❌ CloudFront distribution creation failed. Aborting."; exit 1; fi

        echo "Waiting for distribution to be deployed..."
        aws cloudfront wait distribution-deployed --id "${CLOUDFRONT_DISTRIBUTION_ID}"
        echo "✅ CloudFront distribution created and deployed successfully."
        echo "Your CloudFront Domain Name is: ${CLOUDFRONT_DOMAIN_NAME}"
    else
        echo "✅ CloudFront distribution already exists with ID: ${CLOUDFRONT_DISTRIBUTION_ID}"
    fi
    echo

    # --- Section 6: Apply S3 Bucket Policy ---
    # This policy must be applied every time to ensure it's correct.
    echo "🔒 Step 5: Applying S3 bucket policy to grant access to CloudFront..."
    CLOUDFRONT_ARN="arn:aws:cloudfront::${AWS_ACCOUNT_ID}:distribution/${CLOUDFRONT_DISTRIBUTION_ID}"
    POLICY_JSON=$(printf '{ "Version": "2012-10-17", "Statement": [ { "Sid": "AllowCloudFrontServicePrincipal",
        "Effect": "Allow", "Principal": { "Service": "cloudfront.amazonaws.com" }, "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::%s/*", "Condition": { "StringEquals": { "AWS:SourceArn": "%s" } } } ] }' \
        "$S3_BUCKET_NAME" "$CLOUDFRONT_ARN")

    if ! aws s3api put-bucket-policy --bucket "${S3_BUCKET_NAME}" --policy "${POLICY_JSON}"; then
        echo "❌ Failed to apply S3 bucket policy for CloudFront access. Aborting."; exit 1
    fi
    echo "✅ S3 bucket policy updated."
    echo

    # --- Section 7: Sync Files to S3 (Live) ---
    echo "🚚 Step 6: Syncing build files to S3 (Live Deployment)..."
    aws s3 sync dist/ "s3://${S3_BUCKET_NAME}/" --delete
    echo "✅ S3 sync complete."
    echo

    # --- Section 8: Invalidate CloudFront Cache (Live) ---
    echo "💨 Step 7: Invalidating CloudFront distribution..."
    INVALIDATION_OUTPUT=$(aws cloudfront create-invalidation --distribution-id "${CLOUDFRONT_DISTRIBUTION_ID}" --paths "/*")
    INVALIDATION_ID=$(echo "$INVALIDATION_OUTPUT" | grep '"Id":' | head -1 | awk -F'"' '{print $4}')
    echo "✅ CloudFront invalidation created with ID: ${INVALIDATION_ID}."
    echo "Waiting for invalidation to complete..."
    aws cloudfront wait invalidation-completed --distribution-id "${CLOUDFRONT_DISTRIBUTION_ID}" --id "${INVALIDATION_ID}"
    echo "✅ Invalidation complete."
    echo
    
    echo "🏁 Deployment Complete!"
    echo "Your application is now live."
}

# --- Script Entry Point ---
main "$@" 