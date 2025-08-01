# Terraform configuration for DNS management
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
variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "default_ttl" {
  description = "Default TTL for DNS records"
  type        = number
}

variable "zone_comment" {
  description = "Comment for the hosted zone"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
}

variable "a_records" {
  description = "List of A records"
  type = list(object({
    name  = string
    value = string
    ttl   = number
  }))
  default = []
}

variable "cname_records" {
  description = "List of CNAME records"
  type = list(object({
    name  = string
    value = string
    ttl   = number
  }))
  default = []
}

variable "mx_records" {
  description = "List of MX records"
  type = list(object({
    name     = string
    priority = number
    value    = string
    ttl      = number
  }))
  default = []
}

variable "txt_records" {
  description = "List of TXT records"
  type = list(object({
    name  = string
    value = string
    ttl   = number
  }))
  default = []
}

variable "ns_records" {
  description = "List of NS records for subdomain delegation"
  type = list(object({
    name    = string
    values  = list(string)
    ttl     = number
  }))
  default = []
}

variable "soa_record" {
  description = "SOA record configuration"
  type = object({
    mname   = string
    rname   = string
    serial  = number
    refresh = number
    retry   = number
    expire  = number
    minimum = number
    ttl     = number
  })
  default = null
}

variable "cloudfront_aliases" {
  description = "List of CloudFront alias records"
  type = list(object({
    name     = string
    dns_name = string
    zone_id  = string
  }))
  default = []
}

variable "aaaa_records" {
  description = "List of AAAA records (IPv6)"
  type = list(object({
    name  = string
    value = string
    ttl   = number
  }))
  default = []
}

variable "srv_records" {
  description = "List of SRV records for service discovery"
  type = list(object({
    name     = string
    priority = number
    weight   = number
    port     = number
    target   = string
    ttl      = number
  }))
  default = []
}

variable "ptr_records" {
  description = "List of PTR records for reverse DNS"
  type = list(object({
    name  = string
    value = string
    ttl   = number
  }))
  default = []
}

variable "api_aliases" {
  description = "List of API Gateway alias records"
  type = list(object({
    name     = string
    dns_name = string
    zone_id  = string
  }))
  default = []
}

variable "alb_aliases" {
  description = "List of Application Load Balancer alias records"
  type = list(object({
    name     = string
    dns_name = string
    zone_id  = string
  }))
  default = []
}

variable "caa_records" {
  description = "List of CAA records for certificate authority authorization"
  type = list(object({
    name  = string
    flags = number
    tag   = string
    value = string
    ttl   = number
  }))
  default = []
}

variable "ds_records" {
  description = "List of DS records for DNSSEC delegation signer"
  type = list(object({
    name       = string
    key_tag    = number
    algorithm  = number
    digest_type = number
    digest     = string
    ttl        = number
  }))
  default = []
}

variable "naptr_records" {
  description = "List of NAPTR records for naming authority pointer"
  type = list(object({
    name        = string
    order       = number
    preference  = number
    flags       = string
    service     = string
    regexp      = string
    replacement = string
    ttl         = number
  }))
  default = []
}

