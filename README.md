# award_playlists
This script creates a smart playlist from a list of award-nominees from IMDB.
Sorted by number of nominations (ascending).

It parses the IMDBid from the webpage, looks them up in your own Kodi-movie-databse
and uses the localized titles of the movies to create the smartplaylist.
This is necessary, because some titles won't match in some languages.

Since your databse grows by the time (movies get added) you need to recreate the playlist every now and then.
Only movies wich are present in your databse get added to the playlist.

Requirements:
 - edit the $USERDIR value so the script can find your MyVideoXX.db
   see: http://kodi.wiki/view/XBMC_databases#The_Video_Library
 - install "sqlite3"
