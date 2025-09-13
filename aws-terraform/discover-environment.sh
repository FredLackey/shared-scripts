#!/bin/bash
  
  # Discover all information about an AWS account needed for installing the Moodle LMS server.
  # This includes the VPC, the subnets, and any existing EC2 instances.
  # This will be used to make use of an existing VPC to deploy a new Ubuntu server into for hosting Moodle.

set -euo pipefail

# Default values
PROFILE=""
REGION=""
OUTPUT_FILE="aws-environment.json"
OVERWRITE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions (no prefixes for clean output)
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
Usage: $0 --profile <aws-profile> --region <aws-region> [--output <output-file>] [--overwrite]

Discover AWS environment information for Moodle deployment.

Required arguments:
  --profile <profile>    AWS SSO profile name (e.g., cvle-dev, cvle-prod, cvle-sandbox, cvle-mgmt)
  --region <region>      AWS region (e.g., us-east-1, us-west-2)

Optional arguments:
  --output <file>        Output JSON file path (default: aws-environment.json)
  --overwrite           Overwrite existing output file (default: reuse existing file if present)
  -h, --help            Show this help message

Examples:
  $0 --profile cvle-dev --region us-east-1
  $0 --profile cvle-prod --region us-east-1 --output prod-env.json --overwrite
  $0 --profile cvle-dev --region us-east-1  # Reuses existing aws-environment.json if present
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --region)
                REGION="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --overwrite)
                OVERWRITE=true
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
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    log_info "AWS CLI found: $(aws --version)"
}

# Check and refresh AWS SSO session
check_aws_session() {
    log_info "Checking AWS SSO session for profile: $PROFILE"
    
    # Try to get caller identity to test session
    if ! aws sts get-caller-identity --profile "$PROFILE" --region "$REGION" &> /dev/null; then
        log_warn "AWS SSO session is invalid or expired. Initiating login..."
        
        # Attempt SSO login
        if ! aws sso login --profile "$PROFILE"; then
            log_error "Failed to authenticate with AWS SSO"
            exit 1
        fi
        
        # Verify session after login
        if ! aws sts get-caller-identity --profile "$PROFILE" --region "$REGION" &> /dev/null; then
            log_error "Authentication failed even after SSO login"
            exit 1
        fi
    fi
    
    # Get and display account information
    ACCOUNT_INFO=$(aws sts get-caller-identity --profile "$PROFILE" --region "$REGION" --output json)
    ACCOUNT_ID=$(echo "$ACCOUNT_INFO" | jq -r '.Account')
    USER_ARN=$(echo "$ACCOUNT_INFO" | jq -r '.Arn')
    
    log_success "Authenticated successfully"
    log_info "Account ID: $ACCOUNT_ID"
    log_info "User ARN: $USER_ARN"
}

# Discover VPC information
discover_vpcs() {
    log_info "Discovering VPCs in region $REGION..."
    
    local vpcs_json
    vpcs_json=$(aws ec2 describe-vpcs \
        --profile "$PROFILE" \
        --region "$REGION" \
        --output json)
    
    echo "$vpcs_json"
}

# Discover subnets for a given VPC
discover_subnets() {
    local vpc_id="$1"
    log_info "Discovering subnets for VPC: $vpc_id"
    
    local subnets_json
    subnets_json=$(aws ec2 describe-subnets \
        --profile "$PROFILE" \
        --region "$REGION" \
        --filters "Name=vpc-id,Values=$vpc_id" \
        --output json)
    
    echo "$subnets_json"
}

# Discover security groups for a given VPC
discover_security_groups() {
    local vpc_id="$1"
    log_info "Discovering security groups for VPC: $vpc_id"
    
    local sgs_json
    sgs_json=$(aws ec2 describe-security-groups \
        --profile "$PROFILE" \
        --region "$REGION" \
        --filters "Name=vpc-id,Values=$vpc_id" \
        --output json)
    
    echo "$sgs_json"
}

# Discover EC2 instances
discover_ec2_instances() {
    log_info "Discovering EC2 instances in region $REGION..."
    
    local instances_json
    instances_json=$(aws ec2 describe-instances \
        --profile "$PROFILE" \
        --region "$REGION" \
        --output json)
    
    echo "$instances_json"
}

