# Terraform configuration for CloudFront distribution management
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Variable declarations
variable "distribution_id" {
  description = "CloudFront Distribution ID (for existing distributions)"
  type        = string
  default     = ""
}

variable "caller_reference" {
  description = "Unique value that ensures the request can't be replayed"
  type        = string
  default     = ""
}

variable "comment" {
  description = "Comment to describe the distribution"
  type        = string
  default     = ""
}

variable "default_root_object" {
  description = "Object that you want CloudFront to return when an end user requests the root URL"
  type        = string
  default     = ""
}

variable "enabled" {
  description = "Whether the distribution is enabled to accept end user requests for content"
  type        = bool
  default     = true
}

variable "is_ipv6_enabled" {
  description = "Whether the IPv6 is enabled for the distribution"
  type        = bool
  default     = true
}

variable "http_version" {
  description = "Maximum HTTP version to support on the distribution"
  type        = string
  default     = "http2"
}

variable "price_class" {
  description = "Price class for this distribution"
  type        = string
  default     = "PriceClass_All"
}

variable "web_acl_id" {
  description = "Unique identifier that specifies the AWS WAF web ACL"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "aliases" {
  description = "List of CNAMEs (alternate domain names) for this distribution"
  type        = list(string)
  default     = []
}

variable "origins" {
  description = "List of origins for this distribution"
  type = list(object({
    id                         = string
    domain_name               = string
    origin_path               = optional(string, "")
    connection_attempts       = optional(number, 3)
    connection_timeout        = optional(number, 10)
    origin_access_control_id  = optional(string, "")
    s3_origin_config = optional(object({
      origin_access_identity = optional(string, "")
    }), null)
    custom_origin_config = optional(object({
      http_port              = number
      https_port             = number
      origin_protocol_policy = string
      origin_ssl_protocols   = list(string)
      origin_keepalive_timeout = optional(number, 5)
      origin_read_timeout    = optional(number, 30)
    }), null)
    origin_shield = optional(object({
      enabled = bool
      origin_shield_region = string
    }), null)
    custom_headers = optional(list(object({
      name  = string
      value = string
    })), [])
  }))
  default = []
}

variable "default_cache_behavior" {
  description = "Default cache behavior for this distribution"
  type = object({
    target_origin_id                 = string
    viewer_protocol_policy          = string
    allowed_methods                 = list(string)
    cached_methods                  = list(string)
    compress                        = optional(bool, false)
    smooth_streaming               = optional(bool, false)
    cache_policy_id                = optional(string, "")
    origin_request_policy_id       = optional(string, "")
    response_headers_policy_id     = optional(string, "")
    realtime_log_config_arn        = optional(string, "")
    field_level_encryption_id      = optional(string, "")
    trusted_signers = optional(object({
      enabled = bool
      items   = list(string)
    }), null)
    trusted_key_groups = optional(object({
      enabled = bool
      items   = list(string)
    }), null)
    lambda_function_associations = optional(list(object({
      event_type   = string
      lambda_arn   = string
      include_body = optional(bool, false)
    })), [])
    function_associations = optional(list(object({
      event_type   = string
      function_arn = string
    })), [])
  })
}

variable "cache_behaviors" {
  description = "List of cache behaviors for this distribution"
  type = list(object({
    path_pattern                = string
    target_origin_id           = string
    viewer_protocol_policy     = string
    allowed_methods            = list(string)
    cached_methods             = list(string)
    compress                   = optional(bool, false)
    cache_policy_id            = optional(string, "")
    origin_request_policy_id   = optional(string, "")
    response_headers_policy_id = optional(string, "")
    trusted_signers = optional(object({
      enabled = bool
      items   = list(string)
    }), null)
    trusted_key_groups = optional(object({
      enabled = bool
      items   = list(string)
    }), null)
  }))
  default = []
}

variable "viewer_certificate" {
  description = "SSL certificate for the distribution"
  type = object({
    cloudfront_default_certificate = optional(bool, true)
    acm_certificate_arn           = optional(string, "")
    iam_certificate_id            = optional(string, "")
    ssl_support_method            = optional(string, "")
    minimum_protocol_version      = optional(string, "")
  })
  default = {
    cloudfront_default_certificate = true
  }
}

variable "custom_error_responses" {
  description = "List of custom error responses"
  type = list(object({
    error_code            = number
    response_page_path    = optional(string, "")
    response_code         = optional(string, "")
    error_caching_min_ttl = optional(number, 300)
  }))
  default = []
}

variable "geo_restriction" {
  description = "Geographic restrictions for the distribution"
  type = object({
    restriction_type = string
    locations        = list(string)
  })
  default = {
    restriction_type = "none"
    locations        = []
  }
}

variable "logging_config" {
  description = "Logging configuration for the distribution"
  type = object({
    enabled         = bool
    include_cookies = optional(bool, false)
    bucket          = string
    prefix          = optional(string, "")
  })
  default = {
    enabled = false
    bucket  = ""
  }
}

variable "tags" {
  description = "A map of tags to assign to the distribution"
  type        = map(string)
  default     = {}
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  aliases             = var.aliases
  comment             = var.comment
  default_root_object = var.default_root_object
  enabled             = var.enabled
  is_ipv6_enabled     = var.is_ipv6_enabled
  http_version        = var.http_version
  price_class         = var.price_class
  web_acl_id          = var.web_acl_id

  # Origins
  dynamic "origin" {
    for_each = var.origins
    content {
      domain_name              = origin.value.domain_name
      origin_id                = origin.value.id
      origin_path              = origin.value.origin_path
      connection_attempts      = origin.value.connection_attempts
      connection_timeout       = origin.value.connection_timeout
      origin_access_control_id = origin.value.origin_access_control_id

      dynamic "s3_origin_config" {
        for_each = origin.value.s3_origin_config != null ? [origin.value.s3_origin_config] : []
        content {
          origin_access_identity = s3_origin_config.value.origin_access_identity
        }
      }

      dynamic "custom_origin_config" {
        for_each = origin.value.custom_origin_config != null ? [origin.value.custom_origin_config] : []
        content {
          http_port                = custom_origin_config.value.http_port
          https_port               = custom_origin_config.value.https_port
          origin_protocol_policy   = custom_origin_config.value.origin_protocol_policy
          origin_ssl_protocols     = custom_origin_config.value.origin_ssl_protocols
          origin_keepalive_timeout = custom_origin_config.value.origin_keepalive_timeout
          origin_read_timeout      = custom_origin_config.value.origin_read_timeout
        }
      }

      dynamic "origin_shield" {
        for_each = origin.value.origin_shield != null ? [origin.value.origin_shield] : []
        content {
          enabled              = origin_shield.value.enabled
          origin_shield_region = origin_shield.value.origin_shield_region
        }
      }

      dynamic "custom_header" {
        for_each = origin.value.custom_headers
        content {
          name  = custom_header.value.name
          value = custom_header.value.value
        }
      }
    }
  }

  # Default Cache Behavior
  default_cache_behavior {
    target_origin_id                 = var.default_cache_behavior.target_origin_id
    viewer_protocol_policy          = var.default_cache_behavior.viewer_protocol_policy
    allowed_methods                 = var.default_cache_behavior.allowed_methods
    cached_methods                  = var.default_cache_behavior.cached_methods
    compress                        = var.default_cache_behavior.compress
    smooth_streaming               = var.default_cache_behavior.smooth_streaming
    cache_policy_id                = var.default_cache_behavior.cache_policy_id != "" ? var.default_cache_behavior.cache_policy_id : null
    origin_request_policy_id       = var.default_cache_behavior.origin_request_policy_id != "" ? var.default_cache_behavior.origin_request_policy_id : null
    response_headers_policy_id     = var.default_cache_behavior.response_headers_policy_id != "" ? var.default_cache_behavior.response_headers_policy_id : null
    realtime_log_config_arn        = var.default_cache_behavior.realtime_log_config_arn != "" ? var.default_cache_behavior.realtime_log_config_arn : null
    field_level_encryption_id      = var.default_cache_behavior.field_level_encryption_id != "" ? var.default_cache_behavior.field_level_encryption_id : null

    dynamic "trusted_signers" {
      for_each = var.default_cache_behavior.trusted_signers != null ? [var.default_cache_behavior.trusted_signers] : []
      content {
        enabled = trusted_signers.value.enabled
        items   = trusted_signers.value.items
      }
    }

    dynamic "trusted_key_groups" {
      for_each = var.default_cache_behavior.trusted_key_groups != null ? [var.default_cache_behavior.trusted_key_groups] : []
      content {
        enabled = trusted_key_groups.value.enabled
        items   = trusted_key_groups.value.items
      }
    }

    dynamic "lambda_function_association" {
      for_each = var.default_cache_behavior.lambda_function_associations
      content {
        event_type   = lambda_function_association.value.event_type
        lambda_arn   = lambda_function_association.value.lambda_arn
        include_body = lambda_function_association.value.include_body
      }
    }

    dynamic "function_association" {
      for_each = var.default_cache_behavior.function_associations
      content {
        event_type   = function_association.value.event_type
        function_arn = function_association.value.function_arn
      }
    }
  }

  # Cache Behaviors
  dynamic "ordered_cache_behavior" {
    for_each = var.cache_behaviors
    content {
      path_pattern                = ordered_cache_behavior.value.path_pattern
      target_origin_id           = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy     = ordered_cache_behavior.value.viewer_protocol_policy
      allowed_methods            = ordered_cache_behavior.value.allowed_methods
      cached_methods             = ordered_cache_behavior.value.cached_methods
      compress                   = ordered_cache_behavior.value.compress
      cache_policy_id            = ordered_cache_behavior.value.cache_policy_id != "" ? ordered_cache_behavior.value.cache_policy_id : null
      origin_request_policy_id   = ordered_cache_behavior.value.origin_request_policy_id != "" ? ordered_cache_behavior.value.origin_request_policy_id : null
      response_headers_policy_id = ordered_cache_behavior.value.response_headers_policy_id != "" ? ordered_cache_behavior.value.response_headers_policy_id : null

      dynamic "trusted_signers" {
        for_each = ordered_cache_behavior.value.trusted_signers != null ? [ordered_cache_behavior.value.trusted_signers] : []
        content {
          enabled = trusted_signers.value.enabled
          items   = trusted_signers.value.items
        }
      }

      dynamic "trusted_key_groups" {
        for_each = ordered_cache_behavior.value.trusted_key_groups != null ? [ordered_cache_behavior.value.trusted_key_groups] : []
        content {
          enabled = trusted_key_groups.value.enabled
          items   = trusted_key_groups.value.items
        }
      }
    }
  }

  # Viewer Certificate
  viewer_certificate {
    cloudfront_default_certificate = var.viewer_certificate.cloudfront_default_certificate
    acm_certificate_arn           = var.viewer_certificate.acm_certificate_arn != "" ? var.viewer_certificate.acm_certificate_arn : null
    iam_certificate_id            = var.viewer_certificate.iam_certificate_id != "" ? var.viewer_certificate.iam_certificate_id : null
    ssl_support_method            = var.viewer_certificate.ssl_support_method != "" ? var.viewer_certificate.ssl_support_method : null
    minimum_protocol_version      = var.viewer_certificate.minimum_protocol_version != "" ? var.viewer_certificate.minimum_protocol_version : null
  }

  # Custom Error Responses
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_page_path    = custom_error_response.value.response_page_path != "" ? custom_error_response.value.response_page_path : null
      response_code         = custom_error_response.value.response_code != "" ? custom_error_response.value.response_code : null
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # Geographic Restrictions
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction.restriction_type
      locations        = var.geo_restriction.locations
    }
  }

  # Logging Configuration
  dynamic "logging_config" {
    for_each = var.logging_config.enabled ? [var.logging_config] : []
    content {
      include_cookies = logging_config.value.include_cookies
      bucket          = logging_config.value.bucket
      prefix          = logging_config.value.prefix
    }
  }

  tags = merge(var.tags, {
    Name        = var.comment != "" ? var.comment : "CloudFront Distribution"
    ManagedBy   = "terraform"
    Environment = terraform.workspace
  })

  # Prevent destruction by default - important for production distributions
  lifecycle {
    prevent_destroy = false # Set to true for production
  }
}

