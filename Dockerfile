FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    strongswan \
    strongswan-swanctl \
    libcharon-extra-plugins \
    libcharon-extauth-plugins \
    libstrongswan-extra-plugins \
    iproute2 \
    iptables \
    ca-certificates \
    procps \
    kmod \
    && rm -rf /var/lib/apt/lists/*

COPY strongswan.conf /etc/strongswan.conf
COPY start.sh /start.sh

RUN chmod +x /start.sh \
    && test -f /usr/lib/ipsec/plugins/libstrongswan-eap-mschapv2.so

CMD ["/start.sh"]
