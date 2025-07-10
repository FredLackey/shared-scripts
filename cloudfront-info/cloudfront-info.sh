#!/bin/bash

# ==============================================================================
# FETCH AWS CLOUDFRONT DISTRIBUTION INFO
# ==============================================================================
#
# Author:
# Fred Lackey
# Fred.Lackey@gmail.com
# https://FredLackey.com
#
# Disclaimer:
# This script is provided "as is", without warranty of any kind.
# Please feel free to contact me with any questions.
#
# Description:
# This script finds and displays information about a CloudFront distribution
# by searching for its S3 bucket origin.
#
# Prerequisites:
# - AWS CLI must be installed.
# - jq (command-line JSON processor) must be installed.
#
# Usage:
# ./cloudfront-info.sh
#
# ==============================================================================

# --- Helper Functions ---
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Main Function ---
main() {
    echo "🚀 Welcome to the CloudFront Info Fetcher"
    echo "This script will find a CloudFront distribution based on an S3 bucket name."
    echo "------------------------------------------------------------------"

    # Check for prerequisites
    if ! command_exists aws; then
        echo "❌ AWS CLI is not installed. Please install it to continue."
        exit 1
    fi
    if ! command_exists jq; then
        echo "❌ jq is not installed. Please install it to continue (e.g., 'brew install jq')."
        exit 1
    fi

    # --- Gather user input ---
    read -p "Enter your AWS Access Key ID: " AWS_ACCESS_KEY_ID
    if [[ -z "${AWS_ACCESS_KEY_ID}" ]]; then echo "❌ AWS Access Key ID cannot be empty. Aborting."; exit 1; fi
    read -p "Enter your AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    if [[ -z "${AWS_SECRET_ACCESS_KEY}" ]]; then echo "❌ AWS Secret Access Key cannot be empty. Aborting."; exit 1; fi
    read -p "Enter your AWS Region (e.g., 'us-east-1'): " AWS_REGION
    if [[ -z "${AWS_REGION}" ]]; then echo "❌ AWS Region cannot be empty. Aborting."; exit 1; fi
    read -p "Enter the S3 Bucket Name for the origin: " S3_BUCKET_NAME
    if [[ -z "${S3_BUCKET_NAME}" ]]; then echo "❌ S3 Bucket Name cannot be empty. Aborting."; exit 1; fi
    echo "------------------------------------------------------------------"

    # --- Configure AWS CLI for this session ---
    echo "🔐 Configuring AWS credentials for this session..."
    export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
    export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
    export AWS_DEFAULT_REGION=${AWS_REGION}

    if ! aws sts get-caller-identity > /dev/null; then
        echo "❌ AWS credentials are invalid. Aborting."; exit 1
    fi
    echo "✅ AWS credentials configured successfully."

    # --- Find the distribution ---
    echo "🔎 Searching for a distribution with origin '${S3_BUCKET_NAME}'..."
    S3_REST_ENDPOINT="${S3_BUCKET_NAME}.s3.${AWS_REGION}.amazonaws.com"
    S3_WEBSITE_ENDPOINT="${S3_BUCKET_NAME}.s3-website-${AWS_REGION}.amazonaws.com"

    DISTRIBUTION_INFO=$(aws cloudfront list-distributions | jq --arg rest_ep "$S3_REST_ENDPOINT" --arg web_ep "$S3_WEBSITE_ENDPOINT" \
      '.DistributionList.Items[] | select(.Origins.Items[].DomainName == $rest_ep or .Origins.Items[].DomainName == $web_ep)')

    # --- Display Results ---
    echo "------------------------------------------------------------------"
    if [ -n "$DISTRIBUTION_INFO" ]; then
        DIST_ID=$(echo "$DISTRIBUTION_INFO" | jq -r '.Id')
        DIST_DOMAIN=$(echo "$DISTRIBUTION_INFO" | jq -r '.DomainName')
        DIST_STATUS=$(echo "$DISTRIBUTION_INFO" | jq -r '.Status')
        DIST_ENABLED=$(echo "$DISTRIBUTION_INFO" | jq -r '.Enabled')
        ALIASES=$(echo "$DISTRIBUTION_INFO" | jq -r '.Aliases.Items | if . then join(", ") else "None" end')
        
        echo "✅ Distribution Found!"
        echo "   - ID:                 ${DIST_ID}"
        echo "   - Domain Name:        ${DIST_DOMAIN}"
        echo "   - Status:             ${DIST_STATUS}"
        echo "   - Enabled:            ${DIST_ENABLED}"
        echo "   - Custom Domains:     ${ALIASES}"
    else
        echo "❌ No CloudFront distribution found with bucket '${S3_BUCKET_NAME}' as an origin."
    fi
    echo "------------------------------------------------------------------"
}

# --- Script Entry Point ---
main "$@" 