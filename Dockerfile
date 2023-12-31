FROM alpine

WORKDIR /app
COPY . .

RUN apk update && \
    apk upgrade && \
    apk add --no-cache bash sqlite jq ssmtp git mc

RUN echo ""                   >> /etc/crontabs/root
RUN cat ./docker/cron.example >> /etc/crontabs/root
RUN echo ""                   >> /etc/crontabs/root

VOLUME /app/conf
VOLUME /app/dat
VOLUME /app/log
VOLUME /kodi/userdata/Database
VOLUME /kodi/userdata/playlists/video
VOLUME /www
VOLUME /etc/crontabs


CMD ["crond", "-f", "-d", "8"]