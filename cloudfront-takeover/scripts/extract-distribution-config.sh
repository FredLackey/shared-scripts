#!/bin/bash

# Extract CloudFront Distribution Configuration Script for Terraform Variable Files
# Dynamically extracts all CloudFront distribution configuration and generates appropriate Terraform variable files
# Usage: ./extract-distribution-config.sh <distribution-id> <aws-profile>
# Example: ./extract-distribution-config.sh E1234567890ABC demo-profile

set -e

DISTRIBUTION_ID="${1}"
AWS_PROFILE="${2}"

if [ -z "$DISTRIBUTION_ID" ] || [ -z "$AWS_PROFILE" ]; then
    echo "Usage: $0 <distribution-id> <aws-profile>"
    echo "Example: $0 E1234567890ABC demo-profile"
    exit 1
fi

echo "🔍 Extracting CloudFront distribution configuration for: $DISTRIBUTION_ID"
echo "🔧 Using AWS profile: $AWS_PROFILE"
echo "----------------------------------------"

# Get the distribution configuration
echo "📥 Fetching CloudFront distribution configuration..."
aws cloudfront get-distribution \
    --id "$DISTRIBUTION_ID" \
    --profile "$AWS_PROFILE" \
    --output json > /tmp/cloudfront_distribution.json

if [ ! -f "/tmp/cloudfront_distribution.json" ] || [ ! -s "/tmp/cloudfront_distribution.json" ]; then
    echo "❌ Error: Failed to fetch distribution configuration for $DISTRIBUTION_ID"
    exit 1
fi

# Check if distribution exists by looking for an error
if jq -e '.Error' /tmp/cloudfront_distribution.json > /dev/null 2>&1; then
    echo "❌ Error: Distribution not found or access denied for $DISTRIBUTION_ID"
    jq -r '.Error.Message' /tmp/cloudfront_distribution.json
    rm -f /tmp/cloudfront_distribution.json
    exit 1
fi

echo "✅ Found CloudFront distribution: $DISTRIBUTION_ID"

# Create output directory in project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/extracted"
mkdir -p "$OUTPUT_DIR"

# Extract distribution details
echo "🔎 Extracting distribution components..."

DISTRIBUTION_DOMAIN=$(jq -r '.Distribution.DomainName' /tmp/cloudfront_distribution.json)
DISTRIBUTION_STATUS=$(jq -r '.Distribution.Status' /tmp/cloudfront_distribution.json)
DISTRIBUTION_CONFIG=$(jq '.Distribution.DistributionConfig' /tmp/cloudfront_distribution.json)

echo "📋 Distribution Details:"
echo "  - Domain Name: $DISTRIBUTION_DOMAIN"
echo "  - Status: $DISTRIBUTION_STATUS"
echo "  - Distribution ID: $DISTRIBUTION_ID"

# Count components
ORIGINS_COUNT=$(echo "$DISTRIBUTION_CONFIG" | jq '.Origins.Quantity')
ALIASES_COUNT=$(echo "$DISTRIBUTION_CONFIG" | jq '.Aliases.Quantity')
CACHE_BEHAVIORS_COUNT=$(echo "$DISTRIBUTION_CONFIG" | jq '.CacheBehaviors.Quantity')
CUSTOM_ERROR_RESPONSES_COUNT=$(echo "$DISTRIBUTION_CONFIG" | jq '.CustomErrorResponses.Quantity')

echo "📊 Configuration Summary:"
echo "  - Origins: $ORIGINS_COUNT"
echo "  - Aliases: $ALIASES_COUNT" 
echo "  - Cache Behaviors: $CACHE_BEHAVIORS_COUNT"
echo "  - Custom Error Responses: $CUSTOM_ERROR_RESPONSES_COUNT"

echo ""
echo "📝 Generating Terraform variable files..."

