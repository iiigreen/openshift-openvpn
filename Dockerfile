FROM ubi8

MAINTAINER Ivan Zelenov <izelenov@bcc.ru>

EXPOSE 8080/tcp

RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && yum install -y openvpn easy-rsa && yum install -y iptables

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

CMD ["/opt/openvpn/openvpn.sh"]
