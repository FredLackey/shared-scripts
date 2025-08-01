# CloudFront Infrastructure Management with Terraform

This repository provides Infrastructure-as-Code (IaC) for managing CloudFront distributions using Terraform. It's designed to take over existing CloudFront distributions or create new ones with comprehensive configuration management capabilities.

> **⚠️ Note:** This repository contains demonstration data with sanitized example configurations. All distribution IDs, domain names, AWS account IDs, and other sensitive information should be replaced with your actual values.

## 🎯 Purpose

This Terraform configuration manages CloudFront distribution infrastructure, providing:

- **Complete CloudFront distribution management** 
- **All major distribution features** (Origins, Cache Behaviors, SSL/TLS, Error Pages)
- **AWS service integrations** (S3, ALB, API Gateway, Lambda@Edge)
- **Advanced configurations** (Origin Access Control, Geographic Restrictions, Real-time Logs)
- **Distribution extraction tools** for importing existing configurations
- **Modular variable structure** for easy maintenance

## 📁 Repository Structure

```
├── README.md                           # This file
├── main.tf                            # Main Terraform configuration
├── scripts/
│   └── extract-distribution-config.sh # Distribution extraction utility
├── variables/                         # Variable files (auto-loaded)
│   ├── *.auto.tfvars                 # Production distribution configuration
└── extracted/                         # Generated files from extraction script
    └── *.tfvars                      # Extracted distribution data (NOT auto-loaded)
```

## 🔧 Distribution Extraction Script

The `scripts/extract-distribution-config.sh` script extracts existing CloudFront distribution configurations to help with migration or discovering discrepancies.

### Usage
```bash
./scripts/extract-distribution-config.sh <distribution-id> <aws-profile>
```

**Example:**
```bash
./scripts/extract-distribution-config.sh E1234567890ABC my-aws-profile
```

### Important Notes
- **Files in `extracted/` are NOT automatically used** by Terraform
- The script generates `.tfvars` files (without `.auto`) for manual review
- You must manually copy/rename files to `variables/` with `.auto.tfvars` extension
- Always review extracted files before using them in production

### What Gets Extracted

The script extracts comprehensive CloudFront configuration including:

| Component | Description | File Generated |
|-----------|-------------|----------------|
| **Basic Config** | Distribution settings, enabled status, HTTP version | `distribution_config.tfvars` |
| **Origins** | Origin servers, S3/custom origins, Origin Shield | `origins.tfvars` |
| **Aliases** | CNAME aliases (alternate domain names) | `aliases.tfvars` |
| **Default Cache Behavior** | Primary caching rules and policies | `default_cache_behavior.tfvars` |
| **Cache Behaviors** | Path-specific caching rules | `cache_behaviors.tfvars` |
| **SSL/TLS** | Certificate configuration | `viewer_certificate.tfvars` |
| **Error Pages** | Custom error response configurations | `custom_error_responses.tfvars` |
| **Geographic Restrictions** | Country-based access controls | `geo_restrictions.tfvars` |
| **Logging** | Access log configuration | `logging.tfvars` |
| **AWS Config** | Account and region information | `aws.tfvars` |

## 📊 Supported CloudFront Features

### Origins
- **S3 Origins** with Origin Access Control (OAC) and Origin Access Identity (OAI)
- **Custom Origins** (ALB, API Gateway, custom HTTP servers)
- **Origin Shield** for improved performance
- **Custom Headers** for origin requests
- **Connection settings** (timeout, attempts)

### Cache Behaviors
- **Default Cache Behavior** (required)
- **Ordered Cache Behaviors** with path patterns
- **Cache Policies** (AWS managed and custom)
- **Origin Request Policies**
- **Response Headers Policies**
- **Real-time Log Configurations**

### Security & Access Control
- **SSL/TLS Certificates** (CloudFront default, ACM, IAM)
- **Geographic Restrictions** (whitelist/blacklist countries)
- **AWS WAF Integration**
- **Origin Access Control (OAC)** for S3
- **Trusted Signers** and **Trusted Key Groups**

