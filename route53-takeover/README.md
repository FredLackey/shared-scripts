# DNS Infrastructure Management with Terraform

This repository provides Infrastructure-as-Code (IaC) for managing Route 53 DNS zones and records using Terraform. It's designed to take over existing DNS zones or create new ones with comprehensive DNS record management capabilities.

> **⚠️ Note:** This repository contains demonstration data with sanitized example configurations. All domain names, IP addresses, AWS account IDs, and other sensitive information have been replaced with generic placeholders for public sharing.

## 🎯 Purpose

This Terraform configuration manages DNS infrastructure for domains, providing:

- **Complete DNS zone management** via AWS Route 53
- **All major DNS record types** (A, AAAA, CNAME, MX, TXT, NS, SOA, SRV, PTR)
- **AWS service aliases** (ALB, CloudFront, API Gateway)
- **Advanced record types** (CAA, DS, NAPTR)
- **Zone extraction tools** for importing existing configurations
- **Modular variable structure** for easy maintenance

## 📁 Repository Structure

```
├── README.md                    # This file
├── main.tf                      # Main Terraform configuration
├── scripts/
│   └── extract-zone-records.sh  # Zone extraction utility
├── variables/                   # Variable files (auto-loaded)
│   ├── *.auto.tfvars           # Production DNS records
└── extracted/                   # Generated files from extraction script
    └── *.tfvars                # Extracted zone data (NOT auto-loaded)
```

## 🔧 Zone Extraction Script

The `scripts/extract-zone-records.sh` script extracts existing DNS records from a Route 53 hosted zone to help with zone migration or discovering discrepancies.

### Usage
```bash
./scripts/extract-zone-records.sh <domain-name> <aws-profile>
```

**Example:**
```bash
./scripts/extract-zone-records.sh example.com my-aws-profile
```

### Important Notes
- **Files in `extracted/` are NOT automatically used** by Terraform
- The script generates `.tfvars` files (without `.auto`) for manual review
- You must manually copy/rename files to `variables/` with `.auto.tfvars` extension
- Always review extracted files before using them in production

## 📋 Variables Directory Files

Each file in the `variables/` directory corresponds to a specific DNS record type. All files use the `.auto.tfvars` extension for automatic loading by Terraform.

### Core Configuration Files

#### `aws.auto.tfvars`
AWS provider configuration.
```hcl
aws_region = "us-east-1"
aws_profile = "my-aws-profile"
```

#### `domain.auto.tfvars`
Domain and zone configuration.
```hcl
domain_name = "example.com"
aws_account_id = "123456789012"
environment = "production"
default_ttl = 300
zone_comment = "Primary hosted zone for example.com"
```

### DNS Record Type Files

#### `a_records.auto.tfvars`
Standard A records (IPv4).
```hcl
a_records = [
  {
    name  = "server.example.com"
    value = "192.168.1.100"
    ttl   = 300
  }
]
```

#### `aaaa_records.auto.tfvars`
AAAA records (IPv6).
```hcl
aaaa_records = [
  {
    name  = "ipv6.example.com"
    value = "2001:db8::1"
    ttl   = 300
  }
]
```

#### `cname_records.auto.tfvars`
CNAME records.
```hcl
cname_records = [
  {
    name  = "www.example.com"
    value = "example.com"
    ttl   = 300
  }
]
```

#### `mx_records.auto.tfvars`
Mail exchange records.
```hcl
mx_records = [
  {
    name     = "example.com"
    priority = 10
    value    = "mail.example.com"
    ttl      = 300
  }
]
```

#### `txt_records.auto.tfvars`
Text records (SPF, DMARC, verification, etc.).
```hcl
txt_records = [
  {
    name  = "example.com"
    value = "v=spf1 include:_spf.google.com ~all"
    ttl   = 300
  }
]
```

#### `ns_records.auto.tfvars`
Name server records for subdomain delegation.
```hcl
ns_records = [
  {
    name   = "subdomain.example.com"
    values = ["ns1.subdomain.example.com", "ns2.subdomain.example.com"]
    ttl    = 86400
  }
]
```

