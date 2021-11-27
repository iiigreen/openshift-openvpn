#!/bin/bash

# TODO: Let user supply their own CA and Server certs instead
#       of using the autogenerated ones from the Docker image
# TODO: user/pass is hardcoded to foo/bar in verify_user_pass.sh
# TODO: 10.2.3.0 network is hardcoded

VERB=1

if [ "$DEBUG" == "true" ]; then
    set -x
    VERB=4
fi

set -e

KEY_DIR=${OPENVPN_DIR}/easy-rsa/pki
CA_CRT=${KEY_DIR}/ca.crt

echo -e "\n\nSave this CA certificate to a file for use in your VPN client\n"
cat $CA_CRT

if [ "x$OPENVPN_USER" == "x" -o "x$OPENVPN_PASS" == "x" ]; then
    echo "Error: OPENVPN_USER and OPENVPN_PASS environment variables must be set"
    exit 1
fi

echo -e "$OPENVPN_USER\n$OPENVPN_PASS" > openvpn_creds

KUBE_SERVICE_NETWORK=`echo $KUBERNETES_SERVICE_HOST | awk -F . '{print $1"."$2".0.0"}'`
DNS_SERVER=`grep nameserver /etc/resolv.conf | head -n 1 | xargs -n 1 | grep -v "^nameserver$"`

mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then mknod /dev/net/tun c 10 200; fi

iptables -F

openvpn --dev tun0 \
        --persist-tun \
        --script-security 3 \
        --verb $VERB \
        --client-connect ${OPENVPN_DIR}/client_command.sh \
        --client-disconnect ${OPENVPN_DIR}/client_command.sh \
        --up ${OPENVPN_DIR}/updown.sh \
        --down ${OPENVPN_DIR}/updown.sh \
        --dh ${KEY_DIR}/dh.pem \
        --ca $CA_CRT \
        --cert ${KEY_DIR}/issued/server.crt \
        --key ${KEY_DIR}/private/server.key \
        --verify-client-cert optional \
        --auth-user-pass-verify ${OPENVPN_DIR}/verify_user_pass.sh via-env \
        --server 10.2.3.0 255.255.255.0 \
        --proto tcp-server \
        --topology subnet \
        --keepalive 10 60 \
        --push "route $KUBE_SERVICE_NETWORK 255.255.0.0" \
        --push "dhcp-option DNS $DNS_SERVER" \