### Advanced Features
- **Lambda@Edge** function associations
- **CloudFront Functions** 
- **Custom Error Pages**
- **Access Logging** to S3
- **Field-Level Encryption**
- **HTTP/2 and HTTP/3** support
- **IPv6** support

## 🚀 Getting Started

### 1. Extract Existing Distribution (Optional)

If you have an existing CloudFront distribution to migrate:

```bash
# Extract configuration from existing distribution
./scripts/extract-distribution-config.sh E1234567890ABC my-aws-profile

# Review generated files
ls -la extracted/

# Copy desired configurations to variables/
cp extracted/origins.tfvars variables/origins.auto.tfvars
cp extracted/default_cache_behavior.tfvars variables/default_cache_behavior.auto.tfvars
# ... copy other files as needed
```

### 2. Configure Your Distribution

Create or modify the variable files in the `variables/` directory:

**Required files:**
- `aws.auto.tfvars` - AWS configuration
- `origins.auto.tfvars` - At least one origin
- `default_cache_behavior.auto.tfvars` - Default cache behavior

**Optional files:**
- `aliases.auto.tfvars` - Custom domain names
- `cache_behaviors.auto.tfvars` - Additional cache behaviors
- `viewer_certificate.auto.tfvars` - SSL/TLS certificate
- `custom_error_responses.auto.tfvars` - Error pages
- `geo_restrictions.auto.tfvars` - Geographic restrictions
- `logging.auto.tfvars` - Access logging

### 3. Deploy with Terraform

```bash
# Initialize Terraform
terraform init

# Review the planned changes
terraform plan

# Apply the configuration
terraform apply
```

## 📝 Variable File Examples

### Basic S3 Origin Configuration

**variables/aws.auto.tfvars:**
```hcl
aws_region     = "us-east-1"
aws_profile    = "my-aws-profile"
aws_account_id = "123456789012"
```

**variables/origins.auto.tfvars:**
```hcl
origins = [
  {
    id          = "my-s3-bucket"
    domain_name = "my-bucket.s3.amazonaws.com"
    s3_origin_config = {
      origin_access_identity = ""  # Will use OAC instead
    }
  }
]
```

**variables/default_cache_behavior.auto.tfvars:**
```hcl
default_cache_behavior = {
  target_origin_id       = "my-s3-bucket"
  viewer_protocol_policy = "redirect-to-https"
  allowed_methods        = ["GET", "HEAD", "OPTIONS"]
  cached_methods         = ["GET", "HEAD"]
  compress               = true
  cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"  # CachingDisabled
}
```

### Custom Origin Configuration

**variables/origins.auto.tfvars:**
```hcl
origins = [
  {
    id          = "my-alb"
    domain_name = "my-app.example.com"
    custom_origin_config = {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
]
```

### Multiple Cache Behaviors

**variables/cache_behaviors.auto.tfvars:**
```hcl
cache_behaviors = [
  {
    path_pattern           = "/api/*"
    target_origin_id       = "my-api-gateway"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"  # CachingDisabled
  },
  {
    path_pattern           = "/static/*"
    target_origin_id       = "my-s3-bucket"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e886b2d4089"  # CachingOptimized
  }
]
```

### Custom Domain with SSL Certificate

**variables/aliases.auto.tfvars:**
```hcl
aliases = ["www.example.com", "example.com"]
```

**variables/viewer_certificate.auto.tfvars:**
```hcl
viewer_certificate = {
  cloudfront_default_certificate = false
  acm_certificate_arn           = "arn:aws:acm:us-east-1:123456789012:certificate/abcd1234-..."
  ssl_support_method            = "sni-only"
  minimum_protocol_version      = "TLSv1.2_2021"
}
```

## 🔍 Terraform Commands

### Plan and Apply
```bash
# See what changes will be made
terraform plan

# Apply changes
terraform apply

# Apply with auto-approval (use carefully!)
terraform apply -auto-approve
```

