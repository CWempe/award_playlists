#!/bin/sh
#################################################################################################################
#
# by Christoph Wempe
# 2015-12-29
#
# This script creates a smart playlist from a list of award-nominees from IMDB.
# Sorted by number of nominations (ascending).
#
# It parses the IMDB-ID from the webpage, looks them up in your own Kodi-movie-databse
# and uses the localized titles of the movies to create the smartplaylist.
# This is necessary, because some titles won't match in some languages.
# 
# Since your databse grows by the time (movies get added) you need to recreate the playlist every now and then.
# Only movies wich are present in your databse get added to the playlist.
#
# Requirements:
#  - edit the $USERDIR value so the script can find your MyVideoXX.db
#    see: http://kodi.wiki/view/XBMC_databases#The_Video_Library
#  - install "sqlite3"
#
#################################################################################################################




####
# define default values
####

# Year
YEAR=`date +%Y`
# Event
EVENT="G"

####
# file owner
####
USER="vdr"
GROUP="audio"

# VERBOSE (0/1)
VERBOSE="0"
# Debug (0/1)
DEBUG="0"
# Force (0/1)
FORCE="0"
# xRel (0/1)
XREL="0"


echo ""
echo "####################### "`date`" #######################"


while getopts vdfe:y:x opt
  do
    case $opt in
      v)      # Verbose
        VERBOSE="1"
        ;;
      d)      # DEBUG
        DEBUG="1"
        VERBOSE="1"
        ;;
      f)      # force
        FORCE=1
        ;;
      e)      # event
        EVENTARG="$OPTARG"
        if [ "$VERBOSE" -eq 1 ]
          then
            echo -e "Argument -e : $OPTARG"
        fi
        ;;
      y)      # year
        YEAR="$OPTARG"
        if [ "$VERBOSE" -eq 1 ]
          then
            echo -e "Argument -y : $OPTARG"
        fi
        ;;
      x)      # xRel
        XREL="1"
        ;;
      \?)     # Ungueltige Option
        echo "usage: $0 [-v] [-d] [-f] [-e E] [-y YYYY]"
        echo "example: $0 -vdf -e G -y 2013"
        echo "          [-v] Verbose-Mode: "
        echo "          [-d] Debug-Mode: No Files removed"
        echo "          [-f] Force-Mode: Download new Nominee-List; Overwrite existing ID-File"
        echo "          [-e] Event: Specify the Event"
        echo "                 (A)cademy Awards"
        echo "                 (G)olden Globes"
        echo "          [-y] Year: Specify the year of the Event"
        echo "          [-x] xRel: Create HTML-file with links to xRel.to"
        exit 2
        ;;
  esac
done



# Define Event
case $EVENTARG in
  b|B )
    EVENT="BAFTA"
    EVENTSTRING="bafta"
    EVENTID="ev0000123"
    ;;
  g|G )
    EVENT="Golden Globe Awards"
    EVENTSTRING="golden-globes"
    EVENTID="ev0000292"
    ;;
  a|A|o|O|* )
    EVENT="Academy Awards"
    EVENTSTRING="oscars"
    EVENTID="ev0000003"
    ;;
esac


echo "### $EVENT $YEAR"


# Prefix for filenames
FILENAMEPREFIX="nominees_"$EVENTSTRING"_"$YEAR

# Define files and directories
BINDIR="/home/christoph/skripte/award_playlists"
DATDIR="$BINDIR/dat"
TMPDIR="$BINDIR/tmp"

### Change this paths to your enviroment ###
# Path to XBMC-directory
USERDIR="/var/lib/vdr/.xbmc/userdata"
DBDIR="$USERDIR/Database"
PLVDIR="$USERDIR/playlists/video"
PLVEVENTDIR="$PLVDIR/$EVENT"

# newest MyVideo-database from XBMC
DBFILE=`ls -t $DBDIR/MyVideos*.db | head -1`
# URL to IMDB-Nominee-List
NOMINEEURL="http://www.imdb.com/event/$EVENTID/$YEAR"
# temp-file for IMDB-Nominee-List
NOMINEEHTML="$TMPDIR/$FILENAMEPREFIX.html"
# temp-file for IMDB-Nominee-List
IDSFILE="$DATDIR/$FILENAMEPREFIX.ids"
# filename of playlist
PLAYLISTFILE="$PLVEVENTDIR/$FILENAMEPREFIX.xsp"
# title of playlist
PLAYLISTNAME="$EVENT Awards ($YEAR)"
# xRel.to-webpage
XRELFILE="$DATDIR/"$FILENAMEPREFIX"_xrel.html"


