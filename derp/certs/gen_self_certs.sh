#!/bin/bash

# Useage: ./gen_self_certs.sh <domain/ip>

DOMAIN=$1

cat >openssl.cnf <<EOF
[req]
default_bits = 2048
encrypt_key = no
prompt = no
utf8 = yes
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
CN = $DOMAIN

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = $DOMAIN
EOF

openssl req -x509 -newkey rsa:2048 -nodes -keyout "$DOMAIN".key -out "$DOMAIN".crt \
    -days 365 -config openssl.cnf -extensions v3_req
