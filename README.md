# award_playlists

This script creates a smart playlist from a list of award-nominees from IMDB.
Sorted by number of nominations (ascending).

It parses the IMDBid from the webpage, looks them up in your own Kodi-movie-databse
and uses the localized titles of the movies to create the smartplaylist.
This is necessary, because some titles won't match in some languages.

Since your databse grows by the time (movies get added) you need to recreate the playlist every now and then.
Only movies wich are present in your databse get added to the playlist.

## dummy files

If you want to mark a movie as `watched` that is not in your databse, just create a dummy file that containes the string `TRAILERONLY` in the file name. This file should be a video file (like a downloaded trailer) so Kodi recognizes it as a video.
Like: `My.Movie.of.the.Year.2019.TRAILERONLY.mkv`  
Even if this movie is now technically in your database and can be marked as `watched` it will not be counted as such in this script.

## Requirements

 - edit the $USERDIR value so the script can find your MyVideoXX.db
   see: http://kodi.wiki/view/XBMC_databases#The_Video_Library
 - install "sqlite3"

## Docker

You can run this script in a Docker container.
The container itself is actually running cron and you can add your cronjobs to update your playlists.

### Build container

```shell
docker build . -t award_playlists
```

### Run container

Here is an examplke how to start the container via CLI:

```shell
docker run \
  --name=awards_playlists \
  -v award_playlists-config:/app/conf \
  -v award_playlists-data:/app/dat \
  -v award_playlists-www:/www \
  -v award_playlists-log:/app/log \
  -v award_playlists-cron:/etc/crontabs \
  -v /storage/.kodi/userdata/Database:/kodi/userdata/Database:ro \
  -v /storage/.kodi/userdata/playlists/video:/kodi/userdata/playlists/video \
  -v /etc/localtime:/etc/localtime:ro \
  -d \
  --restart=unless-stopped \
  award_playlists:latest
```

And a separat container for the web server

```shell
docker run \
  --name=awards_www \
  -v award_playlists-www:/usr/share/nginx/html:ro \
  -p 8081:80 \
  -v /etc/localtime:/etc/localtime:ro \
  -d \
  --restart=unless-stopped \
  nginx:alpine
```

### Docker volumes

There are several named volumes:

> VOLUME /app/conf
> VOLUME /app/dat
> VOLUME /app/log
> VOLUME /kodi/userdata/Database
> VOLUME /kodi/userdata/playlists/video
> VOLUME /www
> VOLUME /etc/crontabs
> VOLUME /etc/msmtprc.d

To customize the configuration you need to create `conf/custom.conf`(copy from `custom.conf.original`).

`/www` is mountet as read-only in the web-Container, too.

Edit `/etc/crontabs/root` to add/edit/remove cronjobs.

### Mail config

To send mails from inside the container you need to configure msmtp via the named volume `/etc/msmtprc.d`.

`/etc/msmtprc.d/msmtprc`:

```
# Set default values for all following accounts.
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
syslog         on

# Gmail
account        gmail
host           smtp.gmail.com
port           587
from           sender@example.com
user           sender@example.com
password       <your_Secret>
domain         mydomain.example.com

# Set a default account
account default : gmail
aliases        /etc/msmtprc.d/aliases
```

`/etc/msmtprc.d/aliases`:

```
root: me@example.com

default: me@example.com

```