if [ "$VERBOSE" -eq 1 ]
  then
    echo -e ""
    echo -e "Variables:"
    echo -e " DEBUG:       $DEBUG"
    echo -e " VERBOSE:     $VERBOSE"
    echo -e " FORCE:       $FORCE"
    echo -e " XREL:        $XREL"
    echo -e " YEAR:        $YEAR"
    echo -e " EVENTID:     $EVENTID"
    echo -e " EVENTSTRING: $EVENTSTRING"
    echo -e " EVENT:       $EVENT"
    echo -e ""
    echo -e "Files:"
    echo -e " DBFILE:       $DBFILE"
    echo -e " NOMINEEURL:   $NOMINEEURL"
    echo -e " NOMINEEHTML:  $NOMINEEHTML"
    echo -e " IDSFILE:      $IDSFILE"
    echo -e " PLAYLISTFILE: $PLAYLISTFILE"
    echo -e " XRELFILE:     $XRELFILE"
    echo -e ""
fi


if [ ! -d $DATDIR ]
  then
    echo -e "\$DATDIR does not exist. Creating it now ..."
    mkdir $DATDIR
fi

if [ ! -d $TMPDIR ]
  then
    echo -e "\$TMPDIR does not exist. Creating it now ..."
    mkdir $TMPDIR
fi

if [ ! -s $DBFILE ]
  then
    if [ "$VERBOSE" -eq 1 ]
      then
        echo -e "Database does not exist or is empty."
    fi
    exit 1
fi

if [ ! -d "$PLVEVENTDIR" ]
  then
    if [ "$VERBOSE" -eq 1 ]
      then
        echo -e "Event-Playlist-Directory does not exist yet.\nWill create folder now."
    fi
    mkdir "$PLVEVENTDIR"
    chown $USER:$GROUP "$PLVEVENTDIR"
fi



####
# Downloading list of nominees from imdb.com and generate ID-File if not already existing
####

# check if $IDSFILE exists (and is not empty)
if [ ! -s $IDSFILE -o "$FORCE" -eq 1 ]
  then
    # $IDSFILE does not exist or is empty or force-mode is enabled

    # check if $NOMINEEHTML does not exist or force-mode is enabled
    if [ ! -s $NOMINEEHTML -o "$FORCE" -eq 1 ]
      then
        # Downloading list of nominees from imdb.com
        echo -e "Downloading list of nominees from imdb.com ..."
        wget $NOMINEEURL -O $NOMINEEHTML -q
      else
        echo -e "Using existing \$NOMINEEHTML."
      fi

    # Get IMDB-IDs from nominee-list
    echo -e "Get IMDB-IDs from nominee-list ..."
#    cat $NOMINEEHTML | sed 's/href.*<img.*>/XXXXX/g' | grep -Ev ".*{.*{.*{.*{.*{.*" | grep -oE "tt[0-9]{7}" | sort | uniq -c | sort -nr > $IDSFILE
    cat $NOMINEEHTML | perl -0777 -pi -e 's/Television\ Series(\n|.)*?<h2>/XXXXXX/g' | sed 's/href.*<img.*>/XXXXX/g' | grep -Ev ".*{.*{.*{.*{.*{.*" | grep -oE "tt[0-9]{7}" | sort | uniq -c | sort -nr > $IDSFILE

  else
    # $IDSFILE is present and not empty
    if [ "$VERBOSE" -eq 1 ]
      then
        echo -e "Use existing IDS-File."
    fi
fi

# Count nominees
NOMINEESCOUNT=`wc -l $IDSFILE | awk '{print $1}'`


####
# Generate Playlist
####

