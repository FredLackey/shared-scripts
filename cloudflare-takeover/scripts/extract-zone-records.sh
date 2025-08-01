#!/bin/bash

# Extract Zone Records Script for Cloudflare API to Terraform Variable Files
# Dynamically detects all DNS record types in use and generates appropriate Terraform variable files
# Usage: ./extract-zone-records.sh <domain-name> <cloudflare-api-token>
# Example: ./extract-zone-records.sh example.com your-cloudflare-api-token

set -e

DOMAIN_NAME="${1}"
CLOUDFLARE_API_TOKEN="${2}"

if [ -z "$DOMAIN_NAME" ] || [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "Usage: $0 <domain-name> <cloudflare-api-token>"
    echo "Example: $0 example.com your-cloudflare-api-token"
    echo ""
    echo "To get your API token:"
    echo "1. Go to https://dash.cloudflare.com/profile/api-tokens"
    echo "2. Create a token with Zone:Read permissions"
    echo "3. Include the specific zone or use All zones"
    exit 1
fi

echo "🔍 Extracting DNS records for domain: $DOMAIN_NAME"
echo "🔧 Using Cloudflare API token: ${CLOUDFLARE_API_TOKEN:0:8}..."
echo "----------------------------------------"

# Get the zone ID
echo "📡 Getting zone ID for domain..."
ZONE_RESPONSE=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN_NAME" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json")

# Check if API call was successful
if ! echo "$ZONE_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    echo "❌ Error: Failed to get zone information"
    echo "$ZONE_RESPONSE" | jq -r '.errors[]?.message // "Unknown error"'
    exit 1
fi

ZONE_ID=$(echo "$ZONE_RESPONSE" | jq -r '.result[0].id // empty')

if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
    echo "❌ Error: Zone not found for domain $DOMAIN_NAME"
    echo "Make sure the domain is added to your Cloudflare account"
    exit 1
fi

echo "✅ Found zone ID: $ZONE_ID"

# Create output directory in project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/extracted"
mkdir -p "$OUTPUT_DIR"

# Get all records and save to temp file
echo "📥 Fetching all DNS records..."
curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?per_page=50000" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" > "$OUTPUT_DIR/temp_all_records.json"

# Check if API call was successful
if ! jq -e '.success' "$OUTPUT_DIR/temp_all_records.json" > /dev/null 2>&1; then
    echo "❌ Error: Failed to fetch DNS records"
    jq -r '.errors[]?.message // "Unknown error"' "$OUTPUT_DIR/temp_all_records.json"
    exit 1
fi

# Discover all record types in use
echo "🔎 Discovering record types in use..."
RECORD_TYPES=$(jq -r '.result[].type' "$OUTPUT_DIR/temp_all_records.json" | sort | uniq)

echo "📋 Found the following record types:"
for type in $RECORD_TYPES; do
    count=$(jq -r --arg type "$type" '.result[] | select(.type == $type) | .type' "$OUTPUT_DIR/temp_all_records.json" | wc -l)
    echo "  - $type: $count records"
done

echo ""
echo "📝 Generating Terraform variable files..."