#### `soa_records.auto.tfvars`
Start of Authority record (optional custom SOA).
```hcl
soa_record = {
  mname   = "ns1.example.com"
  rname   = "admin.example.com"
  serial  = 2024010101
  refresh = 7200
  retry   = 900
  expire  = 1209600
  minimum = 86400
  ttl     = 172800
}
```

#### `srv_records.auto.tfvars`
Service discovery records.
```hcl
srv_records = [
  {
    name     = "_sip._tcp.example.com"
    priority = 10
    weight   = 5
    port     = 5060
    target   = "sip.example.com"
    ttl      = 300
  }
]
```

#### `ptr_records.auto.tfvars`
Reverse DNS records.
```hcl
ptr_records = [
  {
    name  = "100.1.168.192.in-addr.arpa"
    value = "server.example.com"
    ttl   = 300
  }
]
```

### AWS Service Alias Files

#### `api_aliases.auto.tfvars`
API Gateway aliases.
```hcl
api_aliases = [
  {
    name     = "api.example.com"
    dns_name = "abc123.execute-api.us-east-1.amazonaws.com"
    zone_id  = "Z1UJRXOUMOOFQ8"
  }
]
```

#### `alb_aliases.auto.tfvars`
Application Load Balancer aliases.
```hcl
alb_aliases = [
  {
    name     = "app.example.com"
    dns_name = "alb-abc123.us-east-1.elb.amazonaws.com"
    zone_id  = "Z35SXDOTRQ7X7K"
  }
]
```

#### `cloudfront_aliases.auto.tfvars`
CloudFront distribution aliases.
```hcl
cloudfront_aliases = [
  {
    name     = "cdn.example.com"
    dns_name = "d123456.cloudfront.net"
    zone_id  = "Z2FDTNDATAQYW2"
  }
]
```

## 🚀 Taking Over an Existing Domain

### Step 1: Extract Current Zone Configuration
```bash
# Extract existing DNS records
./scripts/extract-zone-records.sh yourdomain.com your-aws-profile

# Review generated files
ls -la extracted/
```

### Step 2: Review and Prepare Variable Files
```bash
# Create variables directory if it doesn't exist
mkdir -p variables/

# Copy core configuration files
cp extracted/domain.tfvars variables/domain.auto.tfvars
cp extracted/aws.tfvars variables/aws.auto.tfvars

# Copy desired record type files (review first!)
cp extracted/a_records.tfvars variables/a_records.auto.tfvars
cp extracted/mx_records.tfvars variables/mx_records.auto.tfvars
# ... repeat for other needed record types
```

### Step 3: Review and Modify Variables
1. **Edit** `variables/domain.auto.tfvars` - verify domain settings
2. **Edit** `variables/aws.auto.tfvars` - confirm AWS configuration  
3. **Review each record file** - validate extracted records are correct
4. **Remove any empty files** or records you don't want to manage

### Step 4: Plan and Apply
```bash
# Initialize Terraform
terraform init

# Plan the changes (should show import of existing zone)
terraform plan

# Apply the configuration
terraform apply
```

### Step 5: Verify DNS Resolution
```bash
# Test DNS resolution
dig yourdomain.com
dig www.yourdomain.com
# ... test other critical records
```

## ⚡ Quick Start for New Domains

1. **Copy this repository**
2. **Update** `variables/domain.auto.tfvars` with your domain details
3. **Update** `variables/aws.auto.tfvars` with your AWS settings
4. **Create/modify** record files in `variables/` as needed
5. **Run** `terraform init && terraform plan && terraform apply`

## 🛡️ Important Notes

- **Always test in non-production first**
- **DNS changes can take time to propagate** (TTL dependent)
- **The extraction script is for discovery only** - files in `extracted/` are not used by Terraform
- **Review all extracted records** before copying to `variables/`
- **Backup existing DNS configuration** before making changes
- **Monitor DNS resolution** after applying changes

## 📚 Additional Resources

- [AWS Route 53 Documentation](https://docs.aws.amazon.com/route53/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [DNS Record Types Reference](https://en.wikipedia.org/wiki/List_of_DNS_record_types)