# Discover internet gateways
discover_internet_gateways() {
    log_info "Discovering internet gateways in region $REGION..."
    
    local igws_json
    igws_json=$(aws ec2 describe-internet-gateways \
        --profile "$PROFILE" \
        --region "$REGION" \
        --output json)
    
    echo "$igws_json"
}

# Discover route tables
discover_route_tables() {
    local vpc_id="$1"
    log_info "Discovering route tables for VPC: $vpc_id"
    
    local rt_json
    rt_json=$(aws ec2 describe-route-tables \
        --profile "$PROFILE" \
        --region "$REGION" \
        --filters "Name=vpc-id,Values=$vpc_id" \
        --output json)
    
    echo "$rt_json"
}

# Discover NAT gateways
discover_nat_gateways() {
    local vpc_id="$1"
    log_info "Discovering NAT gateways for VPC: $vpc_id"
    
    local nat_json
    nat_json=$(aws ec2 describe-nat-gateways \
        --profile "$PROFILE" \
        --region "$REGION" \
        --filter "Name=vpc-id,Values=$vpc_id" \
        --output json)
    
    echo "$nat_json"
}

# Format security group rule for display
format_sg_rule() {
    local rule="$1"
    local rule_type="$2"  # "Ingress" or "Egress"
    
    local protocol port_range source_dest description
    protocol=$(echo "$rule" | jq -r '.IpProtocol')
    
    # Handle port ranges
    if [[ "$protocol" == "-1" ]]; then
        port_range="All"
    else
        local from_port to_port
        from_port=$(echo "$rule" | jq -r '.FromPort // empty')
        to_port=$(echo "$rule" | jq -r '.ToPort // empty')
        
        if [[ -n "$from_port" && -n "$to_port" ]]; then
            if [[ "$from_port" == "$to_port" ]]; then
                port_range="$from_port"
            else
                port_range="$from_port-$to_port"
            fi
        else
            port_range="All"
        fi
    fi
    
    # Handle protocol display
    case "$protocol" in
        "-1") protocol="All" ;;
        "6") protocol="TCP" ;;
        "17") protocol="UDP" ;;
        "1") protocol="ICMP" ;;
        *) protocol="$protocol" ;;
    esac
    
    # Handle sources/destinations
    local ip_ranges group_refs prefix_lists sources
    ip_ranges=$(echo "$rule" | jq -r '.IpRanges[]?.CidrIp // empty' | tr '\n' ',' | sed 's/,$//')
    group_refs=$(echo "$rule" | jq -r '.UserIdGroupPairs[]? | "\(.GroupId // .GroupName // "Unknown")" + (if .Description then " (\(.Description))" else "" end)' | tr '\n' ',' | sed 's/,$//')
    prefix_lists=$(echo "$rule" | jq -r '.PrefixListIds[]?.PrefixListId // empty' | tr '\n' ',' | sed 's/,$//')
    
    # Combine all sources
    sources=""
    [[ -n "$ip_ranges" ]] && sources="$ip_ranges"
    [[ -n "$group_refs" ]] && sources="${sources:+$sources, }$group_refs"
    [[ -n "$prefix_lists" ]] && sources="${sources:+$sources, }$prefix_lists"
    [[ -z "$sources" ]] && sources="None"
    
    # Get rule description if available
    description=$(echo "$rule" | jq -r '.Description // empty')
    [[ -n "$description" ]] && description=" - $description"
    
    echo "$rule_type: $protocol:$port_range from/to $sources$description"
}

