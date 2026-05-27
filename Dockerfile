FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    strongswan \
    strongswan-swanctl \
    libcharon-extra-plugins \
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
COPY config/start.sh /start.sh

RUN chmod +x /start.sh

CMD ["/start.sh"]