if [ $NOMINEESCOUNT -eq 0 ]
  then
    echo -e "No nominees.\nNothing to do."
  else

    ####
    # Printing header to playlist
    ####
    echo -e "Printing header to playlist ..."
    echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>"           >  "$PLAYLISTFILE"
    echo -e "<!-- This Smartplaylist was created by \"$0\" at `date +%F\ %T` -->"      >> "$PLAYLISTFILE"
    echo -e "<smartplaylist type=\"movies\">"                                          >> "$PLAYLISTFILE"
    echo -e "  <name>$PLAYLISTNAME</name>"                                             >> "$PLAYLISTFILE"
    echo -e "  <match>one</match>"                                                     >> "$PLAYLISTFILE"

    if [ $VERBOSE -eq 1 ]
      then
        echo -e "Getting movietitles and printing them to playlist ..."
    fi
    cat $IDSFILE | awk -v DB="$DBFILE" '{print "sqlite3 "DB" \"SELECT c00, playCount, '\''"$1"'\'' as nominations FROM movieview WHERE c09 IS '\''"$2"'\'' GROUP BY c00\""}' | sh \
             | awk -F \| '{print "  <rule field=\"title\" operator=\"is\">"$1"</rule>\n    <!--  playCnt = "$2"  noms = "$3"  -->\n"}'    >> "$PLAYLISTFILE"
    
    ####
    # Printing infos and footer to playlist
    ####
    MOVIECOUNT=`grep "playCnt" "$PLAYLISTFILE" | wc -l | awk '{print $1}'`
    WATCHEDCOUNT=`grep -Eo "playCnt = [0-9]+" "$PLAYLISTFILE" | wc -l | awk '{print $1}'`

    if [ $VERBOSE -eq 1 ]
      then
        echo -e "Printing infos and footer to playlist ..."
    fi
    echo -e "    <!--"                                          >> "$PLAYLISTFILE"
    echo -e "      Total nominees:  $NOMINEESCOUNT"             >> "$PLAYLISTFILE"
    echo -e "      in your databse: $MOVIECOUNT"                >> "$PLAYLISTFILE"
    echo -e "      already watched: $WATCHEDCOUNT"              >> "$PLAYLISTFILE"
    echo -e "    -->"                                           >> "$PLAYLISTFILE"
    echo -e "  <order direction="descending">rating</order>"    >> "$PLAYLISTFILE"
    echo -e "</smartplaylist>"                                  >> "$PLAYLISTFILE"
    
    ####
    # Change owner of file
    ####
    chown $USER:$GROUP "$PLAYLISTFILE"


    ####
    # Printing Infos to stdout
    ####
    echo -e ""
    echo -e "Total nominees:  $NOMINEESCOUNT"
    echo -e "in your databse: $MOVIECOUNT"
    echo -e "already watched: $WATCHEDCOUNT"
    echo -e ""
    
    
    ####
    # Create HTML-file with links to xRel.to
    ####
    if [ "$XREL" -eq 1 ]
      then
        echo -e "<b>$PLAYLISTNAME</b><br><br>" > $XRELFILE
        if [ $VERBOSE -eq 1 ]
          then
            echo -e "Create HTML-file with links to xRel.to ..."
        fi
    
        while read LINE; do
          ID=`echo $LINE | awk '{print $2}'`
          #echo "sqlite3 \"$DBFILE\" \"SELECT c00 FROM movieview WHERE c09 IS '$ID' GROUP BY c00\""
          TITLE=`sqlite3 "$DBFILE" "SELECT c00, playCount FROM movieview WHERE c09 IS '$ID' GROUP BY c00" | awk -F \| '{print $1}'`
          echo "<a>$TITLE ($ID)<br>" >> $XRELFILE
          echo "<a target=\"_blank\" href=\"http://www.imdb.com/title/$ID/\">IMDB</a>" >> $XRELFILE
          echo "<a target=\"_blank\" href=\"http://www.xrel.to/search.html?xrel_search_query=$ID\">xRel</a><br><br>" >> $XRELFILE
        done < $IDSFILE

    fi

fi


####
# Deleting temp-files
####


if [ $DEBUG -ne 1 ]
  then
    echo -e "Deleting temp-files ..."
    if [ -s $NOMINEEHTML ]
      then
        rm $NOMINEEHTML
      else
        if [ $VERBOSE -eq 1 ]
          then
            echo -e "No file to delete."
        fi
    fi
  else
    if [ $VERBOSE -eq 1 ]
      then
        echo -e "Not deleting temp-files."
    fi
fi

echo -e "Finished."
exit 0