# Display security group rules
display_sg_rules() {
    local sg_data="$1"
    local sg_id="$2"
    local indent="$3"
    
    # Get ingress rules
    local ingress_count
    ingress_count=$(echo "$sg_data" | jq ".SecurityGroups[] | select(.GroupId == \"$sg_id\") | .IpPermissions | length")
    
    if [[ $ingress_count -gt 0 ]]; then
        echo -e "${BLUE}${indent}    ├─ Ingress Rules: $ingress_count${NC}"
        local rules
        rules=$(echo "$sg_data" | jq -c ".SecurityGroups[] | select(.GroupId == \"$sg_id\") | .IpPermissions[]")
        
        local rule_num=0
        while IFS= read -r rule; do
            [[ -z "$rule" ]] && continue
            ((rule_num++))
            local formatted_rule
            formatted_rule=$(format_sg_rule "$rule" "In")
            
            if [[ $rule_num -eq $ingress_count ]]; then
                echo -e "${BLUE}${indent}    │  └─ $formatted_rule${NC}"
            else
                echo -e "${BLUE}${indent}    │  ├─ $formatted_rule${NC}"
            fi
        done <<< "$rules"
    fi
    
    # Get egress rules
    local egress_count
    egress_count=$(echo "$sg_data" | jq ".SecurityGroups[] | select(.GroupId == \"$sg_id\") | .IpPermissionsEgress | length")
    
    if [[ $egress_count -gt 0 ]]; then
        if [[ $ingress_count -gt 0 ]]; then
            echo -e "${BLUE}${indent}    └─ Egress Rules: $egress_count${NC}"
        else
            echo -e "${BLUE}${indent}    ├─ Egress Rules: $egress_count${NC}"
        fi
        
        local egress_rules
        egress_rules=$(echo "$sg_data" | jq -c ".SecurityGroups[] | select(.GroupId == \"$sg_id\") | .IpPermissionsEgress[]")
        
        local egress_rule_num=0
        while IFS= read -r rule; do
            [[ -z "$rule" ]] && continue
            ((egress_rule_num++))
            local formatted_rule
            formatted_rule=$(format_sg_rule "$rule" "Out")
            
            if [[ $egress_rule_num -eq $egress_count ]]; then
                echo -e "${BLUE}${indent}       └─ $formatted_rule${NC}"
            else
                echo -e "${BLUE}${indent}       ├─ $formatted_rule${NC}"
            fi
        done <<< "$egress_rules"
    fi
}

# Determine if a subnet is public or private based on route tables
determine_subnet_type() {
    local subnet_id="$1"
    local vpc_route_tables="$2"
    
    # Check if subnet has explicit route table association
    local associated_rt_id
    associated_rt_id=$(echo "$vpc_route_tables" | jq -r ".RouteTables[] | select(.Associations[]?.SubnetId == \"$subnet_id\") | .RouteTableId" | head -1)
    
    # If no explicit association, use the main route table for the VPC
    if [[ -z "$associated_rt_id" || "$associated_rt_id" == "null" ]]; then
        associated_rt_id=$(echo "$vpc_route_tables" | jq -r '.RouteTables[] | select(.Associations[]?.Main == true) | .RouteTableId')
    fi
    
    # Check if the route table has a route to an Internet Gateway (0.0.0.0/0 -> igw-*)
    local has_igw_route
    has_igw_route=$(echo "$vpc_route_tables" | jq -r ".RouteTables[] | select(.RouteTableId == \"$associated_rt_id\") | .Routes[] | select(.DestinationCidrBlock == \"0.0.0.0/0\" and (.GatewayId // empty | startswith(\"igw-\"))) | .GatewayId" | head -1)
    
    if [[ -n "$has_igw_route" && "$has_igw_route" != "null" ]]; then
        echo "Public"
    else
        echo "Private"
    fi
}

# Discover key pairs
discover_key_pairs() {
    log_info "Discovering EC2 key pairs in region $REGION..."
    
    local keys_json
    keys_json=$(aws ec2 describe-key-pairs \
        --profile "$PROFILE" \
        --region "$REGION" \
        --output json)
    
    echo "$keys_json"
}

# Discover Elastic IPs
discover_elastic_ips() {
    log_info "Discovering Elastic IPs in region $REGION..."
    
    local eips_json
    eips_json=$(aws ec2 describe-addresses \
        --profile "$PROFILE" \
        --region "$REGION" \
        --output json)
    
    echo "$eips_json"
}

