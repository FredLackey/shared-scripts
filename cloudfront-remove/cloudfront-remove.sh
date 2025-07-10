#!/bin/bash

# ==============================================================================
# TEARDOWN AWS RESOURCES
# ==============================================================================
#
# Description:
# This script finds and deletes all AWS resources created by the
# 'deploy-cloudfront.sh' script. It is designed to be a complete cleanup
# utility.
#
# WARNING:
# This script is DESTRUCTIVE. It will permanently delete AWS resources.
# This action cannot be undone. Please be certain before proceeding.
#
# The script will find resources based on the S3 bucket name you provide.
# It will then ask for a final confirmation before deleting anything.
#
# The CloudFront deletion process can take 15-20 minutes as it requires
# disabling the distribution before it can be deleted. Please be patient.
#
# Prerequisites:
# - AWS CLI must be installed.
#
# Usage:
# ./cloudfront-remove.sh
#
# ==============================================================================

# --- Main Function ---
main() {
    # --- Section 1: Configuration ---
    echo "💣 AWS Resource Teardown Script"
    echo "WARNING: This script will permanently delete AWS resources."
    echo "------------------------------------------------------------------"

    # Gather user input to find the resources
    read -p "Enter your AWS Access Key ID: " AWS_ACCESS_KEY_ID
    if [[ -z "${AWS_ACCESS_KEY_ID}" ]]; then echo "❌ AWS Access Key ID cannot be empty. Aborting."; exit 1; fi
    read -p "Enter your AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    if [[ -z "${AWS_SECRET_ACCESS_KEY}" ]]; then echo "❌ AWS Secret Access Key cannot be empty. Aborting."; exit 1; fi
    read -p "Enter your AWS Region (e.g., 'us-east-1'): " AWS_REGION
    if [[ -z "${AWS_REGION}" ]]; then echo "❌ AWS Region cannot be empty. Aborting."; exit 1; fi
    read -p "Enter the S3 Bucket Name of the deployment to delete: " S3_BUCKET_NAME
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
    echo

    # --- Section 3: Find All Associated Resources ---
    echo "🔍 Step 2: Finding all associated AWS resources..."
    
    # Define potential origin endpoints
    S3_WEBSITE_ENDPOINT="${S3_BUCKET_NAME}.s3-website-${AWS_REGION}.amazonaws.com"
    S3_REST_ENDPOINT="${S3_BUCKET_NAME}.s3.${AWS_REGION}.amazonaws.com"

    # Find CloudFront distributions (old and new types)
    DIST_IDS_OLD=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[0].DomainName=='${S3_WEBSITE_ENDPOINT}'].Id" --output text)
    DIST_IDS_NEW=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[0].DomainName=='${S3_REST_ENDPOINT}'].Id" --output text)
    # Use xargs to trim whitespace and handle empty results gracefully
    ALL_DIST_IDS=$(echo "${DIST_IDS_OLD} ${DIST_IDS_NEW}" | xargs)
    
    # Find Origin Access Control
    OAC_ID=$(aws cloudfront list-origin-access-controls --query "OriginAccessControlList.Items[?Name=='OAC_${S3_BUCKET_NAME}'].Id" --output text)
    
    # Find S3 bucket
    S3_BUCKET_EXISTS=$(aws s3api head-bucket --bucket "${S3_BUCKET_NAME}" > /dev/null 2>&1 && echo "yes" || echo "no")

    echo "---------------------- Resources Found ----------------------"
    FOUND_SOMETHING=false
    if [ ! -z "$ALL_DIST_IDS" ]; then
        echo "CloudFront Distribution(s): ${ALL_DIST_IDS}"
        FOUND_SOMETHING=true
    fi
    # Also check that the result is not the literal string "None" to avoid false positives.
    if [ ! -z "$OAC_ID" ] && [ "$OAC_ID" != "None" ]; then
        echo "CloudFront OAC: ${OAC_ID}"
        FOUND_SOMETHING=true
    fi
    if [ "$S3_BUCKET_EXISTS" == "yes" ]; then
        echo "S3 Bucket: ${S3_BUCKET_NAME}"
        FOUND_SOMETHING=true
    fi

    if ! $FOUND_SOMETHING; then
        echo "No resources found for S3 bucket '${S3_BUCKET_NAME}'."
        echo "🏁 Teardown complete."
        exit 0
    fi
    echo "-----------------------------------------------------------"
    echo

    # --- Section 4: Final Confirmation ---
    read -p "This will PERMANENTLY DELETE the resources listed above. Are you absolutely sure? (yes/no): " CONFIRMATION
    if [ "$CONFIRMATION" != "yes" ]; then
        echo "Aborting teardown."
        exit 0
    fi
    echo

    # --- Section 5: Deletion Process ---
    echo "🔥 Step 3: Starting deletion process..."

    # 1. Delete CloudFront Distributions
    if [ ! -z "$ALL_DIST_IDS" ]; then
        for DIST_ID in $ALL_DIST_IDS; do
            echo "--- Deleting CloudFront Distribution: ${DIST_ID} ---"
            
            # Get the ETag. If the distribution is already gone, skip.
            ETAG_OUTPUT=$(aws cloudfront get-distribution-config --id "${DIST_ID}" --query ETag --output text 2>&1)
            if [ $? -ne 0 ]; then
                if echo "${ETAG_OUTPUT}" | grep -q "NoSuchDistribution"; then
                    echo "Distribution ${DIST_ID} not found, likely already deleted. Skipping."
                    continue
                else
                    echo "❌ Error getting ETag for ${DIST_ID}:"
                    echo "${ETAG_OUTPUT}"
                    exit 1
                fi
            fi
            ETAG=$ETAG_OUTPUT
            
            # Get the config object itself using the --query parameter for valid JSON.
            CONFIG_JSON=$(aws cloudfront get-distribution-config --id "${DIST_ID}" --query DistributionConfig --output json)
            
            # Create the 'disabled' version of the configuration.
            DISABLED_CONFIG_JSON=$(echo "${CONFIG_JSON}" | sed 's/"Enabled": true/"Enabled": false/')
            
            # Proactively try to disable the distribution.
            echo "Sending disable request for ${DIST_ID}..."
            UPDATE_OUTPUT=$(aws cloudfront update-distribution --id "${DIST_ID}" --if-match "${ETAG}" --distribution-config "${DISABLED_CONFIG_JSON}" 2>&1)

            if [ $? -ne 0 ]; then
                # If the error is that it's already disabled, that's okay. We can continue.
                if echo "${UPDATE_OUTPUT}" | grep -q "IllegalUpdate" && echo "${UPDATE_OUTPUT}" | grep -q "The distribution is already disabled"; then
                    echo "Distribution was already in a disabled state. Proceeding to verification."
                else
                    # Any other error during the disable attempt is a problem.
                    echo "❌ An unexpected error occurred while trying to disable the distribution:"
                    echo "${UPDATE_OUTPUT}"
                    exit 1
                fi
            else
                echo "Disable request sent. Now waiting for this change to be confirmed across all of AWS..."
            fi

            # Now, poll until AWS's systems unanimously agree on the final state. This is the source of truth.
            echo "Waiting for distribution to confirm 'Deployed' and 'Disabled' status... (this can take 15+ minutes)"
            while true; do
                GET_DIST_OUTPUT=$(aws cloudfront get-distribution --id "${DIST_ID}" 2>&1)
                if echo "${GET_DIST_OUTPUT}" | grep -q "NoSuchDistribution"; then
                    echo "✅ Distribution successfully deleted during polling."
                    break # Exit the polling loop as the resource is gone
                fi

                DIST_STATUS=$(echo "$GET_DIST_OUTPUT" | grep '"Status":' | awk -F'"' '{print $4}')
                IS_ENABLED_CONFIG=$(aws cloudfront get-distribution-config --id "${DIST_ID}" --query 'DistributionConfig.Enabled' --output text)

                if [ "$DIST_STATUS" == "Deployed" ] && [ "$IS_ENABLED_CONFIG" == "False" ]; then
                    echo "✅ Distribution is confirmed Deployed and Disabled."
                    break
                else
                    echo "Current state is not yet final. Status: ${DIST_STATUS}, Enabled: ${IS_ENABLED_CONFIG}. Waiting 60 seconds..."
                    sleep 60
                fi
            done

            # --- Deletion Retry Loop ---
            DELETED=false
            MAX_RETRIES=5
            RETRY_COUNT=0
            RETRY_DELAY_SEC=60

            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
                FINAL_ETAG=$(aws cloudfront get-distribution-config --id "${DIST_ID}" --query 'ETag' --output text)
                if [ $? -ne 0 ]; then echo "Could not get ETag for ${DIST_ID}. Assuming it was already deleted."; DELETED=true; break; fi

                echo "Attempting to delete distribution (Attempt $((RETRY_COUNT+1))/${MAX_RETRIES})..."
                DELETE_ERROR=$(aws cloudfront delete-distribution --id "${DIST_ID}" --if-match "${FINAL_ETAG}" 2>&1)

                if [ $? -eq 0 ]; then
                    echo "✅ Distribution deleted successfully."
                    DELETED=true
                    break
                else
                    if echo "${DELETE_ERROR}" | grep -q "DistributionNotDisabled"; then
                        RETRY_COUNT=$((RETRY_COUNT+1))
                        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                            echo "Distribution not fully disabled yet. Waiting ${RETRY_DELAY_SEC}s before retrying..."
                            sleep ${RETRY_DELAY_SEC}
                        else
                            echo "❌ Reached max retries. Deletion failed."
                            echo "${DELETE_ERROR}"
                            break
                        fi
                    else
                        echo "❌ An unexpected error occurred during deletion:"
                        echo "${DELETE_ERROR}"
                        break
                    fi
                fi
            done

            if ! $DELETED; then echo "❌ Failed to delete distribution ${DIST_ID} after all retries. Please try manually."; fi
            echo "-----------------------------------------------------"
        done
    fi

    # 2. Delete Origin Access Control
    if [ ! -z "$OAC_ID" ] && [ "$OAC_ID" != "None" ]; then
        echo "--- Deleting Origin Access Control: ${OAC_ID} ---"
        DELETED_OAC=false
        MAX_RETRIES_OAC=3
        RETRY_COUNT_OAC=0
        RETRY_DELAY_SEC_OAC=30

        while [ $RETRY_COUNT_OAC -lt $MAX_RETRIES_OAC ]; do
            # We redirect stderr to /dev/null to suppress the "NoSuchOriginAccessControl" error for cleaner logs.
            # The script's logic correctly handles the non-zero exit code.
            OAC_ETAG=$(aws cloudfront get-origin-access-control --id "${OAC_ID}" --query 'ETag' --output text 2>/dev/null)
            if [ $? -ne 0 ]; then echo "OAC ${OAC_ID} not found. Skipping."; DELETED_OAC=true; break; fi

            echo "Attempting to delete OAC (Attempt $((RETRY_COUNT_OAC+1))/${MAX_RETRIES_OAC})..."
            DELETE_ERROR_OAC=$(aws cloudfront delete-origin-access-control --id "${OAC_ID}" --if-match "${OAC_ETAG}" 2>&1)
            
            if [ $? -eq 0 ]; then
                echo "✅ OAC deleted successfully."
                DELETED_OAC=true
                break
            else
                if echo "${DELETE_ERROR_OAC}" | grep -q "OriginAccessControlInUse"; then
                    RETRY_COUNT_OAC=$((RETRY_COUNT_OAC+1))
                    if [ $RETRY_COUNT_OAC -lt $MAX_RETRIES_OAC ]; then
                        echo "OAC still in use by a distribution. Waiting ${RETRY_DELAY_SEC_OAC}s..."
                        sleep ${RETRY_DELAY_SEC_OAC}
                    else
                        echo "❌ Reached max retries for OAC deletion."; echo "${DELETE_ERROR_OAC}"; break
                    fi
                else
                    echo "❌ An unexpected error occurred during OAC deletion:"; echo "${DELETE_ERROR_OAC}"; break
                fi
            fi
        done
        if ! $DELETED_OAC; then echo "❌ Failed to delete OAC ${OAC_ID}. Please try manually."; fi
        echo "-----------------------------------------------------"
    fi

    # 3. Delete S3 Bucket
    if [ "$S3_BUCKET_EXISTS" == "yes" ]; then
        echo "--- Deleting S3 Bucket: ${S3_BUCKET_NAME} ---"
        echo "Emptying and deleting bucket..."
        aws s3 rb "s3://${S3_BUCKET_NAME}" --force
        if [ $? -ne 0 ]; then echo "❌ Failed to delete bucket ${S3_BUCKET_NAME}. Please try manually."; else echo "✅ Bucket deleted."; fi
        echo "-----------------------------------------------------"
    fi

    echo "🏁 Teardown complete."
}

# --- Script Entry Point ---
main "$@" 