#!/bin/bash

# ==============================================================================
# ADD CUSTOM DOMAIN TO AWS CLOUDFRONT
# ==============================================================================
#
# Description:
# This script automates adding a custom domain (FQDN) to an existing AWS
# CloudFront distribution. It handles requesting an SSL certificate from AWS
# Certificate Manager (ACM), guiding you through DNS validation, and attaching
# the certificate to your distribution.
#
# Prerequisites:
# - AWS CLI must be installed.
# - You must have access to your domain's DNS settings to add a CNAME record.
#
# Usage:
# ./cloudfront-add-domain.sh
#
# ==============================================================================

# --- Helper Function ---
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Main Function ---
main() {
    # --- Section 1: Configuration ---
    echo "🚀 Starting Script to Add Custom Domain to CloudFront"
    echo "This script will request an SSL certificate and update your distribution."
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
    read -p "Enter the CloudFront Distribution ID to update: " CLOUDFRONT_DISTRIBUTION_ID
    if [[ -z "${CLOUDFRONT_DISTRIBUTION_ID}" ]]; then echo "❌ CloudFront Distribution ID cannot be empty. Aborting."; exit 1; fi
    read -p "Enter the custom domain name (e.g., 'jwt.fredlackey.com'): " CUSTOM_DOMAIN_NAME
    if [[ -z "${CUSTOM_DOMAIN_NAME}" ]]; then echo "❌ Custom Domain Name cannot be empty. Aborting."; exit 1; fi
    echo "------------------------------------------------------------------"
    echo

    # --- Section 2: AWS CLI Configuration ---
    echo "🔐 Step 1: Configuring AWS credentials for this session..."
    export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
    export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
    
    # Certificates for CloudFront MUST be in us-east-1
    export AWS_DEFAULT_REGION="us-east-1" 

    if ! aws sts get-caller-identity > /dev/null; then
        echo "❌ AWS credentials are invalid. Aborting."; exit 1
    fi
    echo "✅ AWS credentials configured successfully."
    echo

    # --- Section 3: Request ACM Certificate ---
    echo "📜 Step 2: Requesting SSL Certificate from AWS Certificate Manager (ACM)..."
    echo "Note: Certificates for CloudFront must be requested in 'us-east-1'."

    REQUEST_OUTPUT=$(aws acm request-certificate --domain-name "${CUSTOM_DOMAIN_NAME}" --validation-method DNS --query CertificateArn --output text)
    if [ $? -ne 0 ] || [ -z "$REQUEST_OUTPUT" ]; then
        echo "❌ Failed to request certificate for '${CUSTOM_DOMAIN_NAME}'. Aborting."; exit 1
    fi
    CERTIFICATE_ARN=$REQUEST_OUTPUT
    echo "✅ Certificate requested successfully. ARN: ${CERTIFICATE_ARN}"
    echo

    # --- Section 4: DNS Validation ---
    echo "🔎 Step 3: Waiting for DNS validation details..."
    # Allow some time for ACM to generate the validation record
    sleep 10 

    CNAME_NAME=$(aws acm describe-certificate --certificate-arn "${CERTIFICATE_ARN}" --query "Certificate.DomainValidationOptions[0].ResourceRecord.Name" --output text)
    CNAME_VALUE=$(aws acm describe-certificate --certificate-arn "${CERTIFICATE_ARN}" --query "Certificate.DomainValidationOptions[0].ResourceRecord.Value" --output text)

    if [ -z "$CNAME_NAME" ] || [ -z "$CNAME_VALUE" ]; then
        echo "❌ Could not retrieve DNS validation details. Please check the ACM console. Aborting."; exit 1
    fi

    echo "------------------------------------------------------------------"
    echo "ACTION REQUIRED: Please add the following CNAME record to your DNS provider:"
    echo
    echo "  Record Name:  ${CNAME_NAME}"
    echo "  Record Value: ${CNAME_VALUE}"
    echo
    echo "This record is required for AWS to validate that you own the domain."
    echo "------------------------------------------------------------------"
    read -p "Press [Enter] after you have added the CNAME record..."
    echo

    echo "⏳ Step 4: Waiting for certificate validation. This can take several minutes..."
    aws acm wait certificate-validated --certificate-arn "${CERTIFICATE_ARN}"
    if [ $? -ne 0 ]; then
        echo "❌ Certificate validation failed or timed out. Please check your DNS settings and the ACM console. Aborting."; exit 1
    fi
    echo "✅ Certificate has been validated and issued."
    echo

    # --- Section 5: Update CloudFront Distribution ---
    echo "☁️ Step 5: Updating CloudFront distribution..."
    
    # We need the ETag to update the distribution
    ETAG=$(aws cloudfront get-distribution-config --id "${CLOUDFRONT_DISTRIBUTION_ID}" --query 'ETag' --output text)
    if [ -z "$ETAG" ]; then echo "❌ Could not get ETag for distribution. Aborting."; exit 1; fi

    # Get the current distribution config
    DIST_CONFIG=$(aws cloudfront get-distribution-config --id "${CLOUDFRONT_DISTRIBUTION_ID}" --query 'DistributionConfig' --output json)

    # Add the custom domain and certificate, replacing the old ViewerCertificate object
    # to avoid conflicts with the default certificate.
    NEW_CONFIG=$(echo "${DIST_CONFIG}" | jq \
      --arg CUSTOM_DOMAIN_NAME "${CUSTOM_DOMAIN_NAME}" \
      --arg CERTIFICATE_ARN "${CERTIFICATE_ARN}" \
      '(.Aliases.Items += [$CUSTOM_DOMAIN_NAME]) | (.Aliases.Quantity += 1) | .ViewerCertificate = {ACMCertificateArn: $CERTIFICATE_ARN, SSLSupportMethod: "sni-only", MinimumProtocolVersion: "TLSv1.2_2021"}')

    if ! aws cloudfront update-distribution --id "${CLOUDFRONT_DISTRIBUTION_ID}" --distribution-config "${NEW_CONFIG}" --if-match "${ETAG}" --no-cli-pager; then
        echo "❌ Failed to update CloudFront distribution. Please check the settings in the AWS console. Aborting."; exit 1
    fi

    echo "✅ CloudFront distribution update initiated."
    echo "⏳ Step 6: Waiting for distribution to deploy changes. This can take 10-15 minutes..."
    aws cloudfront wait distribution-deployed --id "${CLOUDFRONT_DISTRIBUTION_ID}"
    echo "✅ Distribution deployed successfully."
    echo

    echo "🏁 Process Complete!"
    echo "Your custom domain '${CUSTOM_DOMAIN_NAME}' should now be active."
}

# --- Script Entry Point ---
main "$@" 