# Display basic summary with counts
display_basic_summary() {
    local output_file="$1"
    local reused="${2:-false}"
    
    if [[ "$reused" == "true" ]]; then
        log_success "Using existing environment data"
        log_info "Data loaded from: $output_file"
    else
        log_success "Environment discovery completed successfully"
        log_info "Output written to: $output_file"
    fi
    
    # Display basic summary
    local vpc_count instance_count subnet_count sg_count key_count igw_count eip_count public_subnet_count private_subnet_count
    vpc_count=$(jq '.vpcs | length' "$output_file")
    instance_count=$(jq '.ec2_instances.Reservations | map(.Instances | length) | add // 0' "$output_file")
    subnet_count=$(jq '.vpcs | map(.subnets.Subnets | length) | add // 0' "$output_file")
    sg_count=$(jq '.vpcs | map(.security_groups.SecurityGroups | length) | add // 0' "$output_file")
    key_count=$(jq '.key_pairs.KeyPairs | length' "$output_file")
    igw_count=$(jq '.internet_gateways.InternetGateways | length' "$output_file")
    eip_count=$(jq '.elastic_ips.Addresses | length' "$output_file")
    
    # Count public vs private subnets
    public_subnet_count=0
    private_subnet_count=0
    for ((i=0; i<vpc_count; i++)); do
        local vpc_subnets_count
        vpc_subnets_count=$(jq ".vpcs[$i].subnets.Subnets | length" "$output_file")
        for ((j=0; j<vpc_subnets_count; j++)); do
            local subnet_id subnet_type vpc_route_tables
            subnet_id=$(jq -r ".vpcs[$i].subnets.Subnets[$j].SubnetId" "$output_file")
            vpc_route_tables=$(jq ".vpcs[$i].route_tables" "$output_file")
            subnet_type=$(determine_subnet_type "$subnet_id" "$vpc_route_tables")
            
            if [[ "$subnet_type" == "Public" ]]; then
                ((public_subnet_count++))
            else
                ((private_subnet_count++))
            fi
        done
    done
    
    log_info "Basic Summary:"
    log_info "  - VPCs discovered: $vpc_count"
    log_info "  - Subnets discovered: $subnet_count (Public: $public_subnet_count, Private: $private_subnet_count)"
    log_info "  - Security Groups discovered: $sg_count"
    log_info "  - EC2 instances discovered: $instance_count"
    log_info "  - Key pairs discovered: $key_count"
    log_info "  - Internet gateways discovered: $igw_count"
    log_info "  - Elastic IPs discovered: $eip_count"
    log_info "  - Region: $REGION"
    log_info "  - Profile: $PROFILE"
}

