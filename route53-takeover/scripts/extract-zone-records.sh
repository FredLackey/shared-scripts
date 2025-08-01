#!/bin/bash

# Extract Zone Records Script for Terraform Variable Files
# Dynamically detects all DNS record types in use and generates appropriate Terraform variable files
# Usage: ./extract-zone-records.sh <domain-name> <aws-profile>
# Example: ./extract-zone-records.sh example.com demo-profile

set -e

DOMAIN_NAME="${1}"
AWS_PROFILE="${2}"

if [ -z "$DOMAIN_NAME" ] || [ -z "$AWS_PROFILE" ]; then
    echo "Usage: $0 <domain-name> <aws-profile>"
    echo "Example: $0 example.com demo-profile"
    exit 1
fi

echo "🔍 Extracting DNS records for domain: $DOMAIN_NAME"
echo "🔧 Using AWS profile: $AWS_PROFILE"
echo "----------------------------------------"

# Get the hosted zone ID
ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --dns-name "$DOMAIN_NAME" \
    --profile "$AWS_PROFILE" \
    --query "HostedZones[?Name=='${DOMAIN_NAME}.'].Id" \
    --output text | sed 's|/hostedzone/||')

if [ -z "$ZONE_ID" ]; then
    echo "❌ Error: Hosted zone not found for domain $DOMAIN_NAME"
    exit 1
fi

echo "✅ Found hosted zone ID: $ZONE_ID"

# Create output directory in project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/extracted"
mkdir -p "$OUTPUT_DIR"

# Get all records and save to temp file
echo "📥 Fetching all DNS records..."
aws route53 list-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" \
    --profile "$AWS_PROFILE" \
    --output json > "$OUTPUT_DIR/temp_all_records.json"

# Discover all record types in use
echo "🔎 Discovering record types in use..."
RECORD_TYPES=$(jq -r '.ResourceRecordSets[].Type' "$OUTPUT_DIR/temp_all_records.json" | sort | uniq)
ALIAS_TYPES=$(jq -r '.ResourceRecordSets[] | select(.AliasTarget) | .AliasTarget.DNSName' "$OUTPUT_DIR/temp_all_records.json" | sed 's/\.$//' | sort | uniq)

echo "📋 Found the following record types:"
for type in $RECORD_TYPES; do
    count=$(jq -r --arg type "$type" '.ResourceRecordSets[] | select(.Type == $type) | .Type' "$OUTPUT_DIR/temp_all_records.json" | wc -l)
    echo "  - $type: $count records"
done

# Check for alias records
if [ -n "$ALIAS_TYPES" ]; then
    echo "📋 Found alias records pointing to:"
    for alias in $ALIAS_TYPES; do
        echo "  - $alias"
    done
fi

echo ""
echo "📝 Generating Terraform variable files..."

# Function to generate A records
generate_a_records() {
    echo "# A Records (standard)" > "$OUTPUT_DIR/a_records.tfvars"
    echo "a_records = [" >> "$OUTPUT_DIR/a_records.tfvars"
    
    # Get standard A records (not aliases, not root domain)
    jq -r --arg domain "$DOMAIN_NAME" '
        .ResourceRecordSets[] | 
        select(.Type == "A" and .ResourceRecords and .Name != ($domain + ".")) |
        "  {\n    name  = \"" + (.Name | rtrimstr(".")) + "\"\n    value = \"" + .ResourceRecords[0].Value + "\"\n    ttl   = " + (.TTL | tostring) + "\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/a_records.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/a_records.tfvars"
    
    # Remove trailing comma from last entry
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/a_records.tfvars" && rm -f "$OUTPUT_DIR/a_records.tfvars.bak"
    
    echo "✅ Generated: a_records.tfvars"
}

# Function to generate AAAA records
generate_aaaa_records() {
    echo "# AAAA Records (IPv6)" > "$OUTPUT_DIR/aaaa_records.tfvars"
    echo "aaaa_records = [" >> "$OUTPUT_DIR/aaaa_records.tfvars"
    
    jq -r '
        .ResourceRecordSets[] | 
        select(.Type == "AAAA" and .ResourceRecords) |
        "  {\n    name  = \"" + (.Name | rtrimstr(".")) + "\"\n    value = \"" + .ResourceRecords[0].Value + "\"\n    ttl   = " + (.TTL | tostring) + "\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/aaaa_records.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/aaaa_records.tfvars"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/aaaa_records.tfvars" && rm -f "$OUTPUT_DIR/aaaa_records.tfvars.bak"
    
    echo "✅ Generated: aaaa_records.tfvars"
}

