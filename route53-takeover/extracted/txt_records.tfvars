# TXT Records
txt_records = [
  {
    name  = "example.com"
    value = "v=spf1 include:_spf.google.com ~all"
    ttl   = 60
  },
  {
    name  = "_dmarc.example.com"
    value = "v=DMARC1; p=none;"
    ttl   = 300
  },
]
