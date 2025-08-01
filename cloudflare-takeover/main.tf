# Terraform configuration for Cloudflare DNS management
terraform {
  required_version = ">= 1.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Configure the Cloudflare Provider
provider "cloudflare" {
  api_token = var.api_token
}

# Variable declarations
variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

variable "zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "default_ttl" {
  description = "Default TTL for DNS records"
  type        = number
  default     = 300
}

variable "a_records" {
  description = "List of A records"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    proxied = bool
    comment = string
  }))
  default = []
}

variable "aaaa_records" {
  description = "List of AAAA records (IPv6)"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    proxied = bool
    comment = string
  }))
  default = []
}

variable "cname_records" {
  description = "List of CNAME records"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    proxied = bool
    comment = string
  }))
  default = []
}

variable "mx_records" {
  description = "List of MX records"
  type = list(object({
    name     = string
    content  = string
    priority = number
    ttl      = number
    comment  = string
  }))
  default = []
}

variable "txt_records" {
  description = "List of TXT records"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "ns_records" {
  description = "List of NS records for subdomain delegation"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
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
    comment  = string
  }))
  default = []
}

variable "ptr_records" {
  description = "List of PTR records for reverse DNS"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "caa_records" {
  description = "List of CAA records for certificate authority authorization"
  type = list(object({
    name    = string
    flags   = number
    tag     = string
    value   = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "cert_records" {
  description = "List of CERT records for certificates"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "dnskey_records" {
  description = "List of DNSKEY records for DNSSEC"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "ds_records" {
  description = "List of DS records for DNSSEC delegation signer"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "https_records" {
  description = "List of HTTPS records"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "loc_records" {
  description = "List of LOC records for location information"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "naptr_records" {
  description = "List of NAPTR records for naming authority pointer"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "openpgpkey_records" {
  description = "List of OPENPGPKEY records"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "smimea_records" {
  description = "List of SMIMEA records"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "sshfp_records" {
  description = "List of SSHFP records for SSH fingerprints"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "svcb_records" {
  description = "List of SVCB records for service binding"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "tlsa_records" {
  description = "List of TLSA records for TLS authentication"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

variable "uri_records" {
  description = "List of URI records"
  type = list(object({
    name    = string
    content = string
    ttl     = number
    comment = string
  }))
  default = []
}

# Local values for record management
locals {
  # Create unique identifiers for records that might have duplicates
  a_records_map = {
    for idx, record in var.a_records :
    "${record.name}-${idx}" => record
  }
  
  aaaa_records_map = {
    for idx, record in var.aaaa_records :
    "${record.name}-${idx}" => record
  }
  
  cname_records_map = {
    for idx, record in var.cname_records :
    "${record.name}-${idx}" => record
  }
  
  mx_records_map = {
    for idx, record in var.mx_records :
    "${record.name}-${record.priority}-${idx}" => record
  }
  
  txt_records_map = {
    for idx, record in var.txt_records :
    "${record.name}-${idx}" => record
  }
  
  ns_records_map = {
    for idx, record in var.ns_records :
    "${record.name}-${idx}" => record
  }
  
  srv_records_map = {
    for idx, record in var.srv_records :
    "${record.name}-${record.priority}-${record.weight}-${idx}" => record
  }
  
  ptr_records_map = {
    for idx, record in var.ptr_records :
    "${record.name}-${idx}" => record
  }
  
  caa_records_map = {
    for idx, record in var.caa_records :
    "${record.name}-${record.flags}-${record.tag}-${idx}" => record
  }
}

# A Records
resource "cloudflare_dns_record" "a_records" {
  for_each = local.a_records_map

  zone_id = var.zone_id
  name    = each.value.name
  type    = "A"
  content = each.value.content
  ttl     = each.value.ttl
  proxied = each.value.proxied
  comment = each.value.comment != "" ? each.value.comment : null
}

# AAAA Records (IPv6)
resource "cloudflare_dns_record" "aaaa_records" {
  for_each = local.aaaa_records_map

  zone_id = var.zone_id
  name    = each.value.name
  type    = "AAAA"
  content = each.value.content
  ttl     = each.value.ttl
  proxied = each.value.proxied
  comment = each.value.comment != "" ? each.value.comment : null
}

# CNAME Records
resource "cloudflare_dns_record" "cname_records" {
  for_each = local.cname_records_map

  zone_id = var.zone_id
  name    = each.value.name
  type    = "CNAME"
  content = each.value.content
  ttl     = each.value.ttl
  proxied = each.value.proxied
  comment = each.value.comment != "" ? each.value.comment : null
}

# MX Records
resource "cloudflare_dns_record" "mx_records" {
  for_each = local.mx_records_map

  zone_id  = var.zone_id
  name     = each.value.name
  type     = "MX"
  content  = each.value.content
  priority = each.value.priority
  ttl      = each.value.ttl
  comment  = each.value.comment != "" ? each.value.comment : null
}

# TXT Records
resource "cloudflare_dns_record" "txt_records" {
  for_each = local.txt_records_map

  zone_id = var.zone_id
  name    = each.value.name
  type    = "TXT"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

# NS Records for subdomain delegation
resource "cloudflare_dns_record" "ns_records" {
  for_each = local.ns_records_map

  zone_id = var.zone_id
  name    = each.value.name
  type    = "NS"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

# SRV Records
resource "cloudflare_dns_record" "srv_records" {
  for_each = local.srv_records_map

  zone_id = var.zone_id
  name    = each.value.name
  type    = "SRV"
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null

  data {
    priority = each.value.priority
    weight   = each.value.weight
    port     = each.value.port
    target   = each.value.target
  }
}

# PTR Records
resource "cloudflare_dns_record" "ptr_records" {
  for_each = local.ptr_records_map

  zone_id = var.zone_id
  name    = each.value.name
  type    = "PTR"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

# CAA Records
resource "cloudflare_dns_record" "caa_records" {
  for_each = local.caa_records_map

  zone_id = var.zone_id
  name    = each.value.name
  type    = "CAA"
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null

  data {
    flags = each.value.flags
    tag   = each.value.tag
    value = each.value.value
  }
}

# Generic records for less common types
resource "cloudflare_dns_record" "cert_records" {
  for_each = {
    for idx, record in var.cert_records :
    "${record.name}-${idx}" => record
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "CERT"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

resource "cloudflare_dns_record" "dnskey_records" {
  for_each = {
    for idx, record in var.dnskey_records :
    "${record.name}-${idx}" => record
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "DNSKEY"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

resource "cloudflare_dns_record" "ds_records" {
  for_each = {
    for idx, record in var.ds_records :
    "${record.name}-${idx}" => record
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "DS"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

resource "cloudflare_dns_record" "https_records" {
  for_each = {
    for idx, record in var.https_records :
    "${record.name}-${idx}" => record
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "HTTPS"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

resource "cloudflare_dns_record" "loc_records" {
  for_each = {
    for idx, record in var.loc_records :
    "${record.name}-${idx}" => record
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "LOC"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

resource "cloudflare_dns_record" "naptr_records" {
  for_each = {
    for idx, record in var.naptr_records :
    "${record.name}-${idx}" => record
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "NAPTR"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

resource "cloudflare_dns_record" "openpgpkey_records" {
  for_each = {
    for idx, record in var.openpgpkey_records :
    "${record.name}-${idx}" => record
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "OPENPGPKEY"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

resource "cloudflare_dns_record" "smimea_records" {
  for_each = {
    for idx, record in var.smimea_records :
    "${record.name}-${idx}" => record
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "SMIMEA"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

resource "cloudflare_dns_record" "sshfp_records" {
  for_each = {
    for idx, record in var.sshfp_records :
    "${record.name}-${idx}" => record
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "SSHFP"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

resource "cloudflare_dns_record" "svcb_records" {
  for_each = {
    for idx, record in var.svcb_records :
    "${record.name}-${idx}" => record
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "SVCB"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

resource "cloudflare_dns_record" "tlsa_records" {
  for_each = {
    for idx, record in var.tlsa_records :
    "${record.name}-${idx}" => record
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "TLSA"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

resource "cloudflare_dns_record" "uri_records" {
  for_each = {
    for idx, record in var.uri_records :
    "${record.name}-${idx}" => record
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "URI"
  content = each.value.content
  ttl     = each.value.ttl
  comment = each.value.comment != "" ? each.value.comment : null
}

# Outputs
output "zone_id" {
  description = "The Cloudflare zone ID"
  value       = var.zone_id
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
    mx_records_count         = length(var.mx_records)
    txt_records_count        = length(var.txt_records)
    ns_records_count         = length(var.ns_records)
    srv_records_count        = length(var.srv_records)
    ptr_records_count        = length(var.ptr_records)
    caa_records_count        = length(var.caa_records)
    cert_records_count       = length(var.cert_records)
    dnskey_records_count     = length(var.dnskey_records)
    ds_records_count         = length(var.ds_records)
    https_records_count      = length(var.https_records)
    loc_records_count        = length(var.loc_records)
    naptr_records_count      = length(var.naptr_records)
    openpgpkey_records_count = length(var.openpgpkey_records)
    smimea_records_count     = length(var.smimea_records)
    sshfp_records_count      = length(var.sshfp_records)
    svcb_records_count       = length(var.svcb_records)
    tlsa_records_count       = length(var.tlsa_records)
    uri_records_count        = length(var.uri_records)
  }
}