# Function to generate A records
generate_a_records() {
    echo "# A Records (IPv4)" > "$OUTPUT_DIR/a_records.tfvars"
    echo "a_records = [" >> "$OUTPUT_DIR/a_records.tfvars"
    
    # Get A records (not proxied through Cloudflare)
    jq -r --arg domain "$DOMAIN_NAME" '
        .result[] | 
        select(.type == "A" and .name != $domain) |
        "  {\n    name     = \"" + .name + "\"\n    content  = \"" + .content + "\"\n    ttl      = " + (.ttl | tostring) + "\n    proxied  = " + (.proxied | tostring) + "\n    comment  = \"" + (.comment // "") + "\"\n  },"
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
        .result[] | 
        select(.type == "AAAA") |
        "  {\n    name     = \"" + .name + "\"\n    content  = \"" + .content + "\"\n    ttl      = " + (.ttl | tostring) + "\n    proxied  = " + (.proxied | tostring) + "\n    comment  = \"" + (.comment // "") + "\"\n  },"
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
        .result[] | 
        select(.type == "CNAME") |
        "  {\n    name     = \"" + .name + "\"\n    content  = \"" + .content + "\"\n    ttl      = " + (.ttl | tostring) + "\n    proxied  = " + (.proxied | tostring) + "\n    comment  = \"" + (.comment // "") + "\"\n  },"
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
        .result[] | 
        select(.type == "TXT") |
        "  {\n    name     = \"" + .name + "\"\n    content  = " + (.content | tostring) + "\n    ttl      = " + (.ttl | tostring) + "\n    comment  = \"" + (.comment // "") + "\"\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/txt_records.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/txt_records.tfvars"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/txt_records.tfvars" && rm -f "$OUTPUT_DIR/txt_records.tfvars.bak"
    
    echo "✅ Generated: txt_records.tfvars"
}

# Function to generate MX records
generate_mx_records() {
    echo "# MX Records" > "$OUTPUT_DIR/mx_records.tfvars"
    echo "mx_records = [" >> "$OUTPUT_DIR/mx_records.tfvars"
    
    jq -r '
        .result[] | 
        select(.type == "MX") |
        "  {\n    name     = \"" + .name + "\"\n    content  = \"" + .content + "\"\n    priority = " + (.priority | tostring) + "\n    ttl      = " + (.ttl | tostring) + "\n    comment  = \"" + (.comment // "") + "\"\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/mx_records.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/mx_records.tfvars"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/mx_records.tfvars" && rm -f "$OUTPUT_DIR/mx_records.tfvars.bak"
    
    echo "✅ Generated: mx_records.tfvars"
}

# Function to generate NS records (excluding root domain)
generate_ns_records() {
    echo "# NS Records (subdomain delegations)" > "$OUTPUT_DIR/ns_records.tfvars"
    echo "ns_records = [" >> "$OUTPUT_DIR/ns_records.tfvars"
    
    jq -r --arg domain "$DOMAIN_NAME" '
        .result[] | 
        select(.type == "NS" and .name != $domain) |
        "  {\n    name     = \"" + .name + "\"\n    content  = \"" + .content + "\"\n    ttl      = " + (.ttl | tostring) + "\n    comment  = \"" + (.comment // "") + "\"\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/ns_records.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/ns_records.tfvars"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/ns_records.tfvars" && rm -f "$OUTPUT_DIR/ns_records.tfvars.bak"
    
    echo "✅ Generated: ns_records.tfvars"
}

# Function to generate SRV records
generate_srv_records() {
    echo "# SRV Records" > "$OUTPUT_DIR/srv_records.tfvars"
    echo "srv_records = [" >> "$OUTPUT_DIR/srv_records.tfvars"
    
    jq -r '
        .result[] | 
        select(.type == "SRV") |
        "  {\n    name     = \"" + .name + "\"\n    priority = " + (.data.priority | tostring) + "\n    weight   = " + (.data.weight | tostring) + "\n    port     = " + (.data.port | tostring) + "\n    target   = \"" + .data.target + "\"\n    ttl      = " + (.ttl | tostring) + "\n    comment  = \"" + (.comment // "") + "\"\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/srv_records.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/srv_records.tfvars"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/srv_records.tfvars" && rm -f "$OUTPUT_DIR/srv_records.tfvars.bak"
    
    echo "✅ Generated: srv_records.tfvars"
}

# Function to generate PTR records
generate_ptr_records() {
    echo "# PTR Records (reverse DNS)" > "$OUTPUT_DIR/ptr_records.tfvars"
    echo "ptr_records = [" >> "$OUTPUT_DIR/ptr_records.tfvars"
    
    jq -r '
        .result[] | 
        select(.type == "PTR") |
        "  {\n    name     = \"" + .name + "\"\n    content  = \"" + .content + "\"\n    ttl      = " + (.ttl | tostring) + "\n    comment  = \"" + (.comment // "") + "\"\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/ptr_records.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/ptr_records.tfvars"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/ptr_records.tfvars" && rm -f "$OUTPUT_DIR/ptr_records.tfvars.bak"
    
    echo "✅ Generated: ptr_records.tfvars"
}

# Function to generate CAA records
generate_caa_records() {
    echo "# CAA Records" > "$OUTPUT_DIR/caa_records.tfvars"
    echo "caa_records = [" >> "$OUTPUT_DIR/caa_records.tfvars"
    
    jq -r '
        .result[] | 
        select(.type == "CAA") |
        "  {\n    name     = \"" + .name + "\"\n    flags    = " + (.data.flags | tostring) + "\n    tag      = \"" + .data.tag + "\"\n    value    = \"" + .data.value + "\"\n    ttl      = " + (.ttl | tostring) + "\n    comment  = \"" + (.comment // "") + "\"\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/caa_records.tfvars"
    
    echo "]" >> "$OUTPUT_DIR/caa_records.tfvars"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/caa_records.tfvars" && rm -f "$OUTPUT_DIR/caa_records.tfvars.bak"
    
    echo "✅ Generated: caa_records.tfvars"
}

# Function to generate generic records for less common types
generate_generic_records() {
    local record_type="$1"
    local filename="${record_type,,}_records.tfvars"
    
    echo "# $record_type Records" > "$OUTPUT_DIR/$filename"
    echo "${record_type,,}_records = [" >> "$OUTPUT_DIR/$filename"
    
    jq -r --arg type "$record_type" '
        .result[] | 
        select(.type == $type) |
        "  {\n    name     = \"" + .name + "\"\n    content  = \"" + .content + "\"\n    ttl      = " + (.ttl | tostring) + "\n    comment  = \"" + (.comment // "") + "\"\n  },"
    ' "$OUTPUT_DIR/temp_all_records.json" >> "$OUTPUT_DIR/$filename"
    
    echo "]" >> "$OUTPUT_DIR/$filename"
    sed -i.bak '$s/,$//' "$OUTPUT_DIR/$filename" && rm -f "$OUTPUT_DIR/$filename.bak"
    
    echo "✅ Generated: $filename"
}

# Generate files for ALL supported record types (placeholders if not in use)
ALL_SUPPORTED_TYPES="A AAAA CNAME TXT MX NS SRV PTR CAA"

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
        "SRV")
            generate_srv_records
            ;;
        "PTR")
            generate_ptr_records
            ;;
        "CAA")
            generate_caa_records
            ;;
        *)
            echo "⚠️  Unknown record type: $type (skipping)"
            ;;
    esac
done

# Check for any additional record types in the zone that we don't support
for type in $RECORD_TYPES; do
    if ! echo "$ALL_SUPPORTED_TYPES" | grep -q "$type"; then
        echo "⚠️  Found unsupported record type in zone: $type"
        echo "  Generating generic file for $type records..."
        generate_generic_records "$type"
    fi
done

# Generate configuration files
echo "📝 Generating configuration files..."

# Get zone information for configuration
ZONE_INFO=$(echo "$ZONE_RESPONSE" | jq -r '.result[0]')
ZONE_NAME=$(echo "$ZONE_INFO" | jq -r '.name')

cat > "$OUTPUT_DIR/domain.tfvars" << EOF
# Domain Configuration
domain_name = "$ZONE_NAME"
zone_id = "$ZONE_ID"
default_ttl = 300
EOF
echo "✅ Generated: domain.tfvars"

cat > "$OUTPUT_DIR/cloudflare.tfvars" << EOF
# Cloudflare Configuration
# Set your API token as an environment variable: export CLOUDFLARE_API_TOKEN=your-token-here
# Or uncomment and set the token below (not recommended for security)
# api_token = "your-cloudflare-api-token"
EOF
echo "✅ Generated: cloudflare.tfvars"

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
echo "5. Set your Cloudflare API token: export CLOUDFLARE_API_TOKEN=your-token"
echo "6. Resolve any naming conflicts or record collisions"
echo "7. Adjust any values as needed"
echo "8. Run terraform plan to verify the configuration"
echo ""
echo "💡 Note: Files are generated without '.auto' to prevent accidental"
echo "   overwrites and allow manual review before Terraform auto-loading."
echo ""
echo "🔐 Security reminder: Never commit your API token to version control!"