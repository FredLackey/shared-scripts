# CAA Records
caa_records = [
  {
    name     = "example.com"
    flags    = 0
    tag      = "issue"
    value    = "letsencrypt.org"
    ttl      = 300
    comment  = "Allow Let's Encrypt to issue certificates"
  },
  {
    name     = "example.com"
    flags    = 0
    tag      = "issuewild"
    value    = "letsencrypt.org"
    ttl      = 300
    comment  = "Allow Let's Encrypt to issue wildcard certificates"
  }
]