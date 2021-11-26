FROM docker.io/openshift/base-centos7

MAINTAINER Ivan Zelenov <izelenov@bcc.ru>

EXPOSE 8080/tcp

RUN yum install -y epel-release && yum install -y openvpn easy-rsa

ENV OPENVPN_DIR=/opt/openvpn

RUN mkdir -p /dev/net \
    && if [ ! -c /dev/net/tun ]; then mknod /dev/net/tun c 10 200; fi \
    && mkdir -p ${OPENVPN_DIR} && \
    cp -r /usr/share/easy-rsa/3.0/ ${OPENVPN_DIR}/easy-rsa

# Generate CA and server certificates
RUN cd ${OPENVPN_DIR}/easy-rsa \
    && ./easyrsa init-pki \
    && echo | ./easyrsa build-ca nopass \
    && ./easyrsa build-server-full server nopass \
    && ./easyrsa gen-dh

COPY openvpn.sh ${OPENVPN_DIR}/openvpn.sh

COPY verify_user_pass.sh client_command.sh updown.sh /${OPENVPN_DIR}/

CMD ["${OPENVPN_DIR}/openvpn.sh"]