# Create the Route 53 hosted zone
resource "aws_route53_zone" "primary" {
  name    = var.domain_name
  comment = var.zone_comment

  tags = {
    Name        = var.domain_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# A Records
resource "aws_route53_record" "a_records" {
  for_each = {
    for record in var.a_records : record.name => record
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "A"
  ttl     = each.value.ttl
  records = [each.value.value]
}

# CNAME Records
resource "aws_route53_record" "cname_records" {
  for_each = {
    for record in var.cname_records : record.name => record
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "CNAME"
  ttl     = each.value.ttl
  records = [each.value.value]
}

# MX Records - Group by name to handle multiple records for same domain
locals {
  mx_records_grouped = {
    for record in var.mx_records :
    record.name => {
      name    = record.name
      ttl     = record.ttl
      records = [for r in var.mx_records : "${r.priority} ${r.value}" if r.name == record.name]
    }...
  }
  
  mx_records_final = {
    for name, groups in local.mx_records_grouped :
    name => {
      name    = groups[0].name
      ttl     = groups[0].ttl
      records = groups[0].records
    }
  }
}

resource "aws_route53_record" "mx_records" {
  for_each = local.mx_records_final

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "MX"
  ttl     = each.value.ttl
  records = each.value.records
}

# TXT Records
resource "aws_route53_record" "txt_records" {
  for_each = {
    for record in var.txt_records : record.name => record
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "TXT"
  ttl     = each.value.ttl
  records = ["\"${each.value.value}\""]
}

# NS Records for subdomain delegation (if any)
resource "aws_route53_record" "ns_records" {
  for_each = {
    for record in var.ns_records : record.name => record
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "NS"
  ttl     = each.value.ttl
  records = each.value.values
}

# SOA Record (if custom SOA is needed)
resource "aws_route53_record" "soa_record" {
  count = var.soa_record != null ? 1 : 0

  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "SOA"
  ttl     = var.soa_record.ttl
  records = [
    "${var.soa_record.mname} ${var.soa_record.rname} ${var.soa_record.serial} ${var.soa_record.refresh} ${var.soa_record.retry} ${var.soa_record.expire} ${var.soa_record.minimum}"
  ]
}

# AAAA Records (IPv6)
resource "aws_route53_record" "aaaa_records" {
  for_each = {
    for record in var.aaaa_records : record.name => record
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "AAAA"
  ttl     = each.value.ttl
  records = [each.value.value]
}

# SRV Records
resource "aws_route53_record" "srv_records" {
  for_each = {
    for record in var.srv_records : "${record.name}-${record.priority}-${record.weight}" => record
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "SRV"
  ttl     = each.value.ttl
  records = ["${each.value.priority} ${each.value.weight} ${each.value.port} ${each.value.target}"]
}

# PTR Records
resource "aws_route53_record" "ptr_records" {
  for_each = {
    for record in var.ptr_records : record.name => record
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "PTR"
  ttl     = each.value.ttl
  records = [each.value.value]
}

# API Gateway Alias Records
resource "aws_route53_record" "api_aliases" {
  for_each = {
    for record in var.api_aliases : record.name => record
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "A"

  alias {
    name                   = each.value.dns_name
    zone_id                = each.value.zone_id
    evaluate_target_health = false
  }
}

# Application Load Balancer Alias Records
resource "aws_route53_record" "alb_aliases" {
  for_each = {
    for record in var.alb_aliases : record.name => record
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "A"

  alias {
    name                   = each.value.dns_name
    zone_id                = each.value.zone_id
    evaluate_target_health = true
  }
}

# CloudFront Alias Records
resource "aws_route53_record" "cloudfront_aliases" {
  for_each = {
    for record in var.cloudfront_aliases : record.name => record
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "A"

  alias {
    name                   = each.value.dns_name
    zone_id                = each.value.zone_id
    evaluate_target_health = false
  }
}

# CAA Records
resource "aws_route53_record" "caa_records" {
  for_each = {
    for record in var.caa_records : "${record.name}-${record.flags}-${record.tag}" => record
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "CAA"
  ttl     = each.value.ttl
  records = ["${each.value.flags} ${each.value.tag} \"${each.value.value}\""]
}

# DS Records
resource "aws_route53_record" "ds_records" {
  for_each = {
    for record in var.ds_records : "${record.name}-${record.key_tag}" => record
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "DS"
  ttl     = each.value.ttl
  records = ["${each.value.key_tag} ${each.value.algorithm} ${each.value.digest_type} ${each.value.digest}"]
}

# NAPTR Records
resource "aws_route53_record" "naptr_records" {
  for_each = {
    for record in var.naptr_records : "${record.name}-${record.order}-${record.preference}" => record
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = "NAPTR"
  ttl     = each.value.ttl
  records = ["${each.value.order} ${each.value.preference} \"${each.value.flags}\" \"${each.value.service}\" \"${each.value.regexp}\" ${each.value.replacement}"]
}

# Outputs
output "zone_id" {
  description = "The hosted zone ID"
  value       = aws_route53_zone.primary.zone_id
}

output "zone_arn" {
  description = "The hosted zone ARN"
  value       = aws_route53_zone.primary.arn
}

output "name_servers" {
  description = "The name servers for the hosted zone"
  value       = aws_route53_zone.primary.name_servers
}

output "domain_name" {
  description = "The domain name"
  value       = var.domain_name
}

output "records_summary" {
  description = "Summary of DNS records created"
  value = {
    a_records_count          = length(var.a_records)
    aaaa_records_count       = length(var.aaaa_records)
    cname_records_count      = length(var.cname_records)
    mx_records_count         = length(local.mx_records_final)
    txt_records_count        = length(var.txt_records)
    ns_records_count         = length(var.ns_records)
    srv_records_count        = length(var.srv_records)
    ptr_records_count        = length(var.ptr_records)
    api_aliases_count        = length(var.api_aliases)
    alb_aliases_count        = length(var.alb_aliases)
    cloudfront_aliases_count = length(var.cloudfront_aliases)
    caa_records_count        = length(var.caa_records)
    ds_records_count         = length(var.ds_records)
    naptr_records_count      = length(var.naptr_records)
    soa_record_managed       = var.soa_record != null
  }
}