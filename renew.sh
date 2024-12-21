#!/bin/sh
#
# Original script Copyright (c) Johannes Feichtner <johannes@web-wack.at>
# Modified slightly for acme-esxi
#
# Released under the GNU GPLv3 License.

# shellcheck disable=SC1091,SC3060

DOMAIN=$(grep "adv/Misc/HostName" /etc/vmware/esx.conf | awk '{print $3}' | xargs)
LOCALDIR=$(dirname "$(readlink -f "$0")")
LOCALSCRIPT=$(basename "$0")

CONFDIR="/etc/acme-esxi"
ACMEDIR="$LOCALDIR/.well-known/acme-challenge"
DIRECTORY_URL="https://acme-v02.api.letsencrypt.org/directory"
SSL_CERT_FILE="$LOCALDIR/ca-certificates.crt"
RENEW_DAYS=30
OU="O=Let's Encrypt / CA"
REGENERATE_CERT=true
HTTP_PORT=8120

ACCOUNTKEY="esxi_account.key"
KEY="esxi.key"
CSR="esxi.csr"
CRT="esxi.crt"
VMWARE_CRT="/etc/vmware/ssl/rui.crt"
VMWARE_KEY="/etc/vmware/ssl/rui.key"
VMWARE_CA="/etc/vmware/ssl/castore.pem"

if [ -r "$LOCALDIR/renew.cfg" ]; then
  . "$LOCALDIR/renew.cfg"
fi

if [ -r "$CONFDIR/renew.cfg" ]; then
  . "$CONFDIR/renew.cfg"
fi

log() {
   echo "$@"
   logger -p daemon.info -t "$0" "$@"
}

log "Starting certificate renewal.";

# Preparation steps
if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "${DOMAIN/.}" ]; then
  log "Error: Hostname ${DOMAIN} is no FQDN."
  exit
fi

# Add a cronjob for auto renewal. The script is run once a week on Sunday at 00:00
if ! grep -q "$LOCALDIR/$LOCALSCRIPT" /var/spool/cron/crontabs/root; then
  kill -sighup "$(pidof crond)" 2>/dev/null
  echo "0    0    *   *   0   /bin/sh $LOCALDIR/$LOCALSCRIPT" >> /var/spool/cron/crontabs/root
  crond
fi

# Check issuer and expiration date of existing cert
if [ -e "$VMWARE_CRT" ]; then
  # If the cert is issued for a different hostname, request a new one
  SAN=$(openssl x509 -in "$VMWARE_CRT" -text -noout | grep DNS: | sed 's/DNS://g' | xargs)
  if [ "$SAN" != "$DOMAIN" ] ; then
    log "Existing cert issued for ${SAN} but current domain name is ${DOMAIN}. Requesting a new one!"
  # If the cert is issued by Let's Encrypt / CA or a private CA, check its expiration date, otherwise request a new one
  elif openssl x509 -in "$VMWARE_CRT" -issuer -noout | grep -q "$OU"; then
    CERT_VALID=$(openssl x509 -enddate -noout -in "$VMWARE_CRT" | cut -d= -f2-)
    log "Existing Let's Encrypt / CA cert valid until: ${CERT_VALID}"
    if openssl x509 -checkend $((RENEW_DAYS * 86400)) -noout -in "$VMWARE_CRT"; then
      log "=> Longer than ${RENEW_DAYS} days. Aborting."
      exit
    else
      log "=> Less than ${RENEW_DAYS} days. Renewing!"
    fi
  else
    log "Existing cert for ${DOMAIN} not issued by Let's Encrypt / CA / CA. Requesting a new one!"
  fi
fi

cd "$LOCALDIR" || exit
mkdir -p "$ACMEDIR"

# Route /.well-known/acme-challenge to port $HTTP_PORT
if ! grep -q "acme-challenge" /etc/vmware/rhttpproxy/endpoints.conf; then
  echo "/.well-known/acme-challenge local $HTTP_PORT redirect allow" >> /etc/vmware/rhttpproxy/endpoints.conf
  /etc/init.d/rhttpproxy restart
fi

# Cert Request
[ ! -r "$ACCOUNTKEY" ] && openssl genrsa 4096 > "$ACCOUNTKEY"

openssl genrsa -out "$KEY" 4096
openssl req -new -sha256 -key "$KEY" -subj "/CN=$DOMAIN" -config "./openssl.cnf" > "$CSR"
chmod 0400 "$ACCOUNTKEY" "$KEY"

# Start HTTP server on port $HTTP_PORT for HTTP validation
esxcli network firewall ruleset set -e true -r httpClient
python -m "http.server" "$HTTP_PORT" &
HTTP_SERVER_PID=$!

# Retrieve the certificate
export SSL_CERT_FILE
CERT=$(python ./acme_tiny.py --account-key "$ACCOUNTKEY" --csr "$CSR" --acme-dir "$ACMEDIR" --directory-url "$DIRECTORY_URL")

kill -9 "$HTTP_SERVER_PID"

# If an error occurred during certificate issuance, $CERT will be empty
if [ -n "$CERT" ] ; then
  echo "$CERT" > "$CRT"
  # Provide the certificate to ESXi
  cp -p "$LOCALDIR/$KEY" "$VMWARE_KEY"
  cp -p "$LOCALDIR/$CRT" "$VMWARE_CRT"
  cp -p "$SSL_CERT_FILE" "$VMWARE_CA"
  log "Success: Obtained and installed a certificate from Let's Encrypt / CA."
else
  if [ "$REGENERATE_CERT" = 'false' ]; then
  log "Error: No cert obtained from Let's Encrypt / CA. Generating a self-signed certificate."
  /sbin/generate-certificates
  fi
fi

for s in /etc/init.d/*; do if $s | grep ssl_reset > /dev/null; then $s ssl_reset; fi; done
