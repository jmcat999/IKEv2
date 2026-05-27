FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    strongswan \
    strongswan-swanctl \
    strongswan-pki \
    libcharon-extra-plugins \
    libcharon-extauth-plugins \
    libstrongswan-extra-plugins \
    iproute2 \
    iptables \
    ca-certificates \
    gettext-base \
    procps \
    kmod \
    && rm -rf /var/lib/apt/lists/*

COPY config/strongswan.conf /etc/strongswan.conf
COPY config/swanctl.conf.template /etc/swanctl/swanctl.conf.template
COPY config/modes /etc/cat66-ikev2/modes
COPY config/start.sh /start.sh

RUN chmod +x /start.sh \
    && test -f /usr/lib/ipsec/plugins/libstrongswan-eap-mschapv2.so

CMD ["/start.sh"]
