FROM alpine

WORKDIR /app
COPY . .

RUN apk update && \
    apk upgrade && \
    apk add --no-cache bash sqlite jq git mc

RUN echo ""                   >> /etc/crontabs/root
RUN cat ./docker/cron.example >> /etc/crontabs/root
RUN echo ""                   >> /etc/crontabs/root


RUN apk add --no-cache msmtp mailx \
    && ln -sf /usr/bin/msmtp /usr/sbin/sendmail \
    && chown 82:82 -R /var/mail \
    && ln -s /etc/msmtprc.d/msmtprc /etc/msmtprc

VOLUME /app/conf
VOLUME /app/dat
VOLUME /app/log
VOLUME /kodi/userdata/Database
VOLUME /kodi/userdata/playlists/video
VOLUME /www
VOLUME /etc/crontabs
VOLUME /etc/msmtprc.d


CMD ["crond", "-f", "-d", "8"]
