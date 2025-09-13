#!/bin/bash

# Find Ubuntu AMIs in a specified AWS region using the AWS CLI
# This script discovers available Ubuntu images for Moodle deployment

set -euo pipefail

# Default values
PROFILE=""
REGION=""
UBUNTU_VERSION=""
ARCHITECTURE="all"
OUTPUT_FORMAT="table"
LATEST_ONLY=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}$1${NC}" >&2
}

log_warn() {
    echo -e "${YELLOW}$1${NC}" >&2
}

log_error() {
    echo -e "${RED}$1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}$1${NC}" >&2
}

# Usage function
usage() {
    cat << EOF
Usage: $0 -p <aws-profile> -r <aws-region> [options]

Find Ubuntu AMIs available in the specified AWS region.

Required arguments:
  -p, --profile <profile>    AWS SSO profile name (e.g., cvle-dev, cvle-prod, cvle-sandbox, cvle-mgmt)
  -r, --region <region>      AWS region (e.g., us-east-1, us-west-2)

Optional arguments:
  -v, --ubuntu-version <ver> Ubuntu version (20/20.04, 22/22.04, 24/24.04, or 'all' for all versions) (default: all)
  -a, --architecture <arch>  Architecture (x86/x86_64/amd64, arm/arm64, or 'all') (default: all)
  -f, --format <format>      Output format (table, json, text) (default: table)
  -l, --latest-only          Show only the most recent AMI for each Ubuntu version
  -h, --help                Show this help message

Examples:
  $0 -p cvle-dev -r us-east-1
  $0 --profile cvle-prod --region us-east-1 -v 22.04 -f json
  $0 -p cvle-mgmt -r us-west-2 -a arm
  $0 -p cvle-flackey -r us-gov-west-1 -v 22 -a x86 -l
EOF
}

# Parse command line arguments
parse_args() {
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
            -v|--ubuntu-version)
                UBUNTU_VERSION="$2"
                shift 2
                ;;
            -a|--architecture)
                ARCHITECTURE="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -l|--latest-only)
                LATEST_ONLY=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$PROFILE" ]]; then
        log_error "AWS profile is required. Use --profile <profile-name>"
        usage
        exit 1
    fi

    if [[ -z "$REGION" ]]; then
        log_error "AWS region is required. Use --region <region-name>"
        usage
        exit 1
    fi

    # Set default Ubuntu version if not specified
    if [[ -z "$UBUNTU_VERSION" ]]; then
        UBUNTU_VERSION="all"
    fi

    # Validate output format
    if [[ "$OUTPUT_FORMAT" != "table" && "$OUTPUT_FORMAT" != "json" && "$OUTPUT_FORMAT" != "text" ]]; then
        log_error "Invalid output format. Must be 'table', 'json', or 'text'"
        exit 1
    fi
}

# Check AWS authentication
check_aws_auth() {
    log_info "Checking AWS authentication for profile '$PROFILE' in region '$REGION'..."
    
    if ! aws sts get-caller-identity --profile "$PROFILE" --region "$REGION" &> /dev/null; then
        log_warn "Not authenticated with AWS. Attempting SSO login..."
        
        if ! aws sso login --profile "$PROFILE"; then
            log_error "Failed to authenticate with AWS SSO"
            exit 1
        fi
        
        # Verify authentication worked
        if ! aws sts get-caller-identity --profile "$PROFILE" --region "$REGION" &> /dev/null; then
            log_error "Authentication failed. Please check your AWS SSO configuration."
            exit 1
        fi
    fi
    
    ACCOUNT_INFO=$(aws sts get-caller-identity --profile "$PROFILE" --region "$REGION" --output json)
    ACCOUNT_ID=$(echo "$ACCOUNT_INFO" | jq -r '.Account')
    
    log_success "Successfully authenticated as account: $ACCOUNT_ID"
}

