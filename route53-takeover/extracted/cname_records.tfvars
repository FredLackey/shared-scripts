# CNAME Records
cname_records = [
  {
    name  = "abc123def456ghi789._domainkey.example.com"
    value = "abc123def456ghi789.dkim.amazonses.com"
    ttl   = 300
  },
  {
    name  = "def789ghi123abc456._domainkey.example.com"
    value = "def789ghi123abc456.dkim.amazonses.com"
    ttl   = 300
  },
  {
    name  = "ghi456abc789def123._domainkey.example.com"
    value = "ghi456abc789def123.dkim.amazonses.com"
    ttl   = 300
  },
  {
    name  = "caldav.example.com"
    value = "mail.example.com"
    ttl   = 300
  },
  {
    name  = "imap.example.com"
    value = "mail.example.com"
    ttl   = 300
  },
  {
    name  = "mx.example.com"
    value = "mail.example.com"
    ttl   = 300
  },
  {
    name  = "project.example.com"
    value = "apps.example.com"
    ttl   = 300
  },
  {
    name  = "staging.example.com"
    value = "d123456abc.cloudfront.net"
    ttl   = 300
  },
  {
    name  = "_abc123def456ghi789.staging.example.com"
    value = "_def456ghi789abc123.abcdefghij.acm-validations.aws"
    ttl   = 300
  },
  {
    name  = "_def789abc123ghi456.staging.example.com"
    value = "_ghi123def456abc789.abcdefghij.acm-validations.aws"
    ttl   = 300
  },
  {
    name  = "_ghi456def789abc123.sampleapp.staging.example.com"
    value = "_abc789ghi123def456.abcdefghij.acm-validations.aws"
    ttl   = 60
  },
  {
    name  = "_abc789ghi456def123.testapp.staging.example.com"
    value = "_def123abc456ghi789.abcdefghij.acm-validations.aws"
    ttl   = 60
  },
  {
    name  = "_def123ghi789abc456.www.testapp.staging.example.com"
    value = "_ghi456abc789def123.abcdefghij.acm-validations.aws"
    ttl   = 60
  },
  {
    name  = "_ghi789abc456def123.demoapp.staging.example.com"
    value = "_abc456def123ghi789.abcdefghij.acm-validations.aws"
    ttl   = 300
  },
  {
    name  = "www.staging.example.com"
    value = "d123456abc.cloudfront.net"
    ttl   = 300
  },
  {
    name  = "_abc456ghi123def789.www.staging.example.com"
    value = "_def789abc456ghi123.abcdefghij.acm-validations.aws"
    ttl   = 300
  },
  {
    name  = "_ghi123def789abc456.www.staging.example.com"
    value = "_abc789def456ghi123.abcdefghij.acm-validations.aws"
    ttl   = 300
  },
  {
    name  = "smtp.example.com"
    value = "mail.example.com"
    ttl   = 300
  },
  {
    name  = "webmail.example.com"
    value = "mail.example.com"
    ttl   = 300
  },
  {
    name  = "www.example.com"
    value = "apps.example.com"
    ttl   = 300
  },
]