# Function to generate CNAME records
generate_cname_records() {
    echo "# CNAME Records" > "$OUTPUT_DIR/cname_records.tfvars"
    echo "cname_records = [" >> "$OUTPUT_DIR/cname_records.tfvars"
    
    jq -r '
        .ResourceRecordSets[] | 
        select(.Type == "CNAME" and .ResourceRecords) |
        "  {\n    name  = \"" + (.Name | rtrimstr(".")) + "\"\n    value = \"" + (.ResourceRecords[0].Value | rtrimstr(".")) + "\"\n    ttl   = " + (.TTL | tostring) + "\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/cname_records.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/cname_records.tfvars"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/cname_records.tfvars" && rm -f "$OUTPUT_DIR/cname_records.tfvars.bak"
    
    echo "✅ Generated: cname_records.tfvars"
}

# Function to generate TXT records
generate_txt_records() {
    echo "# TXT Records" > "$OUTPUT_DIR/txt_records.tfvars"
    echo "txt_records = [" >> "$OUTPUT_DIR/txt_records.tfvars"
    
    jq -r '
        .ResourceRecordSets[] | 
        select(.Type == "TXT" and .ResourceRecords) |
        "  {\n    name  = \"" + (.Name | rtrimstr(".")) + "\"\n    value = " + .ResourceRecords[0].Value + "\n    ttl   = " + (.TTL | tostring) + "\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/txt_records.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/txt_records.tfvars"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/txt_records.tfvars" && rm -f "$OUTPUT_DIR/txt_records.tfvars.bak"
    
    echo "✅ Generated: txt_records.tfvars"
}

# Function to generate MX records
generate_mx_records() {
    echo "# MX Records" > "$OUTPUT_DIR/mx_records.tfvars"
    echo "mx_records = [" >> "$OUTPUT_DIR/mx_records.tfvars"
    
    # Use AWS CLI directly to get MX records
    aws route53 list-resource-record-sets \
        --hosted-zone-id "$ZONE_ID" \
        --profile "$AWS_PROFILE" \
        --query 'ResourceRecordSets[?Type==`MX`]' \
        --output json > "$OUTPUT_DIR/temp_mx.json"
    
    # Process each MX record
    jq -r '.[] | 
        .Name as $name | 
        .TTL as $ttl | 
        .ResourceRecords[] | 
        (.Value | split(" ")) as $parts | 
        "  {\n    name     = \"" + ($name | rtrimstr(".")) + "\"\n    priority = " + $parts[0] + "\n    value    = \"" + ($parts[1:] | join(" ")) + "\"\n    ttl      = " + ($ttl | tostring) + "\n  },"' \
        "$OUTPUT_DIR/temp_mx.json" >> "$OUTPUT_DIR/mx_records.tfvars" 2>/dev/null
    
    echo "]" >> "$OUTPUT_DIR/mx_records.tfvars"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/mx_records.tfvars" && rm -f "$OUTPUT_DIR/mx_records.tfvars.bak"
    rm -f "$OUTPUT_DIR/temp_mx.json"
    
    echo "✅ Generated: mx_records.tfvars"
}

# Function to generate NS records (excluding root domain)
generate_ns_records() {
    echo "# NS Records (subdomain delegations)" > "$OUTPUT_DIR/ns_records.tfvars"
    echo "ns_records = [" >> "$OUTPUT_DIR/ns_records.tfvars"
    
    jq -r --arg domain "$DOMAIN_NAME" '
        .ResourceRecordSets[] | 
        select(.Type == "NS" and .Name != ($domain + ".") and .ResourceRecords) |
        "  {\n    name   = \"" + (.Name | rtrimstr(".")) + "\"\n    values = [\n" + 
        (.ResourceRecords | map("      \"" + (.Value | rtrimstr(".")) + "\"") | join(",\n")) + 
        "\n    ]\n    ttl    = " + (.TTL | tostring) + "\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/ns_records.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/ns_records.tfvars"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/ns_records.tfvars" && rm -f "$OUTPUT_DIR/ns_records.tfvars.bak"
    
    echo "✅ Generated: ns_records.tfvars"
}

