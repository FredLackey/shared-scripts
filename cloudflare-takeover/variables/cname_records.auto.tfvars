# CNAME Records
cname_records = [
  {
    name     = "blog.example.com"
    content  = "example.github.io"
    ttl      = 300
    proxied  = false
    comment  = "Blog hosted on GitHub"
  },
  {
    name     = "cdn.example.com"
    content  = "d123456.cloudfront.net"
    ttl      = 300
    proxied  = false
    comment  = "CDN endpoint"
  }
]