# Display detailed summary with resource names
display_detailed_summary() {
    local output_file="$1"
    
    echo ""
    echo -e "${GREEN}=== DETAILED ENVIRONMENT SUMMARY ===${NC}"
    echo ""
    
    # Account information
    local account_id profile region discovery_time
    account_id=$(jq -r '.discovery_metadata.account.Account' "$output_file")
    profile=$(jq -r '.discovery_metadata.profile' "$output_file")
    region=$(jq -r '.discovery_metadata.region' "$output_file")
    discovery_time=$(jq -r '.discovery_metadata.discovery_time' "$output_file")
    
    echo -e "${BLUE}Account ID: $account_id${NC}"
    echo -e "${BLUE}Profile: $profile${NC}"
    echo -e "${BLUE}Region: $region${NC}"
    echo -e "${BLUE}Discovery Time: $discovery_time${NC}"
    echo ""
    
    # VPCs and their resources
    local vpc_count
    vpc_count=$(jq '.vpcs | length' "$output_file")
    echo -e "${GREEN}VPCs Found: $vpc_count${NC}"
    
    for ((i=0; i<vpc_count; i++)); do
        local vpc_id vpc_name vpc_cidr
        vpc_id=$(jq -r ".vpcs[$i].vpc.VpcId" "$output_file")
        vpc_name=$(jq -r ".vpcs[$i].vpc.Tags[]? | select(.Key==\"Name\") | .Value" "$output_file" 2>/dev/null || echo "No Name Tag")
        vpc_cidr=$(jq -r ".vpcs[$i].vpc.CidrBlock" "$output_file")
        
        echo -e "${BLUE}  ├─ VPC: $vpc_name ($vpc_id) - $vpc_cidr${NC}"
        
        # Subnets in this VPC
        local subnet_count
        subnet_count=$(jq ".vpcs[$i].subnets.Subnets | length" "$output_file")
        echo -e "${BLUE}  │  ├─ Subnets: $subnet_count${NC}"
        
        for ((j=0; j<subnet_count; j++)); do
            local subnet_id subnet_name subnet_cidr subnet_az subnet_type
            subnet_id=$(jq -r ".vpcs[$i].subnets.Subnets[$j].SubnetId" "$output_file")
            subnet_name=$(jq -r ".vpcs[$i].subnets.Subnets[$j].Tags[]? | select(.Key==\"Name\") | .Value" "$output_file" 2>/dev/null || echo "No Name Tag")
            subnet_cidr=$(jq -r ".vpcs[$i].subnets.Subnets[$j].CidrBlock" "$output_file")
            subnet_az=$(jq -r ".vpcs[$i].subnets.Subnets[$j].AvailabilityZone" "$output_file")
            
            # Get route tables for this VPC to determine subnet type
            local vpc_route_tables
            vpc_route_tables=$(jq ".vpcs[$i].route_tables" "$output_file")
            subnet_type=$(determine_subnet_type "$subnet_id" "$vpc_route_tables")
            
            if [[ $j -eq $((subnet_count-1)) ]]; then
                echo -e "${BLUE}  │  │  └─ $subnet_name ($subnet_id) - $subnet_cidr [$subnet_az] ($subnet_type)${NC}"
            else
                echo -e "${BLUE}  │  │  ├─ $subnet_name ($subnet_id) - $subnet_cidr [$subnet_az] ($subnet_type)${NC}"
            fi
        done
        
        # Security Groups in this VPC
        local sg_count
        sg_count=$(jq ".vpcs[$i].security_groups.SecurityGroups | length" "$output_file")
        echo -e "${BLUE}  │  ├─ Security Groups: $sg_count${NC}"
        
        for ((k=0; k<sg_count; k++)); do
            local sg_id sg_name sg_description
            sg_id=$(jq -r ".vpcs[$i].security_groups.SecurityGroups[$k].GroupId" "$output_file")
            sg_name=$(jq -r ".vpcs[$i].security_groups.SecurityGroups[$k].Tags[]? | select(.Key==\"Name\") | .Value" "$output_file" 2>/dev/null || jq -r ".vpcs[$i].security_groups.SecurityGroups[$k].GroupName" "$output_file")
            sg_description=$(jq -r ".vpcs[$i].security_groups.SecurityGroups[$k].Description" "$output_file")
            
            if [[ $k -eq $((sg_count-1)) ]]; then
                echo -e "${BLUE}  │  │  └─ $sg_name ($sg_id) - $sg_description${NC}"
                # Display rules for this security group
                local sg_data
                sg_data=$(jq ".vpcs[$i].security_groups" "$output_file")
                display_sg_rules "$sg_data" "$sg_id" "  │  │  "
            else
                echo -e "${BLUE}  │  │  ├─ $sg_name ($sg_id) - $sg_description${NC}"
                # Display rules for this security group
                local sg_data
                sg_data=$(jq ".vpcs[$i].security_groups" "$output_file")
                display_sg_rules "$sg_data" "$sg_id" "  │  │  "
            fi
        done
        
        # NAT Gateways in this VPC
        local nat_count
        nat_count=$(jq ".vpcs[$i].nat_gateways.NatGateways | length" "$output_file")
        if [[ $nat_count -gt 0 ]]; then
            echo -e "${BLUE}  │  └─ NAT Gateways: $nat_count${NC}"
            for ((n=0; n<nat_count; n++)); do
                local nat_id nat_state
                nat_id=$(jq -r ".vpcs[$i].nat_gateways.NatGateways[$n].NatGatewayId" "$output_file")
                nat_state=$(jq -r ".vpcs[$i].nat_gateways.NatGateways[$n].State" "$output_file")
                
                if [[ $n -eq $((nat_count-1)) ]]; then
                    echo -e "${BLUE}  │     └─ $nat_id ($nat_state)${NC}"
                else
                    echo -e "${BLUE}  │     ├─ $nat_id ($nat_state)${NC}"
                fi
            done
        else
            echo -e "${BLUE}  │  └─ NAT Gateways: 0${NC}"
        fi
        
        if [[ $i -lt $((vpc_count-1)) ]]; then
            echo -e "${BLUE}  │${NC}"
        fi
    done
    
    echo ""
    
    # EC2 Instances
    local instance_count
    instance_count=$(jq '.ec2_instances.Reservations | map(.Instances | length) | add // 0' "$output_file")
    echo -e "${GREEN}EC2 Instances Found: $instance_count${NC}"
    
    if [[ $instance_count -gt 0 ]]; then
        local reservation_count
        reservation_count=$(jq '.ec2_instances.Reservations | length' "$output_file")
        
        for ((r=0; r<reservation_count; r++)); do
            local instances_in_reservation
            instances_in_reservation=$(jq ".ec2_instances.Reservations[$r].Instances | length" "$output_file")
            
            for ((inst=0; inst<instances_in_reservation; inst++)); do
                local instance_id instance_name instance_type instance_state instance_az
                instance_id=$(jq -r ".ec2_instances.Reservations[$r].Instances[$inst].InstanceId" "$output_file")
                instance_name=$(jq -r ".ec2_instances.Reservations[$r].Instances[$inst].Tags[]? | select(.Key==\"Name\") | .Value" "$output_file" 2>/dev/null || echo "No Name Tag")
                instance_type=$(jq -r ".ec2_instances.Reservations[$r].Instances[$inst].InstanceType" "$output_file")
                instance_state=$(jq -r ".ec2_instances.Reservations[$r].Instances[$inst].State.Name" "$output_file")
                instance_az=$(jq -r ".ec2_instances.Reservations[$r].Instances[$inst].Placement.AvailabilityZone" "$output_file")
                
                # Get security groups for this instance
                local instance_sgs
                instance_sgs=$(jq -r ".ec2_instances.Reservations[$r].Instances[$inst].SecurityGroups[]? | .GroupName + \" (\" + .GroupId + \")\"" "$output_file" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
                [[ -z "$instance_sgs" ]] && instance_sgs="None"
                
                # Get private and public IPs
                local private_ip public_ip ip_info
                private_ip=$(jq -r ".ec2_instances.Reservations[$r].Instances[$inst].PrivateIpAddress // empty" "$output_file")
                public_ip=$(jq -r ".ec2_instances.Reservations[$r].Instances[$inst].PublicIpAddress // empty" "$output_file")
                
                ip_info=""
                [[ -n "$private_ip" ]] && ip_info="Private: $private_ip"
                [[ -n "$public_ip" ]] && ip_info="${ip_info:+$ip_info, }Public: $public_ip"
                [[ -n "$ip_info" ]] && ip_info=" - $ip_info"
                
                # Determine if this is the last instance across all reservations
                local total_processed=$((r * instances_in_reservation + inst + 1))
                if [[ $total_processed -eq $instance_count ]]; then
                    echo -e "${BLUE}  └─ $instance_name ($instance_id) - $instance_type [$instance_state] in $instance_az${ip_info}${NC}"
                    echo -e "${BLUE}     └─ Security Groups: $instance_sgs${NC}"
                else
                    echo -e "${BLUE}  ├─ $instance_name ($instance_id) - $instance_type [$instance_state] in $instance_az${ip_info}${NC}"
                    echo -e "${BLUE}  │  └─ Security Groups: $instance_sgs${NC}"
                fi
            done
        done
    fi
    
    echo ""
    
    # Key Pairs
    local key_count
    key_count=$(jq '.key_pairs.KeyPairs | length' "$output_file")
    echo -e "${GREEN}Key Pairs Found: $key_count${NC}"
    
    if [[ $key_count -gt 0 ]]; then
        for ((k=0; k<key_count; k++)); do
            local key_name key_type key_fingerprint
            key_name=$(jq -r ".key_pairs.KeyPairs[$k].KeyName" "$output_file")
            key_type=$(jq -r ".key_pairs.KeyPairs[$k].KeyType" "$output_file")
            key_fingerprint=$(jq -r ".key_pairs.KeyPairs[$k].KeyFingerprint" "$output_file")
            
            if [[ $k -eq $((key_count-1)) ]]; then
                echo -e "${BLUE}  └─ $key_name ($key_type) - $key_fingerprint${NC}"
            else
                echo -e "${BLUE}  ├─ $key_name ($key_type) - $key_fingerprint${NC}"
            fi
        done
    fi
    
    echo ""
    
    # Internet Gateways
    local igw_count
    igw_count=$(jq '.internet_gateways.InternetGateways | length' "$output_file")
    echo -e "${GREEN}Internet Gateways Found: $igw_count${NC}"
    
    if [[ $igw_count -gt 0 ]]; then
        for ((igw=0; igw<igw_count; igw++)); do
            local igw_id igw_name igw_state attached_vpc
            igw_id=$(jq -r ".internet_gateways.InternetGateways[$igw].InternetGatewayId" "$output_file")
            igw_name=$(jq -r ".internet_gateways.InternetGateways[$igw].Tags[]? | select(.Key==\"Name\") | .Value" "$output_file" 2>/dev/null || echo "No Name Tag")
            attached_vpc=$(jq -r ".internet_gateways.InternetGateways[$igw].Attachments[]?.VpcId" "$output_file" 2>/dev/null || echo "Not Attached")
            igw_state=$(jq -r ".internet_gateways.InternetGateways[$igw].Attachments[]?.State" "$output_file" 2>/dev/null || echo "detached")
            
            if [[ $igw -eq $((igw_count-1)) ]]; then
                echo -e "${BLUE}  └─ $igw_name ($igw_id) - $igw_state to $attached_vpc${NC}"
            else
                echo -e "${BLUE}  ├─ $igw_name ($igw_id) - $igw_state to $attached_vpc${NC}"
            fi
        done
    fi
    
    echo ""
    
    # Elastic IPs
    local eip_count
    eip_count=$(jq '.elastic_ips.Addresses | length' "$output_file")
    echo -e "${GREEN}Elastic IPs Found: $eip_count${NC}"
    
    if [[ $eip_count -gt 0 ]]; then
        for ((eip=0; eip<eip_count; eip++)); do
            local eip_addr eip_allocation_id eip_instance_id eip_status eip_name
            eip_addr=$(jq -r ".elastic_ips.Addresses[$eip].PublicIp" "$output_file")
            eip_allocation_id=$(jq -r ".elastic_ips.Addresses[$eip].AllocationId" "$output_file")
            eip_instance_id=$(jq -r ".elastic_ips.Addresses[$eip].InstanceId // empty" "$output_file")
            eip_name=$(jq -r ".elastic_ips.Addresses[$eip].Tags[]? | select(.Key==\"Name\") | .Value" "$output_file" 2>/dev/null || echo "No Name Tag")
            
            # Determine status
            if [[ -n "$eip_instance_id" ]]; then
                eip_status="Attached to $eip_instance_id"
            else
                eip_status="Unassigned"
            fi
            
            if [[ $eip -eq $((eip_count-1)) ]]; then
                echo -e "${BLUE}  └─ $eip_name ($eip_addr) - $eip_allocation_id [$eip_status]${NC}"
            else
                echo -e "${BLUE}  ├─ $eip_name ($eip_addr) - $eip_allocation_id [$eip_status]${NC}"
            fi
        done
    fi
    
    echo ""
    echo -e "${GREEN}=== END SUMMARY ===${NC}"
}

# Build comprehensive environment JSON
build_environment_json() {
    log_info "Building comprehensive environment discovery..."
    
    # Get account information
    local account_info
    account_info=$(aws sts get-caller-identity --profile "$PROFILE" --region "$REGION" --output json)
    
    # Discover all VPCs
    local vpcs_data
    vpcs_data=$(discover_vpcs)
    
    # Discover EC2 instances
    local instances_data
    instances_data=$(discover_ec2_instances)
    
    # Discover internet gateways
    local igw_data
    igw_data=$(discover_internet_gateways)
    
    # Discover key pairs
    local keys_data
    keys_data=$(discover_key_pairs)
    
    # Discover Elastic IPs
    local eips_data
    eips_data=$(discover_elastic_ips)
    
    # Build the main JSON structure
    local environment_json
    environment_json=$(jq -n \
        --argjson account "$account_info" \
        --arg region "$REGION" \
        --arg profile "$PROFILE" \
        --argjson vpcs "$vpcs_data" \
        --argjson instances "$instances_data" \
        --argjson internet_gateways "$igw_data" \
        --argjson key_pairs "$keys_data" \
        --argjson elastic_ips "$eips_data" \
        --arg discovery_time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            discovery_metadata: {
                profile: $profile,
                region: $region,
                discovery_time: $discovery_time,
                account: $account
            },
            vpcs: [],
            ec2_instances: $instances,
            internet_gateways: $internet_gateways,
            key_pairs: $key_pairs,
            elastic_ips: $elastic_ips
        }')
    
    # Process each VPC and add detailed information
    local vpc_count
    vpc_count=$(echo "$vpcs_data" | jq '.Vpcs | length')
    
    for ((i=0; i<vpc_count; i++)); do
        local vpc_id
        vpc_id=$(echo "$vpcs_data" | jq -r ".Vpcs[$i].VpcId")
        
        log_info "Processing VPC: $vpc_id"
        
        # Get VPC details
        local vpc_details
        vpc_details=$(echo "$vpcs_data" | jq ".Vpcs[$i]")
        
        # Get subnets for this VPC
        local subnets_data
        subnets_data=$(discover_subnets "$vpc_id")
        
        # Get security groups for this VPC
        local sgs_data
        sgs_data=$(discover_security_groups "$vpc_id")
        
        # Get route tables for this VPC
        local rt_data
        rt_data=$(discover_route_tables "$vpc_id")
        
        # Get NAT gateways for this VPC
        local nat_data
        nat_data=$(discover_nat_gateways "$vpc_id")
        
        # Build VPC object with all related resources
        local vpc_object
        vpc_object=$(jq -n \
            --argjson vpc "$vpc_details" \
            --argjson subnets "$subnets_data" \
            --argjson security_groups "$sgs_data" \
            --argjson route_tables "$rt_data" \
            --argjson nat_gateways "$nat_data" \
            '{
                vpc: $vpc,
                subnets: $subnets,
                security_groups: $security_groups,
                route_tables: $route_tables,
                nat_gateways: $nat_gateways
            }')
        
        # Add this VPC to the main JSON
        environment_json=$(echo "$environment_json" | jq --argjson vpc_obj "$vpc_object" '.vpcs += [$vpc_obj]')
    done
    
    echo "$environment_json"
}

# Main function
main() {
    log_info "Starting AWS environment discovery..."
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check if output file exists and handle overwrite logic
    if [[ -f "$OUTPUT_FILE" && "$OVERWRITE" != "true" ]]; then
        log_info "Output file '$OUTPUT_FILE' already exists. Using existing data (use --overwrite to refresh)."
        
        # Validate existing JSON file
        if jq empty "$OUTPUT_FILE" 2>/dev/null; then
            # Display summaries using existing file
            display_basic_summary "$OUTPUT_FILE" "true"
            display_detailed_summary "$OUTPUT_FILE"
            return 0
        else
            log_error "Existing file '$OUTPUT_FILE' contains invalid JSON. Use --overwrite to regenerate."
            exit 1
        fi
    fi
    
    # If we reach here, we need to discover (either no file exists or --overwrite was specified)
    if [[ -f "$OUTPUT_FILE" && "$OVERWRITE" == "true" ]]; then
        log_info "Overwriting existing file: $OUTPUT_FILE"
    fi
    
    # Check prerequisites
    check_aws_cli
    
    # Validate and refresh AWS session
    check_aws_session
    
    # Build comprehensive environment JSON
    log_info "Discovering AWS resources..."
    local environment_data
    environment_data=$(build_environment_json)
    
    # Write to output file
    echo "$environment_data" | jq '.' > "$OUTPUT_FILE"
    
    # Validate JSON output
    if jq empty "$OUTPUT_FILE" 2>/dev/null; then
        # Display basic summary
        display_basic_summary "$OUTPUT_FILE"
        
        # Display detailed summary with names
        display_detailed_summary "$OUTPUT_FILE"
    else
        log_error "Failed to generate valid JSON output"
        exit 1
    fi
}

main "$@"