# A Records (IPv4)
a_records = [
  {
    name     = "www.example.com"
    content  = "192.0.2.1"
    ttl      = 300
    proxied  = true
    comment  = "Main website"
  },
  {
    name     = "api.example.com"
    content  = "192.0.2.2"
    ttl      = 300
    proxied  = false
    comment  = "API endpoint"
  }
]