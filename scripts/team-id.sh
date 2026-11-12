#!/bin/bash
set -euo pipefail

team_id=$(security find-certificate -c "Apple Development" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | sed -E 's/.*OU[[:space:]]*=[[:space:]]*([^,\/]+).*/\1/' | head -1)
[[ "$team_id" =~ ^[A-Z0-9]{10}$ ]] || exit 1
printf '%s\n' "$team_id"