# Function to generate SOA record
generate_soa_records() {
    echo "# SOA Record" > "$OUTPUT_DIR/soa_records.tfvars"
    
    SOA_DATA=$(jq -r '.ResourceRecordSets[] | select(.Type == "SOA") | .ResourceRecords[0].Value + "|" + (.TTL | tostring)' "$OUTPUT_DIR/temp_all_records.json")
    
    if [ -n "$SOA_DATA" ] && [ "$SOA_DATA" != "null|null" ]; then
        SOA_RECORD=$(echo "$SOA_DATA" | cut -d'|' -f1)
        SOA_TTL=$(echo "$SOA_DATA" | cut -d'|' -f2)
        
        echo "soa_record = {" >> "$OUTPUT_DIR/soa_records.tfvars"
        echo "$SOA_RECORD" | awk '{
            printf "  mname   = \"%s\"\n", $1
            printf "  rname   = \"%s\"\n", $2
            printf "  serial  = %s\n", $3
            printf "  refresh = %s\n", $4
            printf "  retry   = %s\n", $5
            printf "  expire  = %s\n", $6
            printf "  minimum = %s\n", $7
        }' >> "$OUTPUT_DIR/soa_records.tfvars"
        echo "  ttl     = $SOA_TTL" >> "$OUTPUT_DIR/soa_records.tfvars"
        echo "}" >> "$OUTPUT_DIR/soa_records.tfvars"
    else
        echo "soa_record = null" >> "$OUTPUT_DIR/soa_records.tfvars"
    fi
    
    echo "✅ Generated: soa_records.tfvars"
}

# Function to generate SRV records
generate_srv_records() {
    echo "# SRV Records" > "$OUTPUT_DIR/srv_records.tfvars"
    echo "srv_records = [" >> "$OUTPUT_DIR/srv_records.tfvars"
    
    jq -r '
        .ResourceRecordSets[] | 
        select(.Type == "SRV" and .ResourceRecords) |
        .ResourceRecords[] |
        (.Value | split(" ")) as $parts |
        "  {\n    name     = \"" + (input.Name | rtrimstr(".")) + "\"\n    priority = " + $parts[0] + "\n    weight   = " + $parts[1] + "\n    port     = " + $parts[2] + "\n    target   = \"" + $parts[3] + "\"\n    ttl      = " + (input.TTL | tostring) + "\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" 2>/dev/null >> "$OUTPUT_DIR/srv_records.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/srv_records.tfvars"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/srv_records.tfvars" && rm -f "$OUTPUT_DIR/srv_records.tfvars.bak"
    
    echo "✅ Generated: srv_records.tfvars"
}

# Function to generate PTR records
generate_ptr_records() {
    echo "# PTR Records (reverse DNS)" > "$OUTPUT_DIR/ptr_records.tfvars"
    echo "ptr_records = [" >> "$OUTPUT_DIR/ptr_records.tfvars"
    
    jq -r '
        .ResourceRecordSets[] | 
        select(.Type == "PTR" and .ResourceRecords) |
        "  {\n    name  = \"" + (.Name | rtrimstr(".")) + "\"\n    value = \"" + (.ResourceRecords[0].Value | rtrimstr(".")) + "\"\n    ttl   = " + (.TTL | tostring) + "\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/ptr_records.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/ptr_records.tfvars"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/ptr_records.tfvars" && rm -f "$OUTPUT_DIR/ptr_records.tfvars.bak"
    
    echo "✅ Generated: ptr_records.tfvars"
}

# Function to generate alias records by type
generate_alias_records() {
    local alias_type="$1"
    local pattern="$2"
    local filename="$3"
    local description="$4"
    
    echo "# $description" > "$OUTPUT_DIR/$filename"
    lowercase_alias_type=$(echo "$alias_type" | tr '[:upper:]' '[:lower:]')
    echo "${lowercase_alias_type}_aliases = [" >> "$OUTPUT_DIR/$filename"
    
    jq -r --arg pattern "$pattern" '
        .ResourceRecordSets[] | 
        select(.AliasTarget and (.AliasTarget.DNSName | contains($pattern))) |
        "  {\n    name     = \"" + (.Name | rtrimstr(".")) + "\"\n    dns_name = \"" + .AliasTarget.DNSName + "\"\n    zone_id  = \"" + .AliasTarget.HostedZoneId + "\"\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/$filename"
    
    echo "]" >> "$OUTPUT_DIR/$filename"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/$filename" && rm -f "$OUTPUT_DIR/$filename.bak"
    
    echo "✅ Generated: $filename"
}

# Generate files for ALL supported record types (placeholders if not in use)
ALL_SUPPORTED_TYPES="A AAAA CNAME TXT MX NS SOA SRV PTR"

echo "📝 Generating files for all supported DNS record types..."

