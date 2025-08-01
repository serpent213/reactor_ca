# Let's Encrypt cert in comparison to ReactorCA default host cert

(LLM generated)

```raw
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            05:68:99:a1:77:cf:f3:d2:d8:77:eb:c3:93:65:b7:04:a0:5f
        Signature Algorithm: ecdsa-with-SHA384
        Issuer: C=US, O=Let's Encrypt, CN=E6
        Validity
            Not Before: Jul 18 11:55:17 2025 GMT
            Not After : Oct 16 11:55:16 2025 GMT
        Subject: CN=example.net
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub:
                    04:51:c3:35:d5:2c:cd:8a:b5:12:63:37:db:3f:03:
                    75:c9:3e:8f:4c:ce:c2:44:cc:3f:a1:6b:3e:17:18:
                    e5:58:07:ad:bb:a8:86:b2:0c:d9:ed:13:92:56:49:
                    7b:af:88:13:bc:e1:e8:3c:82:fc:2f:aa:2d:13:36:
                    aa:73:4f:29:5c
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature
            X509v3 Extended Key Usage:
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Subject Key Identifier:
                35:BD:1D:A2:24:CB:25:DB:5A:84:F9:C0:4D:08:6F:A4:5D:8D:87:84
            X509v3 Authority Key Identifier:
                93:27:46:98:03:A9:51:68:8E:98:D6:C4:42:48:DB:23:BF:58:94:D2
            Authority Information Access:
                CA Issuers - URI:http://e6.i.lencr.org/
            X509v3 Subject Alternative Name:
                DNS:example.net, DNS:www.example.net
            X509v3 Certificate Policies:
                Policy: 2.23.140.1.2.1
            X509v3 CRL Distribution Points:
                Full Name:
                  URI:http://e6.c.lencr.org/96.crl

            CT Precertificate SCTs:
                Signed Certificate Timestamp:
                    Version   : v1 (0x0)
                    Log ID    : A4:42:C5:06:49:60:61:54:8F:0F:D4:EA:9C:FB:7A:2D:
                                26:45:4D:87:A9:7F:2F:DF:45:59:F6:27:4F:3A:84:54
                    Timestamp : Jul 18 12:53:48.288 2025 GMT
                    Extensions: none
                    Signature : ecdsa-with-SHA256
                                30:45:02:21:00:B2:57:32:6F:AF:55:9A:EA:6B:6D:D9:
                                E2:B7:7D:E6:4E:BE:1E:50:37:D6:0D:60:D8:7B:E9:96:
                                7E:DC:6C:9D:CB:02:20:3B:D8:2C:2E:6D:8B:49:82:53:
                                54:96:FD:45:A8:99:A3:59:C4:E7:36:9B:27:CF:BD:96:
                                56:DF:82:2F:52:11:FC
                Signed Certificate Timestamp:
                    Version   : v1 (0x0)
                    Log ID    : 1A:04:FF:49:D0:54:1D:40:AF:F6:A0:C3:BF:F1:D8:C4:
                                67:2F:4E:EC:EE:23:40:68:98:6B:17:40:2E:DC:89:7D
                    Timestamp : Jul 18 12:53:48.333 2025 GMT
                    Extensions: none
                    Signature : ecdsa-with-SHA256
                                30:46:02:21:00:9B:92:89:E2:63:EA:4A:1B:AC:DA:F3:
                                EF:14:EA:AA:DA:3B:6A:9F:68:3A:EC:5E:51:DC:7A:05:
                                C2:E4:02:56:1B:02:21:00:EB:4C:20:61:57:58:D8:7D:
                                3B:2D:EA:EC:C0:00:9D:7E:C2:7E:90:F5:B7:65:9E:CC:
                                18:D5:2B:05:DB:A2:D0:DE
    Signature Algorithm: ecdsa-with-SHA384
    Signature Value:
        30:66:02:31:00:b5:b4:c2:52:a6:52:8a:9c:ad:b1:7c:7a:d3:
        46:51:cf:3f:8c:21:f1:1b:fa:2d:67:de:53:42:de:29:fa:50:
        02:3f:61:1b:67:73:df:30:93:3c:24:7d:f1:fe:fe:1d:3a:02:
        31:00:fe:48:fb:d8:69:e5:53:f2:c8:e0:f3:ed:71:d8:cc:1b:
        0a:1a:5a:52:b3:f9:ac:25:a7:78:c2:5f:75:a9:0d:ee:62:
        ba:43:c7:ae:76:9f:cd:f8:91:61:3d:54:96:8b
```

## **Subject Distinguished Name**
- **ReactorCA**: `C=DE, ST=Berlin, L=Berlin, O=Reactor Industries, OU=Web Services, CN=host2.reactor.local, emailAddress=dc@reactor.de`
- **Let's Encrypt**: `CN=example.net`

**Meaning**: ReactorCA includes organizational context useful for internal certificate management. Let's Encrypt strips everything except the Common Name since they only verify domain ownership, not organizational details.

## **Public Key Algorithm & Size**
- **ReactorCA**: P-384 curve (384-bit key)
- **Let's Encrypt**: P-256 curve (256-bit key)

**Meaning**: ReactorCA uses stronger cryptography. P-384 provides ~192-bit security vs P-256's ~128-bit. For homelab use, P-256 is sufficient, but P-384 provides extra security margin at minimal computational cost on modern hardware.

## **Key Usage Extensions**
- **ReactorCA**: `Digital Signature, Key Encipherment`
- **Let's Encrypt**: `Digital Signature` only

**Meaning**: ReactorCA includes Key Encipherment for RSA-style key exchange (legacy TLS compatibility). Modern ECDHE eliminates this need - Let's Encrypt's approach is more current. The extra usage doesn't hurt but isn't necessary.

## **Missing Extensions in ReactorCA**

**Subject Key Identifier**: Let's Encrypt includes this for certificate chain validation. ReactorCA omits it - not critical for simple PKI but useful for complex certificate hierarchies.

**Authority Information Access**: Points to CA issuer certificate location. Let's Encrypt needs this for public trust chains. ReactorCA doesn't need it since certificates are distributed through configuration.

**Certificate Policies**: Let's Encrypt references WebPKI policy (2.23.140.1.2.1). ReactorCA omits this - appropriate since it's not following public CA policies.

**CRL Distribution Points**: Let's Encrypt provides revocation checking via HTTP. ReactorCA omits this - acceptable for homelab where certificate lifecycle is managed through configuration.

**CT Precertificate SCTs**: Certificate Transparency logging required for public CAs. ReactorCA correctly omits this since it's not subject to CT requirements.

ReactorCA's certificate structure is **perfectly appropriate** for its use case - a private homelab PKI focused on simplicity and direct management rather than public internet compatibility.
