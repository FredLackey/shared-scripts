#!/bin/bash

# Script to delete DNS records that are NOT managed by Terraform based on configurable criteria
# Usage: ./cleanup-non-terraform-records.sh <cloudflare_token> [domains_file] [dry_run]

set -e

if [ $# -lt 1 ] || [[ "$1" =~ ^(-h|--help)$ ]]; then
    echo "Usage: $0 <cloudflare_token> [domains_file] [dry_run]"
    echo ""
    echo "Arguments:"
    echo "  cloudflare_token - Your Cloudflare API token (required)"
    echo "  domains_file     - Path to domains file (default: ../domains.txt)"
    echo "  dry_run         - Set to 'true' to preview without deleting (default: true)"
    echo ""
    echo "This script uses a 3-step filtering process:"
    echo "  1. Find all records matching specified types AND containing target strings"
    echo "  2. From those, identify which have required safe strings in comments"
    echo "  3. Delete only those WITHOUT required safe strings (unsafe records)"
    echo ""
    echo "Configurable criteria (edit script to modify):"
    echo "  - Record types: TXT, CNAME"
    echo "  - Target strings: spf, dmarc, ionos, workmail, _domainkey"
    echo "  - Required safe strings: terraform"
    echo ""
    echo "SAFETY: Uses dry-run mode by default. Set dry_run=false to actually delete."
    exit 0
fi

CLOUDFLARE_TOKEN="$1"
DOMAINS_FILE="${2:-../domains.txt}"
DRY_RUN="${3:-true}"

# ===================================
# CONFIGURATION ARRAYS
# ===================================

# Record types to check (case-insensitive)
RECORD_TYPES=("TXT" "CNAME" "MX")

# Target strings to look for in record content (case-insensitive)
# Records must contain at least one of these to be considered for cleanup
TARGET_STRINGS=(
    "spf"
    "dmarc"
    "ionos"
    "workmail"
    "_domainkey"
    "amazonses"
    "ses"
    "v=spf1"
    "v=DMARC1"
)

# Required content strings to look for in record comments (case-insensitive)
# Records containing any of these in comments will be considered SAFE and NOT deleted
REQUIRED_CONTENT_STRINGS=(
    "terraform"
)

# ===================================
# SCRIPT LOGIC
# ===================================

# Create log file with timestamp
LOG_FILE="dns-cleanup-$(date +%Y%m%d-%H%M%S).log"

echo "🧹 DNS Records Cleanup Script"
echo "============================="
echo "Domains file: $DOMAINS_FILE"
echo "Dry run mode: $DRY_RUN"
echo "Log file: $LOG_FILE"
echo ""
echo "🎯 Target Configuration:"
echo "Record types: ${RECORD_TYPES[*]}"
echo "Target strings: ${TARGET_STRINGS[*]}"
echo "Required safe strings: ${REQUIRED_CONTENT_STRINGS[*]}"
echo "" | tee "$LOG_FILE"

if [ ! -f "$DOMAINS_FILE" ]; then
    echo "❌ Error: Domains file not found: $DOMAINS_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

# Counters
processed_domains=0
total_records_found=0
terraform_managed=0
non_terraform_found=0
deleted_count=0
error_count=0

# Arrays to store record details for summary
declare -a safe_records=()
declare -a unsafe_records=()

echo "$(date): Starting DNS cleanup process" >> "$LOG_FILE"
echo "Target record types: ${RECORD_TYPES[*]}" >> "$LOG_FILE"
echo "Target content strings: ${TARGET_STRINGS[*]}" >> "$LOG_FILE"
echo "Required safe strings: ${REQUIRED_CONTENT_STRINGS[*]}" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Function to check if content contains any target string
contains_target_string() {
    local content="$1"
    for target in "${TARGET_STRINGS[@]}"; do
        if [[ "$content" =~ $target ]]; then
            return 0  # Found match
        fi
    done
    return 1  # No match found
}

# Function to check if record type is in target list
is_target_type() {
    local record_type="$1"
    for type in "${RECORD_TYPES[@]}"; do
        if [[ "${record_type^^}" == "${type^^}" ]]; then
            return 0  # Found match
        fi
    done
    return 1  # No match found
}

# Function to check if comment contains any required safe string
contains_required_string() {
    local comment="$1"
    for required in "${REQUIRED_CONTENT_STRINGS[@]}"; do
        # Convert both to lowercase for case-insensitive comparison
        local comment_lower=$(echo "$comment" | tr '[:upper:]' '[:lower:]')
        local required_lower=$(echo "$required" | tr '[:upper:]' '[:lower:]')
        if [[ "$comment_lower" =~ $required_lower ]]; then
            return 0  # Found match - record is SAFE
        fi
    done
    return 1  # No match found - record is NOT safe
}

# Read domains from file (skip comments and empty lines)
while IFS= read -r domain; do
    # Skip comments and empty lines
    if [[ "$domain" =~ ^[[:space:]]*# ]] || [[ -z "${domain// }" ]]; then
        continue
    fi
    
    domain=$(echo "$domain" | tr -d '\r\n' | xargs)
    ((processed_domains++))
    
    echo "🔍 [$processed_domains] Processing: $domain" | tee -a "$LOG_FILE"
    
    # Get zone ID
    zone_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type: application/json")
    
    zone_id=$(echo "$zone_response" | jq -r '.result[0].id // empty')
    
    if [ -z "$zone_id" ]; then
        echo "  ❌ Zone not found for $domain" | tee -a "$LOG_FILE"
        ((error_count++))
        continue
    fi
    
    # Get all DNS records for the domain
    for record_type in "${RECORD_TYPES[@]}"; do
        echo "  🔎 Checking $record_type records..." | tee -a "$LOG_FILE"
        
        records_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=$record_type" \
            -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
            -H "Content-Type: application/json")
        
        # Create temporary files for this domain to avoid subshell variable issues
        temp_safe="/tmp/safe_records_$$_$domain"
        temp_unsafe="/tmp/unsafe_records_$$_$domain"
        temp_counters="/tmp/counters_$$_$domain"
        
        # Process each record of this type
        echo "$records_response" | jq -c '.result[]' | while read -r record; do
            record_id=$(echo "$record" | jq -r '.id')
            record_name=$(echo "$record" | jq -r '.name')
            record_content=$(echo "$record" | jq -r '.content')
            record_comment=$(echo "$record" | jq -r '.comment // ""')
            record_type_actual=$(echo "$record" | jq -r '.type')
            
            # STEP 1: Check if content contains any target string (initial filtering)
            if contains_target_string "$record_content" || contains_target_string "$record_name"; then
                echo "    📋 Found Target Record: $record_id" | tee -a "$LOG_FILE"
                echo "       Type: $record_type_actual" | tee -a "$LOG_FILE"
                echo "       Name: $record_name" | tee -a "$LOG_FILE"
                echo "       Content: $record_content" | tee -a "$LOG_FILE"
                echo "       Comment: $record_comment" | tee -a "$LOG_FILE"
                
                # STEP 2: Check if comment contains any required safe string
                if contains_required_string "$record_comment"; then
                    echo "    ✅ SAFE (contains required string) - Skipping" | tee -a "$LOG_FILE"
                    echo "$domain|$record_type_actual|$record_name|SAFE" >> "$temp_safe"
                    echo "safe" >> "$temp_counters"
                else
                    echo "    🎯 UNSAFE (missing required string) - Target for deletion" | tee -a "$LOG_FILE"
                    echo "$domain|$record_type_actual|$record_name|DELETE" >> "$temp_unsafe"
                    echo "unsafe" >> "$temp_counters"
                    
                    if [ "$DRY_RUN" = "true" ]; then
                        echo "    🔍 DRY RUN - Would delete record $record_id" | tee -a "$LOG_FILE"
                    else
                        echo "    🗑️  DELETING record $record_id" | tee -a "$LOG_FILE"
                        
                        delete_response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
                            -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
                            -H "Content-Type: application/json")
                        
                        success=$(echo "$delete_response" | jq -r '.success // false')
                        
                        if [ "$success" = "true" ]; then
                            echo "       ✅ Successfully deleted" | tee -a "$LOG_FILE"
                            echo "deleted" >> "$temp_counters"
                        else
                            error_msg=$(echo "$delete_response" | jq -r '.errors[0].message // "Unknown error"')
                            echo "       ❌ Failed to delete: $error_msg" | tee -a "$LOG_FILE"
                            echo "error" >> "$temp_counters"
                        fi
                        
                        # Rate limiting - wait 100ms between deletions
                        sleep 0.1
                    fi
                fi
                
                echo "found" >> "$temp_counters"
                echo "" | tee -a "$LOG_FILE"
            fi
        done
        
        # Update counters from temp files
        if [ -f "$temp_counters" ]; then
            found_count=$(grep -c "found" "$temp_counters" 2>/dev/null | head -1 || echo "0")
            safe_count=$(grep -c "safe" "$temp_counters" 2>/dev/null | head -1 || echo "0")
            unsafe_count=$(grep -c "unsafe" "$temp_counters" 2>/dev/null | head -1 || echo "0")
            deleted_count_temp=$(grep -c "deleted" "$temp_counters" 2>/dev/null | head -1 || echo "0")
            error_count_temp=$(grep -c "error" "$temp_counters" 2>/dev/null | head -1 || echo "0")
            
            # Ensure we have valid numbers
            found_count=${found_count:-0}
            safe_count=${safe_count:-0}
            unsafe_count=${unsafe_count:-0}
            deleted_count_temp=${deleted_count_temp:-0}
            error_count_temp=${error_count_temp:-0}
            
            total_records_found=$((total_records_found + found_count))
            terraform_managed=$((terraform_managed + safe_count))
            non_terraform_found=$((non_terraform_found + unsafe_count))
            deleted_count=$((deleted_count + deleted_count_temp))
            error_count=$((error_count + error_count_temp))
        fi
        
        # Update record arrays from temp files
        if [ -f "$temp_safe" ]; then
            while IFS= read -r line; do
                safe_records+=("$line")
            done < "$temp_safe"
        fi
        
        if [ -f "$temp_unsafe" ]; then
            while IFS= read -r line; do
                unsafe_records+=("$line")
            done < "$temp_unsafe"
        fi
        
        # Clean up temp files
        rm -f "$temp_safe" "$temp_unsafe" "$temp_counters"
    done
    
    echo "" | tee -a "$LOG_FILE"
    
done < "$DOMAINS_FILE"

# Final summary
echo "🎉 DNS Cleanup Summary" | tee -a "$LOG_FILE"
echo "=====================" | tee -a "$LOG_FILE"
echo "Domains processed: $processed_domains" | tee -a "$LOG_FILE"
echo "Target records found: $total_records_found" | tee -a "$LOG_FILE"
echo "Safe records (kept): $terraform_managed" | tee -a "$LOG_FILE"
echo "Unsafe records found: $non_terraform_found" | tee -a "$LOG_FILE"

# Detailed record summaries
echo "" | tee -a "$LOG_FILE"
echo "📋 DETAILED RECORD SUMMARY" | tee -a "$LOG_FILE"
echo "=========================" | tee -a "$LOG_FILE"

if [ ${#safe_records[@]} -gt 0 ]; then
    echo "" | tee -a "$LOG_FILE"
    echo "✅ SAFE RECORDS (will be kept):" | tee -a "$LOG_FILE"
    printf "%-25s %-8s %-50s %s\n" "DOMAIN" "TYPE" "RECORD NAME" "STATUS" | tee -a "$LOG_FILE"
    printf "%-25s %-8s %-50s %s\n" "$(printf "%0.s-" {1..25})" "$(printf "%0.s-" {1..8})" "$(printf "%0.s-" {1..50})" "$(printf "%0.s-" {1..10})" | tee -a "$LOG_FILE"
    for record in "${safe_records[@]}"; do
        IFS='|' read -r domain type name status <<< "$record"
        printf "%-25s %-8s %-50s %s\n" "$domain" "$type" "$name" "$status" | tee -a "$LOG_FILE"
    done
fi

if [ ${#unsafe_records[@]} -gt 0 ]; then
    echo "" | tee -a "$LOG_FILE"
    echo "🎯 UNSAFE RECORDS (will be deleted):" | tee -a "$LOG_FILE"
    printf "%-25s %-8s %-50s %s\n" "DOMAIN" "TYPE" "RECORD NAME" "STATUS" | tee -a "$LOG_FILE"
    printf "%-25s %-8s %-50s %s\n" "$(printf "%0.s-" {1..25})" "$(printf "%0.s-" {1..8})" "$(printf "%0.s-" {1..50})" "$(printf "%0.s-" {1..10})" | tee -a "$LOG_FILE"
    for record in "${unsafe_records[@]}"; do
        IFS='|' read -r domain type name status <<< "$record"
        printf "%-25s %-8s %-50s %s\n" "$domain" "$type" "$name" "$status" | tee -a "$LOG_FILE"
    done
else
    echo "" | tee -a "$LOG_FILE"
    echo "🎉 No unsafe records found! All target records are properly managed." | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"

if [ "$DRY_RUN" = "true" ]; then
    echo "Records that WOULD be deleted: $non_terraform_found" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "🔄 To actually delete, run:" | tee -a "$LOG_FILE"
    echo "   $0 $CLOUDFLARE_TOKEN $DOMAINS_FILE false" | tee -a "$LOG_FILE"
else
    echo "Records successfully deleted: $deleted_count" | tee -a "$LOG_FILE"
    echo "Errors encountered: $error_count" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "📄 Complete log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "$(date): DNS cleanup process completed" >> "$LOG_FILE"

# Show configuration for easy modification
echo "" | tee -a "$LOG_FILE"
echo "💡 To modify target criteria, edit arrays in script:" | tee -a "$LOG_FILE"
echo "   RECORD_TYPES=(\"TXT\" \"CNAME\" \"A\" \"AAAA\")" | tee -a "$LOG_FILE"
echo "   TARGET_STRINGS=(\"spf\" \"dmarc\" \"ionos\" \"custom_string\")" | tee -a "$LOG_FILE"
echo "   REQUIRED_CONTENT_STRINGS=(\"terraform\" \"managed\")" | tee -a "$LOG_FILE"
