FROM nginx
LABEL maintainer=nick@nickrandell.com

VOLUME /etc/letsencrypt
EXPOSE 443

RUN apt-get update && \
    apt-get install -y --no-install-recommends certbot python3-certbot-dns-dnsimple

RUN rm -f /etc/nginx/conf.d/*

COPY scripts/ /scripts
RUN chmod +x /scripts/*.sh


ENTRYPOINT [ ]
CMD ["/bin/bash", "/scripts/run.sh"]
