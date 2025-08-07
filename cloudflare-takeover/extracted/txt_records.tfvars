# TXT Records
txt_records = [
  {
    name     = "dkim._domainkey.fredlackey.com"
    content  = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmiUJp0KU1EQyzUQ6tmfl56BavE27O70hsxWeSdJpldg9u0UafHcLZxouORD8iqjqoceEPOzIICFG8TZZVU/w5hBnjV1l+u9qLYjPEtcWvMiv9xBHS9/t4xSlYkYeGQSJxV0YEPa2q1u4Vm8XPTXFfKarW9E6Z+I51h8obOp00ghSxtGMiIctO3CU3UIaPfpqZ" "DTpssQghO3lTRyQaxbv9yL/O/hrL8IrAp7N9fkvkLa1fkkOVgieC2GPfFQ5Y+fHBF5RezrYL8/pGb4t0BN/It9y3/TKTDzreXIZODfSLKxQFG8NB9Y8wEqCD0GPZ3K5DZwuI4hgD7t98qhU3GLiFQIDAQAB"
    ttl      = 1
    comment  = ""
  },
  {
    name     = "_dmarc.fredlackey.com"
    content  = "v=DMARC1; p=reject; rua=mailto:admin@frednglenda.com; ruf=mailto:admin@frednglenda.com; adkim=s; aspf=s"
    ttl      = 1
    comment  = ""
  },
  {
    name     = "fredlackey.com"
    content  = "v=spf1 include:_spf-us.ionos.com include:sendgrid.net include:spf.smtp2go.com ~all"
    ttl      = 1
    comment  = ""
  },
  {
    name     = "fredlackey.com"
    content  = "google-site-verification=YedqfVbnDbMLq603wfe0pGYlKccX6pQPe-wVFLcCIG0"
    ttl      = 1
    comment  = ""
  },
  {
    name     = "fredlackey.com"
    content  = "zone-ownership-verification-56d6275faac91e884034e8b861fe1e772cf9bc4fd3dd8fe40abbb94eb0515233"
    ttl      = 1
    comment  = ""
  },
  {
    name     = "fredlackey.com"
    content  = "apple-domain=PHENP9gKZ0cn1MRM"
    ttl      = 1
    comment  = ""
  },
  {
    name     = "fredlackey.com._report._dmarc.fredlackey.com"
    content  = "v=DMARC1;"
    ttl      = 1
    comment  = ""
  },
  {
    name     = "wp-a._domainkey.fredlackey.com"
    content  = "v=DKIM1; h=sha256; k=rsa; t=y; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmAki9aeXhMDPGjCP0xC171CvpVPTJQ5wmB3ovafjHMiVqgYir0vlpdG/+vXpStPcNTnDYLH/QesjkJwEYvCHeVx/xnMKNH+7UpnU+SCtxhJGz7a9+NnApTTH9j6ZqkRLK/yJ/VsYX75UzDyfNlIfO0xGpBwaGScNIrrMlWJBsjLrZhjJsO" "GQaDXr6mfM0/iIyqr6wLkf309Q8CUuK7hx2+CVmFQW3kMyYbqjYzQAvXIVRLvAhrVdUqYXXQ6LLh/t6hxzLTK512e235sqg5kEIGhB2zL8im/ghT1lzOOHXF/a0OSjoSl7gklHsTZRHHWCYThhMPO2Z6fpa6lzQeV2PQIDAQAB;"
    ttl      = 1
    comment  = ""
  },
]
