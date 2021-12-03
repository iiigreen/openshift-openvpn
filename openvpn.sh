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


if [ "x$OPENVPN_USER" == "x" -o "x$OPENVPN_PASS" == "x" ]; then
    echo "Error: OPENVPN_USER and OPENVPN_PASS environment variables must be set"
    exit 1
fi

echo -e "$OPENVPN_USER\n$OPENVPN_PASS" > openvpn_creds

echo -e "\n\nUse this as OVPN confing file, for example opensift.ovn"
echo "#----------------------------------------------------------"
echo "client"
echo "dev tun"
echo "proto tcp"
echo "remote yourhost.tld/IP 31194"
echo "auth-user-pass"
echo "<ca>"
cat $CA_CRT
echo "</ca>"
echo "#----------------------------------------------------------"

KUBE_SERVICE_NETWORK=`echo $KUBERNETES_SERVICE_HOST | awk -F . '{print $1"."$2".0.0"}'`
DNS_SERVER=`grep nameserver /etc/resolv.conf | head -n 1 | xargs -n 1 | grep -v "^nameserver$"`
SEARCH_DOMAIN=`grep search /etc/resolv.conf | xargs -n 1 | grep -v "^search$" | head -n 1`

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
	--tun-mtu 1100 \
        --push "route $KUBE_SERVICE_NETWORK 255.255.0.0" \
        --push "dhcp-option DNS $DNS_SERVER" \
        --push "dhcp-option DOMAIN $SEARCH_DOMAIN"
