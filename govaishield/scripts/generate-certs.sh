#!/usr/bin/env bash
set -uo pipefail
mkdir -p certs
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout certs/ca.key -out certs/ca.crt -subj "/CN=GovAI Shield Dev CA"
openssl req -newkey rsa:2048 -nodes -keyout certs/server.key -out certs/server.csr -subj "/CN=api-gateway"
openssl x509 -req -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/server.crt -days 365
echo "✅ certs/ gerado (SÓ para dev!)"
