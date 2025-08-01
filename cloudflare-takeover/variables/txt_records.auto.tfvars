# TXT Records
txt_records = [
  {
    name     = "example.com"
    content  = "v=spf1 include:_spf.google.com ~all"
    ttl      = 300
    comment  = "SPF record for email"
  },
  {
    name     = "_dmarc.example.com"
    content  = "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"
    ttl      = 300
    comment  = "DMARC policy"
  },
  {
    name     = "google._domainkey.example.com"
    content  = "k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC..."
    ttl      = 300
    comment  = "Google DKIM key"
  }
]