# Function to generate distribution basic configuration
generate_distribution_config() {
    echo "# CloudFront Distribution Basic Configuration" > "$OUTPUT_DIR/distribution_config.tfvars"
    
    # Extract basic distribution settings
    echo "$DISTRIBUTION_CONFIG" | jq -r '
        "# Distribution Basic Settings\n" +
        "distribution_id = \"" + input.Distribution.Id + "\"\n" +
        "caller_reference = \"" + .CallerReference + "\"\n" +
        "comment = \"" + (.Comment // "") + "\"\n" +
        "default_root_object = \"" + (.DefaultRootObject // "") + "\"\n" +
        "enabled = " + (.Enabled | tostring) + "\n" +
        "is_ipv6_enabled = " + (.IsIPV6Enabled | tostring) + "\n" +
        "http_version = \"" + .HttpVersion + "\"\n" +
        "price_class = \"" + .PriceClass + "\"\n" +
        "web_acl_id = \"" + (.WebACLId // "") + "\""
    ' --slurpfile input /tmp/cloudfront_distribution.json >> "$OUTPUT_DIR/distribution_config.tfvars"
    
    echo "✅ Generated: distribution_config.tfvars"
}

# Function to generate origins configuration
generate_origins_config() {
    echo "# CloudFront Origins Configuration" > "$OUTPUT_DIR/origins.tfvars"
    echo "origins = [" >> "$OUTPUT_DIR/origins.tfvars"
    
    echo "$DISTRIBUTION_CONFIG" | jq -r '
        .Origins.Items[] |
        "  {\n" +
        "    id                         = \"" + .Id + "\"\n" +
        "    domain_name               = \"" + .DomainName + "\"\n" +
        "    origin_path               = \"" + (.OriginPath // "") + "\"\n" +
        "    connection_attempts       = " + (.ConnectionAttempts | tostring) + "\n" +
        "    connection_timeout        = " + (.ConnectionTimeout | tostring) + "\n" +
        (if .S3OriginConfig then
        "    s3_origin_config = {\n" +
        "      origin_access_identity = \"" + (.S3OriginConfig.OriginAccessIdentity // "") + "\"\n" +
        "    }\n"
        else "" end) +
        (if .CustomOriginConfig then
        "    custom_origin_config = {\n" +
        "      http_port              = " + (.CustomOriginConfig.HTTPPort | tostring) + "\n" +
        "      https_port             = " + (.CustomOriginConfig.HTTPSPort | tostring) + "\n" +
        "      origin_protocol_policy = \"" + .CustomOriginConfig.OriginProtocolPolicy + "\"\n" +
        "      origin_ssl_protocols   = [" + (.CustomOriginConfig.OriginSslProtocols.Items | map("\"" + . + "\"") | join(", ")) + "]\n" +
        "    }\n"
        else "" end) +
        (if .OriginShield.Enabled then
        "    origin_shield = {\n" +
        "      enabled = " + (.OriginShield.Enabled | tostring) + "\n" +
        "      origin_shield_region = \"" + (.OriginShield.OriginShieldRegion // "") + "\"\n" +
        "    }\n"
        else "" end) +
        "  },"
    ' >> "$OUTPUT_DIR/origins.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/origins.tfvars"
    
    # Remove trailing comma from last entry
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/origins.tfvars" && rm -f "$OUTPUT_DIR/origins.tfvars.bak"
    
    echo "✅ Generated: origins.tfvars"
}

# Function to generate aliases configuration
generate_aliases_config() {
    echo "# CloudFront Aliases Configuration" > "$OUTPUT_DIR/aliases.tfvars"
    
    if [ "$ALIASES_COUNT" -gt 0 ]; then
        echo "aliases = [" >> "$OUTPUT_DIR/aliases.tfvars"
        echo "$DISTRIBUTION_CONFIG" | jq -r '.Aliases.Items[] | "  \"" + . + "\","' >> "$OUTPUT_DIR/aliases.tfvars"
        echo "]" >> "$OUTPUT_DIR/aliases.tfvars"
        # Remove trailing comma from last entry
        sed -i.bak '$s/,$//' "$OUTPUT_DIR/aliases.tfvars" && rm -f "$OUTPUT_DIR/aliases.tfvars.bak"
    else
        echo "aliases = []" >> "$OUTPUT_DIR/aliases.tfvars"
    fi
    
    echo "✅ Generated: aliases.tfvars"
}

# Function to generate default cache behavior
generate_default_cache_behavior() {
    echo "# Default Cache Behavior Configuration" > "$OUTPUT_DIR/default_cache_behavior.tfvars"
    
    echo "$DISTRIBUTION_CONFIG" | jq -r '
        .DefaultCacheBehavior |
        "default_cache_behavior = {\n" +
        "  target_origin_id                 = \"" + .TargetOriginId + "\"\n" +
        "  viewer_protocol_policy          = \"" + .ViewerProtocolPolicy + "\"\n" +
        "  allowed_methods                 = [" + (.AllowedMethods.Items | map("\"" + . + "\"") | join(", ")) + "]\n" +
        "  cached_methods                  = [" + (.AllowedMethods.CachedMethods.Items | map("\"" + . + "\"") | join(", ")) + "]\n" +
        "  compress                        = " + (.Compress | tostring) + "\n" +
        "  smooth_streaming               = " + (.SmoothStreaming | tostring) + "\n" +
        (if .CachePolicyId then
        "  cache_policy_id                = \"" + .CachePolicyId + "\"\n"
        else "" end) +
        (if .OriginRequestPolicyId then
        "  origin_request_policy_id       = \"" + .OriginRequestPolicyId + "\"\n"
        else "" end) +
        (if .ResponseHeadersPolicyId then
        "  response_headers_policy_id     = \"" + .ResponseHeadersPolicyId + "\"\n"
        else "" end) +
        (if .RealtimeLogConfigArn then
        "  realtime_log_config_arn        = \"" + .RealtimeLogConfigArn + "\"\n"
        else "" end) +
        (if .FieldLevelEncryptionId then
        "  field_level_encryption_id      = \"" + .FieldLevelEncryptionId + "\"\n"
        else "" end) +
        "}"
    ' >> "$OUTPUT_DIR/default_cache_behavior.tfvars"
    
    echo "✅ Generated: default_cache_behavior.tfvars"
}

# Function to generate cache behaviors
generate_cache_behaviors() {
    echo "# Cache Behaviors Configuration" > "$OUTPUT_DIR/cache_behaviors.tfvars"
    
    if [ "$CACHE_BEHAVIORS_COUNT" -gt 0 ]; then
        echo "cache_behaviors = [" >> "$OUTPUT_DIR/cache_behaviors.tfvars"
        
        echo "$DISTRIBUTION_CONFIG" | jq -r '
            .CacheBehaviors.Items[] |
            "  {\n" +
            "    path_pattern                = \"" + .PathPattern + "\"\n" +
            "    target_origin_id           = \"" + .TargetOriginId + "\"\n" +
            "    viewer_protocol_policy     = \"" + .ViewerProtocolPolicy + "\"\n" +
            "    allowed_methods            = [" + (.AllowedMethods.Items | map("\"" + . + "\"") | join(", ")) + "]\n" +
            "    cached_methods             = [" + (.AllowedMethods.CachedMethods.Items | map("\"" + . + "\"") | join(", ")) + "]\n" +
            "    compress                   = " + (.Compress | tostring) + "\n" +
            (if .CachePolicyId then
            "    cache_policy_id            = \"" + .CachePolicyId + "\"\n"
            else "" end) +
            (if .OriginRequestPolicyId then
            "    origin_request_policy_id   = \"" + .OriginRequestPolicyId + "\"\n"
            else "" end) +
            "  },"
        ' >> "$OUTPUT_DIR/cache_behaviors.tfvars"
        
        echo "]" >> "$OUTPUT_DIR/cache_behaviors.tfvars"
        # Remove trailing comma from last entry
        sed -i.bak '$s/,$//' "$OUTPUT_DIR/cache_behaviors.tfvars" && rm -f "$OUTPUT_DIR/cache_behaviors.tfvars.bak"
    else
        echo "cache_behaviors = []" >> "$OUTPUT_DIR/cache_behaviors.tfvars"
    fi
    
    echo "✅ Generated: cache_behaviors.tfvars"
}

# Function to generate viewer certificate configuration
generate_viewer_certificate() {
    echo "# Viewer Certificate Configuration" > "$OUTPUT_DIR/viewer_certificate.tfvars"
    
    echo "$DISTRIBUTION_CONFIG" | jq -r '
        .ViewerCertificate |
        "viewer_certificate = {\n" +
        "  cloudfront_default_certificate = " + (.CloudFrontDefaultCertificate | tostring) + "\n" +
        (if .ACMCertificateArn then
        "  acm_certificate_arn           = \"" + .ACMCertificateArn + "\"\n"
        else "" end) +
        (if .IAMCertificateId then
        "  iam_certificate_id            = \"" + .IAMCertificateId + "\"\n"
        else "" end) +
        (if .SSLSupportMethod then
        "  ssl_support_method            = \"" + .SSLSupportMethod + "\"\n"
        else "" end) +
        (if .MinimumProtocolVersion then
        "  minimum_protocol_version      = \"" + .MinimumProtocolVersion + "\"\n"
        else "" end) +
        "}"
    ' >> "$OUTPUT_DIR/viewer_certificate.tfvars"
    
    echo "✅ Generated: viewer_certificate.tfvars"
}

# Function to generate custom error responses
generate_custom_error_responses() {
    echo "# Custom Error Responses Configuration" > "$OUTPUT_DIR/custom_error_responses.tfvars"
    
    if [ "$CUSTOM_ERROR_RESPONSES_COUNT" -gt 0 ]; then
        echo "custom_error_responses = [" >> "$OUTPUT_DIR/custom_error_responses.tfvars"
        
        echo "$DISTRIBUTION_CONFIG" | jq -r '
            .CustomErrorResponses.Items[] |
            "  {\n" +
            "    error_code            = " + (.ErrorCode | tostring) + "\n" +
            (if .ResponsePagePath then
            "    response_page_path    = \"" + .ResponsePagePath + "\"\n"
            else "" end) +
            (if .ResponseCode then
            "    response_code         = \"" + .ResponseCode + "\"\n"
            else "" end) +
            (if .ErrorCachingMinTTL then
            "    error_caching_min_ttl = " + (.ErrorCachingMinTTL | tostring) + "\n"
            else "" end) +
            "  },"
        ' >> "$OUTPUT_DIR/custom_error_responses.tfvars"
        
        echo "]" >> "$OUTPUT_DIR/custom_error_responses.tfvars"
        # Remove trailing comma from last entry
        sed -i.bak '$s/,$//' "$OUTPUT_DIR/custom_error_responses.tfvars" && rm -f "$OUTPUT_DIR/custom_error_responses.tfvars.bak"
    else
        echo "custom_error_responses = []" >> "$OUTPUT_DIR/custom_error_responses.tfvars"
    fi
    
    echo "✅ Generated: custom_error_responses.tfvars"
}

# Function to generate geo restrictions
generate_geo_restrictions() {
    echo "# Geo Restrictions Configuration" > "$OUTPUT_DIR/geo_restrictions.tfvars"
    
    echo "$DISTRIBUTION_CONFIG" | jq -r '
        .Restrictions.GeoRestriction |
        "geo_restriction = {\n" +
        "  restriction_type = \"" + .RestrictionType + "\"\n" +
        "  locations        = [" + ((.Items // []) | map("\"" + . + "\"") | join(", ")) + "]\n" +
        "}"
    ' >> "$OUTPUT_DIR/geo_restrictions.tfvars"
    
    echo "✅ Generated: geo_restrictions.tfvars"
}

# Function to generate logging configuration
generate_logging_config() {
    echo "# Logging Configuration" > "$OUTPUT_DIR/logging.tfvars"
    
    echo "$DISTRIBUTION_CONFIG" | jq -r '
        .Logging |
        "logging_config = {\n" +
        "  enabled         = " + (.Enabled | tostring) + "\n" +
        "  include_cookies = " + (.IncludeCookies | tostring) + "\n" +
        "  bucket          = \"" + (.Bucket // "") + "\"\n" +
        "  prefix          = \"" + (.Prefix // "") + "\"\n" +
        "}"
    ' >> "$OUTPUT_DIR/logging.tfvars"
    
    echo "✅ Generated: logging.tfvars"
}

# Generate configuration files
echo "📝 Generating configuration files..."

# Generate basic AWS configuration
cat > "$OUTPUT_DIR/aws.tfvars" << EOF
# AWS Configuration  
aws_region = "$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null || echo "us-east-1")"
aws_profile = "$AWS_PROFILE"
aws_account_id = "$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)"
EOF
echo "✅ Generated: aws.tfvars"

# Generate all configuration sections
generate_distribution_config
generate_origins_config
generate_aliases_config
generate_default_cache_behavior
generate_cache_behaviors
generate_viewer_certificate
generate_custom_error_responses
generate_geo_restrictions
generate_logging_config

# Clean up temp file
rm -f /tmp/cloudfront_distribution.json

echo ""
echo "🎉 CloudFront distribution configuration extraction completed!"
echo "📁 All files generated in: extracted/"
echo ""
echo "📋 Summary of generated files:"
ls -la "$OUTPUT_DIR/" | grep -v "^total"
echo ""
echo "🚀 Next steps:"
echo "1. Review the generated .tfvars files in extracted/"
echo "2. Create a 'variables/' directory in your Terraform project"
echo "3. Copy desired files from extracted/ to variables/"
echo "4. Rename files to .auto.tfvars if you want automatic loading"
echo "   (e.g., cp extracted/origins.tfvars variables/origins.auto.tfvars)"
echo "5. Customize any values as needed for your infrastructure"
echo "6. Run terraform plan to verify the configuration"
echo ""
echo "💡 Note: Files are generated without '.auto' to prevent accidental"
echo "   overwrites and allow manual review before Terraform auto-loading."