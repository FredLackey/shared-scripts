# SRV Records
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