for type in $ALL_SUPPORTED_TYPES; do
    if echo "$RECORD_TYPES" | grep -q "^$type$"; then
        echo "  Processing $type records (found in zone)..."
    else
        echo "  Creating placeholder for $type records (not found in zone)..."
    fi
    
    case "$type" in
        "A")
            generate_a_records
            ;;
        "AAAA")
            generate_aaaa_records
            ;;
        "CNAME")
            generate_cname_records
            ;;
        "TXT")
            generate_txt_records
            ;;
        "MX")
            generate_mx_records
            ;;
        "NS")
            generate_ns_records
            ;;
        "SOA")
            generate_soa_records
            ;;
        "SRV")
            generate_srv_records
            ;;
        "PTR")
            generate_ptr_records
            ;;
        *)
            echo "⚠️  Unknown record type: $type (skipping)"
            ;;
    esac
done

# Check for any additional record types in the zone that we don't support
for type in $RECORD_TYPES; do
    if ! echo "$ALL_SUPPORTED_TYPES" | grep -q "$type"; then
        echo "⚠️  Found unsupported record type in zone: $type (skipping)"
    fi
done

# Generate alias record files for ALL supported alias types (placeholders if not in use)
echo "📝 Generating alias record files for all supported types..."

# API Gateway aliases
if echo "$ALIAS_TYPES" | grep -q "execute-api"; then
    echo "  Processing API Gateway aliases (found in zone)..."
    generate_alias_records "api" "execute-api" "api_aliases.tfvars" "API Gateway Aliases"
else
    echo "  Creating placeholder for API Gateway aliases (not found in zone)..."
    echo "# API Gateway Aliases" > "$OUTPUT_DIR/api_aliases.tfvars"
    echo "api_aliases = [" >> "$OUTPUT_DIR/api_aliases.tfvars"
    echo "]" >> "$OUTPUT_DIR/api_aliases.tfvars"
    echo "✅ Generated: api_aliases.tfvars"
fi

# Application Load Balancer aliases
if echo "$ALIAS_TYPES" | grep -q "elb.amazonaws.com"; then
    echo "  Processing ALB aliases (found in zone)..."
    generate_alias_records "alb" "elb.amazonaws.com" "alb_aliases.tfvars" "Application Load Balancer Aliases"
else
    echo "  Creating placeholder for ALB aliases (not found in zone)..."
    echo "# Application Load Balancer Aliases" > "$OUTPUT_DIR/alb_aliases.tfvars"
    echo "alb_aliases = [" >> "$OUTPUT_DIR/alb_aliases.tfvars"
    echo "]" >> "$OUTPUT_DIR/alb_aliases.tfvars"
    echo "✅ Generated: alb_aliases.tfvars"
fi

# CloudFront aliases
if echo "$ALIAS_TYPES" | grep -q "cloudfront.net"; then
    echo "  Processing CloudFront aliases (found in zone)..."
    generate_alias_records "cloudfront" "cloudfront.net" "cloudfront_aliases.tfvars" "CloudFront Aliases"
else
    echo "  Creating placeholder for CloudFront aliases (not found in zone)..."
    echo "# CloudFront Aliases" > "$OUTPUT_DIR/cloudfront_aliases.tfvars"
    echo "cloudfront_aliases = [" >> "$OUTPUT_DIR/cloudfront_aliases.tfvars"
    echo "]" >> "$OUTPUT_DIR/cloudfront_aliases.tfvars"
    echo "✅ Generated: cloudfront_aliases.tfvars"
fi

# Generate configuration files
echo "📝 Generating configuration files..."

cat > "$OUTPUT_DIR/domain.tfvars" << EOF
# Domain Configuration
domain_name = "$DOMAIN_NAME"
aws_account_id = "$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)"
environment = "production"
default_ttl = 300
zone_comment = "Primary hosted zone for $DOMAIN_NAME"
EOF
echo "✅ Generated: domain.tfvars"

cat > "$OUTPUT_DIR/aws.tfvars" << EOF
# AWS Configuration
aws_region = "$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null || echo "us-east-1")"
aws_profile = "$AWS_PROFILE"
EOF
echo "✅ Generated: aws.tfvars"

# Clean up temp file
rm -f "$OUTPUT_DIR/temp_all_records.json"

echo ""
echo "🎉 Zone record extraction completed!"
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
echo "   (e.g., cp extracted/mx_records.tfvars variables/mx_records.auto.tfvars)"
echo "5. Resolve any naming conflicts or record collisions"
echo "6. Adjust any values as needed"
echo "7. Run terraform plan to verify the configuration"
echo ""
echo "💡 Note: Files are generated without '.auto' to prevent accidental"
echo "   overwrites and allow manual review before Terraform auto-loading."