### State Management
```bash
# Import existing distribution (if not using extraction script)
terraform import aws_cloudfront_distribution.main E1234567890ABC

# Show current state
terraform show

# List resources in state
terraform state list
```

### Validation and Formatting
```bash
# Validate configuration
terraform validate

# Format code
terraform fmt

# Check for security issues (requires tfsec)
tfsec .
```

## 🛡️ Security Best Practices

### Origin Access Control (OAC)
- Use OAC instead of OAI for S3 origins (automatically created by this module)
- Restrict S3 bucket access to only CloudFront

### SSL/TLS Configuration
- Always use `redirect-to-https` or `https-only` for viewer protocol policy
- Use ACM certificates for custom domains
- Set minimum TLS version to 1.2 or higher

### Geographic Restrictions
```hcl
geo_restriction = {
  restriction_type = "blacklist"  # or "whitelist"
  locations        = ["CN", "RU"]  # ISO country codes
}
```

### WAF Integration
```hcl
web_acl_id = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/MyWebACL/..."
```

## 📊 Monitoring and Logging

### Access Logging
```hcl
logging_config = {
  enabled         = true
  include_cookies = false
  bucket          = "my-cloudfront-logs.s3.amazonaws.com"
  prefix          = "cloudfront-logs/"
}
```

### Real-time Logs
```hcl
default_cache_behavior = {
  # ... other settings ...
  realtime_log_config_arn = "arn:aws:logs:us-east-1:123456789012:log-group:cloudfront-realtime"
}
```

## 🔧 Troubleshooting

### Common Issues

**Distribution Not Found:**
```bash
# Verify distribution ID and AWS profile
aws cloudfront get-distribution --id E1234567890ABC --profile my-profile
```

**Permission Denied:**
```bash
# Check AWS credentials and CloudFront permissions
aws sts get-caller-identity --profile my-profile
```

**Certificate Issues:**
- ACM certificates for CloudFront must be in `us-east-1`
- Ensure certificate covers all aliases
- Verify certificate is validated and issued

**Origin Access Issues:**
- For S3: Use OAC and update bucket policy
- For custom origins: Ensure origin is accessible and HTTPS is configured properly

### Validation Commands
```bash
# Test distribution accessibility
curl -I https://d123456789.cloudfront.net/

# Check SSL certificate
openssl s_client -connect d123456789.cloudfront.net:443 -servername www.example.com
```

## 🔄 Migration from Existing Distributions

1. **Extract current configuration:**
   ```bash
   ./scripts/extract-distribution-config.sh E1234567890ABC my-profile
   ```

2. **Review and customize extracted files:**
   - Check `extracted/` directory
   - Modify configurations as needed
   - Copy to `variables/` with `.auto.tfvars` extension

3. **Import existing distribution:**
   ```bash
   terraform import aws_cloudfront_distribution.main E1234567890ABC
   ```

4. **Plan and verify:**
   ```bash
   terraform plan
   # Should show minimal or no changes if extraction was accurate
   ```

## 📚 Additional Resources

- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [Terraform AWS Provider - CloudFront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution)
- [CloudFront Security Best Practices](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/security-best-practices.html)
- [Origin Access Control (OAC) Documentation](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)

## 🤝 Contributing

1. Review changes in `extracted/` files before copying to `variables/`
2. Test configurations in a development environment first
3. Use `terraform plan` to verify changes before applying
4. Follow AWS and Terraform best practices
5. Update documentation for any new features or configurations

## ⚠️ Important Notes

- **Cost Implications:** CloudFront distributions incur charges based on data transfer and requests
- **Propagation Time:** Distribution changes can take 15-20 minutes to propagate globally
- **Production Safety:** Set `prevent_destroy = true` in lifecycle block for production distributions
- **Backup:** Always backup important configurations before making changes
- **Testing:** Test changes in non-production environments first

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.