# Origin Access Control (OAC) for S3 origins
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  count = length([for origin in var.origins : origin if origin.s3_origin_config != null && origin.origin_access_control_id == ""])

  name                              = "OAC-${aws_cloudfront_distribution.main.id}-${count.index}"
  description                       = "Origin Access Control for S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Outputs
output "distribution_id" {
  description = "The CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "The CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "distribution_domain_name" {
  description = "The CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "distribution_hosted_zone_id" {
  description = "The CloudFront distribution hosted zone ID"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "distribution_status" {
  description = "The current status of the distribution"
  value       = aws_cloudfront_distribution.main.status
}

output "distribution_etag" {
  description = "The current version of the distribution's information"
  value       = aws_cloudfront_distribution.main.etag
}

output "origin_access_controls" {
  description = "The Origin Access Control IDs created for S3 origins"
  value       = aws_cloudfront_origin_access_control.s3_oac[*].id
}

output "distribution_summary" {
  description = "Summary of the CloudFront distribution configuration"
  value = {
    id                    = aws_cloudfront_distribution.main.id
    domain_name          = aws_cloudfront_distribution.main.domain_name
    status               = aws_cloudfront_distribution.main.status
    origins_count        = length(var.origins)
    aliases_count        = length(var.aliases)
    cache_behaviors_count = length(var.cache_behaviors)
    enabled              = var.enabled
    price_class          = var.price_class
    http_version         = var.http_version
    ipv6_enabled         = var.is_ipv6_enabled
  }
}