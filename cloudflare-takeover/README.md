# DNS Infrastructure Management with Terraform for Cloudflare

This repository provides Infrastructure-as-Code (IaC) for managing Cloudflare DNS zones and records using Terraform. It's designed to take over existing DNS zones or create new ones with comprehensive DNS record management capabilities.

> **⚠️ Note:** This repository contains demonstration data with sanitized example configurations. All domain names, IP addresses, zone IDs, and other sensitive information have been replaced with generic placeholders for public sharing.

## 🎯 Purpose

This Terraform configuration manages DNS infrastructure for domains using Cloudflare, providing:

- **Complete DNS zone management** via Cloudflare DNS
- **All major DNS record types** (A, AAAA, CNAME, MX, TXT, NS, SRV, PTR, CAA)
- **Advanced record types** (CERT, DNSKEY, DS, HTTPS, LOC, NAPTR, OPENPGPKEY, SMIMEA, SSHFP, SVCB, TLSA, URI)
- **Cloudflare-specific features** (proxying, comments, TTL management)
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

The `scripts/extract-zone-records.sh` script extracts existing DNS records from a Cloudflare zone to help with zone migration or discovering discrepancies.

### Usage
```bash
./scripts/extract-zone-records.sh <domain-name> <cloudflare-api-token>
```

**Example:**
```bash
./scripts/extract-zone-records.sh example.com your-cloudflare-api-token
```

### Getting Your API Token

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click "Create Token"
3. Use the "Custom Token" template
4. Configure permissions:
   - **Zone:Read** for the zone you want to extract
   - **Zone:Zone:Read** for zone information
5. Set the zone resources (specific zone or all zones)
6. Create and copy the token

### Important Notes
- **Files in `extracted/` are NOT automatically used** by Terraform
- The script generates `.tfvars` files (without `.auto`) for manual review
- You must manually copy/rename files to `variables/` with `.auto.tfvars` extension
- Always review extracted files before using them in production

## 🚀 Taking Over an Existing Domain

### Step 1: Extract Current Zone Configuration
```bash
# Extract existing DNS records
./scripts/extract-zone-records.sh yourdomain.com your-cloudflare-api-token

# Review generated files
ls -la extracted/
```

### Step 2: Review and Prepare Variable Files
```bash
# Create variables directory if it doesn't exist
mkdir -p variables/

# Copy core configuration files
cp extracted/domain.tfvars variables/domain.auto.tfvars
cp extracted/cloudflare.tfvars variables/cloudflare.auto.tfvars

# Copy desired record type files (review first!)
cp extracted/a_records.tfvars variables/a_records.auto.tfvars
cp extracted/mx_records.tfvars variables/mx_records.auto.tfvars
# ... repeat for other needed record types
```

### Step 3: Review and Modify Variables
1. **Edit** `variables/domain.auto.tfvars` - verify domain settings and zone ID
2. **Edit** `variables/cloudflare.auto.tfvars` - set API token configuration  
3. **Review each record file** - validate extracted records are correct
4. **Remove any empty files** or records you don't want to manage

### Step 4: Set API Token
```bash
# Recommended: Set as environment variable
export CLOUDFLARE_API_TOKEN=your-cloudflare-api-token

# Alternative: Set in variables/cloudflare.auto.tfvars (less secure)
# api_token = "your-cloudflare-api-token"
```

### Step 5: Plan and Apply
```bash
# Initialize Terraform
terraform init

# Plan the changes (should show creation of records)
terraform plan

# Apply the configuration
terraform apply
```

### Step 6: Verify DNS Resolution
```bash
# Test DNS resolution
dig yourdomain.com
dig www.yourdomain.com
# ... test other critical records
```

## ⚡ Quick Start for New Domains

1. **Copy this repository**
2. **Update** `variables/domain.auto.tfvars` with your domain details and zone ID
3. **Set** your Cloudflare API token: `export CLOUDFLARE_API_TOKEN=your-token`
4. **Create/modify** record files in `variables/` as needed
5. **Run** `terraform init && terraform plan && terraform apply`

## 🛡️ Important Notes

- **Always test in non-production first**
- **DNS changes can take time to propagate** (TTL dependent)
- **The extraction script is for discovery only** - files in `extracted/` are not used by Terraform
- **Review all extracted records** before copying to `variables/`
- **Backup existing DNS configuration** before making changes
- **Monitor DNS resolution** after applying changes
- **Never commit API tokens to version control**

## 📚 Additional Resources

- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [Terraform Cloudflare Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [DNS Record Types Reference](https://developers.cloudflare.com/dns/manage-dns-records/reference/dns-record-types/)

## 📋 Variables Directory Files Reference

Each file in the `variables/` directory corresponds to a specific DNS record type. All files use the `.auto.tfvars` extension for automatic loading by Terraform.

### Core Configuration Files

#### `cloudflare.auto.tfvars`
Cloudflare API configuration.
```hcl
# Set API token as environment variable (recommended)
# export CLOUDFLARE_API_TOKEN=your-token

# Or set directly (not recommended for security)
# api_token = "your-cloudflare-api-token"
```

#### `domain.auto.tfvars`
Domain and zone configuration.
```hcl
domain_name = "example.com"
zone_id = "f2ea6707005a4da1af1b431202e96ac5"
default_ttl = 300
```

### DNS Record Type Files

#### `a_records.auto.tfvars`
**A records** map domain names to IPv4 addresses. These are the most common DNS records, used when you want a domain or subdomain to point to a specific server's IP address.
```hcl
a_records = [
  {
    name     = "www.example.com"
    content  = "192.0.2.1"
    ttl      = 300
    proxied  = true
    comment  = "Main website"
  }
]
```

#### `aaaa_records.auto.tfvars`
**AAAA records** map domain names to IPv6 addresses. Use these when you have IPv6-enabled servers and want to support IPv6 connectivity for modern internet infrastructure.
```hcl
aaaa_records = [
  {
    name     = "www.example.com"
    content  = "2001:db8::1"
    ttl      = 300
    proxied  = true
    comment  = "Main website IPv6"
  }
]
```

#### `cname_records.auto.tfvars`
**CNAME records** create aliases that point one domain name to another. Commonly used for `www` subdomains, CDN endpoints, or when you want multiple names to resolve to the same destination without duplicating IP addresses.
```hcl
cname_records = [
  {
    name     = "blog.example.com"
    content  = "example.github.io"
    ttl      = 300
    proxied  = false
    comment  = "Blog hosted on GitHub"
  }
]
```

#### `mx_records.auto.tfvars`
**MX records** specify mail servers responsible for handling email for your domain. The priority determines which server is tried first (lower numbers = higher priority). Essential for receiving email at your domain.
```hcl
mx_records = [
  {
    name     = "example.com"
    content  = "mail.example.com"
    priority = 10
    ttl      = 300
    comment  = "Primary mail server"
  }
]
```

#### `txt_records.auto.tfvars`
**TXT records** store arbitrary text data. Commonly used for email security (SPF, DKIM, DMARC), domain verification for services like Google/Microsoft, SSL certificate validation, and site ownership verification.
```hcl
txt_records = [
  {
    name     = "example.com"
    content  = "v=spf1 include:_spf.google.com ~all"
    ttl      = 300
    comment  = "SPF record for email"
  }
]
```

#### `ns_records.auto.tfvars`
**NS records** delegate authority for a subdomain to different name servers. Use when you want a subdomain managed by different DNS servers (e.g., delegating `api.example.com` to a third-party service).
```hcl
ns_records = [
  {
    name     = "subdomain.example.com"
    content  = "ns1.subdomain.example.com"
    ttl      = 86400
    comment  = "Subdomain delegation"
  }
]
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
    comment  = "SIP service"
  }
]
```

#### `ptr_records.auto.tfvars`
**PTR records** provide reverse DNS lookups, mapping IP addresses back to domain names. Essential for email servers (many mail servers reject emails from servers without proper reverse DNS) and network troubleshooting.
```hcl
ptr_records = [
  {
    name     = "1.2.0.192.in-addr.arpa"
    content  = "www.example.com"
    ttl      = 300
    comment  = "Reverse DNS for 192.0.2.1"
  }
]
```

#### `caa_records.auto.tfvars`
**CAA records** specify which Certificate Authorities (CAs) are authorized to issue SSL/TLS certificates for your domain. This adds security by preventing unauthorized certificate issuance, which helps protect against man-in-the-middle attacks.
```hcl
caa_records = [
  {
    name     = "example.com"
    flags    = 0
    tag      = "issue"
    value    = "letsencrypt.org"
    ttl      = 300
    comment  = "Allow Let's Encrypt to issue certificates"
  }
]
```

### Advanced Record Types

The configuration also supports advanced DNS record types commonly used in modern infrastructure:

- **CERT Records** - Certificate records for storing certificates
- **DNSKEY Records** - DNS Security Extension keys for DNSSEC
- **DS Records** - Delegation Signer records for DNSSEC
- **HTTPS Records** - HTTPS service parameters
- **LOC Records** - Location information
- **NAPTR Records** - Naming Authority Pointer for complex transformations
- **OPENPGPKEY Records** - OpenPGP public keys
- **SMIMEA Records** - S/MIME certificate association
- **SSHFP Records** - SSH key fingerprints
- **SVCB Records** - Service binding for generic services
- **TLSA Records** - TLS authentication via DANE
- **URI Records** - Uniform Resource Identifier records

## 🔐 Security Best Practices

1. **API Token Management**
   - Use environment variables for API tokens
   - Never commit tokens to version control
   - Use least-privilege access (Zone:Read for extraction, Zone:Edit for management)
   - Rotate tokens regularly

2. **DNS Security**
   - Implement CAA records to control certificate issuance
   - Use DNSSEC where appropriate
   - Monitor DNS changes with Cloudflare's audit logs
   - Implement proper SPF, DKIM, and DMARC records for email security

3. **Infrastructure Security**
   - Use Terraform state locking
   - Store state files securely (e.g., encrypted S3 bucket)
   - Implement proper access controls on state files
   - Use separate environments for development and production

## 🔄 Cloudflare-Specific Features

This configuration leverages Cloudflare-specific features:

- **Proxying** - Route traffic through Cloudflare's edge network
- **Comments** - Add descriptive comments to DNS records
- **TTL Management** - Flexible TTL settings (automatic for proxied records)
- **Advanced Record Types** - Support for modern DNS record types
- **Bulk Operations** - Efficient management of large record sets

## 📈 Monitoring and Maintenance

- **Monitor DNS propagation** using tools like `dig` or `nslookup`
- **Check Cloudflare Analytics** for traffic patterns and issues
- **Review Terraform state** regularly for drift detection
- **Update record TTLs** appropriately for your use case
- **Test failover scenarios** if using multiple records

## 🤝 Contributing

When contributing to this project:

1. Test changes in a development environment first
2. Update documentation for any new record types or features
3. Follow Terraform best practices for code organization
4. Ensure sensitive data is properly sanitized in examples

## 📄 License

This project is provided as-is for educational and operational purposes. Please review and comply with relevant terms of service for Cloudflare and Terraform.