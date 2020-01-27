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