# Determine Ubuntu owner IDs based on region type
get_ubuntu_owner_ids() {
    if [[ "$REGION" =~ ^us-gov- ]]; then
        # AWS GovCloud regions use different owner ID
        echo "513442679011"
    else
        # Commercial AWS regions use canonical Ubuntu owner ID
        echo "099720109477"
    fi
}

# Find Ubuntu AMIs
find_ubuntu_amis() {
    log_info "Searching for Ubuntu AMIs in region '$REGION'..."
    
    # Get the appropriate Ubuntu owner IDs for this region
    local ubuntu_owner_ids
    ubuntu_owner_ids=$(get_ubuntu_owner_ids)
    
    log_info "Using Ubuntu owner IDs: $ubuntu_owner_ids"
    
    # Build name filters based on Ubuntu version
    local name_patterns=()
    
    # Add Ubuntu 22.04 (Jammy) patterns
    if [[ "$UBUNTU_VERSION" == "all" || "$UBUNTU_VERSION" == "22.04" || "$UBUNTU_VERSION" == "22" ]]; then
        name_patterns+=("ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-*")
    fi
    
    # Add Ubuntu 24.04 (Noble) patterns
    if [[ "$UBUNTU_VERSION" == "all" || "$UBUNTU_VERSION" == "24.04" || "$UBUNTU_VERSION" == "24" ]]; then
        name_patterns+=("ubuntu/images/hvm-ssd/ubuntu-noble-24.04-*")
        name_patterns+=("ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-*")
    fi
    
    # Add Ubuntu 20.04 (Focal) patterns for completeness
    if [[ "$UBUNTU_VERSION" == "all" || "$UBUNTU_VERSION" == "20.04" || "$UBUNTU_VERSION" == "20" ]]; then
        name_patterns+=("ubuntu/images/hvm-ssd/ubuntu-focal-20.04-*")
    fi
    
    # If no patterns were added, default to all
    if [[ ${#name_patterns[@]} -eq 0 ]]; then
        log_warn "No matching Ubuntu version found for '$UBUNTU_VERSION'. Defaulting to all versions."
        name_patterns+=("ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-*")
        name_patterns+=("ubuntu/images/hvm-ssd/ubuntu-noble-24.04-*")
        name_patterns+=("ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-*")
        name_patterns+=("ubuntu/images/hvm-ssd/ubuntu-focal-20.04-*")
    fi
    
    # Search for each name pattern
    local all_amis=()
    
    for name_pattern in "${name_patterns[@]}"; do
        log_info "Searching for pattern: $name_pattern"
        
        # Build architecture filter for the AWS CLI filters
        local arch_filters=()
        local aws_arch="$ARCHITECTURE"
        
        # Convert shorthand architecture names to AWS format
        case "$ARCHITECTURE" in
            "x86"|"amd64")
                aws_arch="x86_64"
                ;;
            "arm")
                aws_arch="arm64"
                ;;
        esac
        
        if [[ "$ARCHITECTURE" == "all" ]]; then
            arch_filters=("Name=architecture,Values=x86_64,arm64")
        else
            arch_filters=("Name=architecture,Values=$aws_arch")
        fi
        
        local amis
        amis=$(aws ec2 describe-images \
            --profile "$PROFILE" \
            --region "$REGION" \
            --owners $ubuntu_owner_ids \
            --filters "Name=name,Values=$name_pattern" "Name=state,Values=available" "${arch_filters[@]}" \
            --query 'Images[].{ImageId:ImageId,Name:Name,CreationDate:CreationDate,Architecture:Architecture,Description:Description}' \
            --output json)
        
        # Add to all_amis array if results found
        if [[ "$amis" != "[]" && "$amis" != "null" ]]; then
            all_amis+=("$amis")
        fi
    done
    
    # Combine all results
    if [[ ${#all_amis[@]} -eq 0 ]]; then
        log_warn "No Ubuntu AMIs found matching the specified criteria"
        return 0
    fi
    
    # Merge all AMI arrays and sort by creation date (newest first)
    local combined_amis
    combined_amis=$(printf '%s\n' "${all_amis[@]}" | jq -s 'add | sort_by(.CreationDate) | reverse')
    
    # Filter to latest only if requested
    if [[ "$LATEST_ONLY" == "true" ]]; then
        combined_amis=$(echo "$combined_amis" | jq 'group_by(.Name | sub("ubuntu/images/hvm-ssd(-gp3)?/"; "") | sub("-[0-9]{8}.*"; "")) | map(.[0]) | sort_by(.CreationDate) | reverse')
    fi
    
    # Output results
    case "$OUTPUT_FORMAT" in
        "json")
            echo "$combined_amis" | jq '.'
            ;;
        "text")
            echo "$combined_amis" | jq -r '.[] | "\(.ImageId)\t\(.Name | sub("ubuntu/images/hvm-ssd(-gp3)?/"; ""))\t\(.CreationDate)\t\(.Architecture)"'
            ;;
        "table"|*)
            echo ""
            log_success "Found $(echo "$combined_amis" | jq 'length') Ubuntu AMIs:"
            echo ""
            
            # Show the newest (recommended) AMI first
            local newest_ami
            newest_ami=$(echo "$combined_amis" | jq -r '.[0]')
            local newest_id newest_name newest_date newest_arch
            newest_id=$(echo "$newest_ami" | jq -r '.ImageId')
            newest_name=$(echo "$newest_ami" | jq -r '.Name | sub("ubuntu/images/hvm-ssd(-gp3)?/"; "")')
            newest_date=$(echo "$newest_ami" | jq -r '.CreationDate')
            newest_arch=$(echo "$newest_ami" | jq -r '.Architecture')
            
            echo -e "${GREEN}📋 RECOMMENDED (Latest):${NC}"
            printf "%-20s %-45s %-25s %-12s\n" "IMAGE ID" "NAME" "CREATION DATE" "ARCHITECTURE"
            printf "%-20s %-45s %-25s %-12s\n" "--------" "----" "-------------" "------------"
            printf "%-20s %-45s %-25s %-12s\n" "$newest_id" "$newest_name" "$newest_date" "$newest_arch"
            echo ""
            
            # Show count by Ubuntu version
            echo -e "${BLUE}📊 SUMMARY BY VERSION:${NC}"
            echo "$combined_amis" | jq -r '.[] | .Name | sub("ubuntu/images/hvm-ssd(-gp3)?/"; "") | sub("-.*"; "")' | sort | uniq -c | while read count version; do
                printf "  %-25s %s AMIs\n" "$version" "$count"
            done
            echo ""
            
            echo -e "${YELLOW}💡 TIP: Use the RECOMMENDED AMI above for latest security updates${NC}"
            echo -e "${YELLOW}    All AMIs are official Canonical builds with monthly security patches${NC}"
            echo ""
            
            # Show all AMIs if user wants full list
            if [[ $(echo "$combined_amis" | jq 'length') -gt 10 ]]; then
                echo -e "${BLUE}📝 COMPLETE LIST (newest first):${NC}"
            fi
            printf "%-20s %-45s %-25s %-12s\n" "IMAGE ID" "NAME" "CREATION DATE" "ARCHITECTURE"
            printf "%-20s %-45s %-25s %-12s\n" "--------" "----" "-------------" "------------"
            echo "$combined_amis" | jq -r '.[] | "\(.ImageId)\t\(.Name | sub("ubuntu/images/hvm-ssd(-gp3)?/"; ""))\t\(.CreationDate)\t\(.Architecture)"' | \
            while IFS=$'\t' read -r image_id name creation_date arch; do
                printf "%-20s %-45s %-25s %-12s\n" "$image_id" "$name" "$creation_date" "$arch"
            done
            echo ""
            ;;
    esac
}

main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Check AWS authentication
    check_aws_auth
    
    # Find Ubuntu AMIs
    find_ubuntu_amis
    
    log_success "Ubuntu AMI search completed successfully"
}

main "$@"