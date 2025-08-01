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

## 📋 Variables Directory Files Reference

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
**A records** map domain names to IPv4 addresses. These are the most common DNS records, used when you want a domain or subdomain to point to a specific server's IP address.
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
**AAAA records** map domain names to IPv6 addresses. Use these when you have IPv6-enabled servers and want to support IPv6 connectivity for modern internet infrastructure.
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
**CNAME records** create aliases that point one domain name to another. Commonly used for `www` subdomains, CDN endpoints, or when you want multiple names to resolve to the same destination without duplicating IP addresses.
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
**MX records** specify mail servers responsible for handling email for your domain. The priority determines which server is tried first (lower numbers = higher priority). Essential for receiving email at your domain.
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
**TXT records** store arbitrary text data. Commonly used for email security (SPF, DKIM, DMARC), domain verification for services like Google/Microsoft, SSL certificate validation, and site ownership verification.
```hcl
txt_records = [
  {
    name  = "example.com"
    value = "v=spf1 include:_spf.google.com ~all"
    ttl   = 300
  },
  {
    name  = "_dmarc.example.com"
    value = "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com; ruf=mailto:dmarc@example.com; fo=1; adkim=s; aspf=s; pct=100; rf=afrf; ri=86400; sp=quarantine"
    ttl   = 300
  }
]
```

#### `ns_records.auto.tfvars`
**NS records** delegate authority for a subdomain to different name servers. Use when you want a subdomain managed by different DNS servers (e.g., delegating `api.example.com` to a third-party service).
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
**SOA records** define authoritative information about the DNS zone, including the primary name server, admin contact, and timing parameters for zone transfers. AWS Route 53 creates this automatically, but you can customize it if needed.
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
**SRV records** specify the location (hostname and port) of servers providing specific services. Used for service discovery in protocols like SIP, XMPP, or Microsoft services. The format is `_service._protocol.domain`.
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
**PTR records** provide reverse DNS lookups, mapping IP addresses back to domain names. Essential for email servers (many mail servers reject emails from servers without proper reverse DNS) and network troubleshooting.
```hcl
ptr_records = [
  {
    name  = "100.1.168.192.in-addr.arpa"
    value = "server.example.com"
    ttl   = 300
  }
]
```

#### `caa_records.auto.tfvars`
**CAA records** specify which Certificate Authorities (CAs) are authorized to issue SSL/TLS certificates for your domain. This adds security by preventing unauthorized certificate issuance, which helps protect against man-in-the-middle attacks.
```hcl
caa_records = [
  {
    name  = "example.com"
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org"
    ttl   = 300
  }
]
```

#### `ds_records.auto.tfvars`
**DS records** are used in DNSSEC (DNS Security Extensions) to establish a chain of trust for cryptographically signed DNS data. They contain a hash of a DNSKEY record and are placed in the parent zone to validate the child zone's authenticity.
```hcl
ds_records = [
  {
    name        = "secure.example.com"
    key_tag     = 12345
    algorithm   = 7
    digest_type = 1
    digest      = "1234567890ABCDEF1234567890ABCDEF12345678"
    ttl         = 86400
  }
]
```

#### `naptr_records.auto.tfvars`
**NAPTR records** provide complex name transformation rules, commonly used in telecommunications for services like SIP and ENUM. They specify how to convert one identifier into another through regular expressions and service parameters.
```hcl
naptr_records = [
  {
    name        = "example.com"
    order       = 100
    preference  = 10
    flags       = "S"
    service     = "SIP+D2U"
    regexp      = "!^.*$!sip:customer-service@example.com!"
    replacement = "_sip._udp.example.com"
    ttl         = 300
  }
]
```

### AWS Service Alias Files

#### `api_aliases.auto.tfvars`
**API Gateway aliases** create friendly domain names for AWS API Gateway endpoints. Instead of using the default `abc123.execute-api.region.amazonaws.com` URL, you can use your own domain like `api.example.com`. This improves branding and allows you to change backends without updating client URLs.
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
**Application Load Balancer (ALB) aliases** point your custom domain to an AWS ALB. ALBs distribute incoming traffic across multiple targets (EC2 instances, containers, etc.) for high availability. Using aliases instead of A records provides automatic failover and health checking.
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
**CloudFront aliases** connect your custom domain to an AWS CloudFront distribution. CloudFront is a Content Delivery Network (CDN) that caches your content globally for faster delivery. Aliases let you use `cdn.example.com` instead of the default `d123456.cloudfront.net` URL.
```hcl
cloudfront_aliases = [
  {
    name     = "cdn.example.com"
    dns_name = "d123456.cloudfront.net"
    zone_id  = "Z2FDTNDATAQYW2"
  }
]
```