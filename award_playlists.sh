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
# TV shows (0/1)
TV="0"
# Mail address
MAIL=""
# Statistics (0/1)
STATS="1"
# xRel (0/1)
XREL="0"


echo ""
echo "####################### "`date`" #######################"


while getopts vdfe:m:y:t:sx opt
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
      m)      # mail address
        MAIL="$OPTARG"
        if [ "$VERBOSE" -eq 1 ]
          then
            echo -e "Argument -m : $OPTARG"
        fi
        ;;
      y)      # year
        YEAR="$OPTARG"
        if [ "$VERBOSE" -eq 1 ]
          then
            echo -e "Argument -y : $OPTARG"
        fi
        ;;
      t)      # TV shows
        if [ "$VERBOSE" -eq 1 ]
          then
            echo -e "Argument -t : $OPTARG"
        fi
        if [ "$OPTARG" = "yes" -o "$OPTARG" = "no" ]
        then
          TV="$OPTARG"
        else
          echo "Argument for -t is not 'yes' or 'no'. Use default."
        fi
        ;;
      s)      # Stastics
        if [ "$MAIL" == "" ]
          then
            STATS="0"
          else
            # stats are needed to send mail
            STATS="0"
        fi
        ;;
      x)      # xRel
        XREL="1"
        ;;
      \?)     # Ungueltige Option
        echo "usage: $0 [-v] [-d] [-f] [-e E] [-y YYYY] [-t yes|no] [-x]"
        echo "example: $0 -vdf -e G -y 2013"
        echo "          [-v] Verbose-Mode: Print more output"
        echo "          [-d] Debug-Mode: No Files removed"
        echo "          [-f] Force-Mode: Download new Nominee-List; Overwrite existing ID-File"
        echo "          [-e] Event: Specify the Event"
        echo "                 (A)cademy Awards or (O)scars"
        echo "                 (B)AFTAS"
        echo "                 (C)ritics Choice Awards"
        echo "                 (G)olden Globes Awards"
        echo "                 (I)ndependent Spirit Awards"
        echo "          [-m] Mail: Specify the mail address to send the statistics to"
        echo "          [-y] Year: Specify the year of the Event"
        echo "          [-t] TV: Overrides the default to create or not create a playlist for nominated tv shows (without IMDBid)"
        echo "          [-s] Statistics: do NOT create a file with statistics"
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
    TV="no"
    ;;
  c|C )
    EVENT="Critics Choice"
    EVENTSTRING="critics"
    EVENTID="ev0000133"
    TV="no"
    ;;
  g|G )
    EVENT="Golden Globe Awards"
    EVENTSTRING="golden-globes"
    EVENTID="ev0000292"
    if [ "$TV" != "no" ]
    then
      TV="yes"
    fi
    ;;
  i|I )
    EVENT="Independent Spirit"
    EVENTSTRING="independant"
    EVENTID="ev0000349"
    TV="no"
    ;;
  a|A|o|O|* )
    EVENT="Academy Awards"
    EVENTSTRING="oscars"
    EVENTID="ev0000003"
    TV="no"
    ;;
esac


echo "### $EVENT $YEAR"


# Define files and directories
BINDIR="$( cd "$(dirname "$0")" ; pwd -P )"
# " to correct syntax highlichting in mcedit
CONFDIR="$BINDIR/conf"
# custom config file
CONFIG="$CONFDIR/custom.conf"

# Check if config file exists
if [ ! -f "$CONFIG" ]
  then
    echo -e "Config file does not exist!\nPlease copy custom.conf.original to custom.conf"
    exit 1
fi
# import custom config
source "$CONFIG"


if [ "$VERBOSE" -eq 1 ]
  then
    echo -e ""
    echo -e "Variables:"
    echo -e " DEBUG:          $DEBUG"
    echo -e " VERBOSE:        $VERBOSE"
    echo -e " FORCE:          $FORCE"
    echo -e " TV:             $TV"
    echo -e " STATS:          $STATS"
    echo -e " XREL:           $XREL"
    echo -e " FROM:           $FROM"
    echo -e " MAIL:           $MAIL"
    echo -e " SUBJECT:        $SUBJECT"
    echo -e " YEAR:           $YEAR"
    echo -e " EVENTID:        $EVENTID"
    echo -e " EVENTSTRING:    $EVENTSTRING"
    echo -e " EVENT:          $EVENT"
    echo -e ""
    echo -e "Files:"
    echo -e " DBFILE:         $DBFILE"
    echo -e " NOMINEEURL:     $NOMINEEURL"
    echo -e " NOMINEEHTML:    $NOMINEEHTML"
    echo -e " IDSFILE:        $IDSFILE"
    echo -e " PLAYLISTFILE:   $PLAYLISTFILE"
    echo -e " PLAYLISTFILETV: $PLAYLISTFILETV"
    echo -e " XRELFILE:       $XRELFILE"
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


# creatre backup of statistics file
if [ -f "$STATFILE" ]
  then
    cp "$STATFILE" "$STATFILEOLD"
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
    cat $NOMINEEHTML | sed 's/href.*<img.*>/XXXXX/g' | grep -Ev ".*{.*{.*{.*{.*{.*" | grep -oE "tt[0-9]{7}.*</a" \
      | sed 's/\/"\ >/\ /g' | sed 's/<\/a//' | sort | uniq -c | sort -nr > $IDSFILE

  else
    # $IDSFILE is present and not empty
    if [ "$VERBOSE" -eq 1 ]
      then
        echo -e "Use existing IDS-File."
    fi
fi

# Count nominees
NOMINEESCOUNT=`wc -l $IDSFILE | awk '{print $1}'`
MOVIECOUNT=0
WATCHEDCOUNT=0


####
# Generate Playlist
####

if [ $NOMINEESCOUNT -eq 0 ]
  then
    STATTEXT="No nominees!"
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

    if [ "$TV" = "yes" ]
      then
        ####
        # Printing header to playlist for tv shows
        ####
        echo -e "Printing header to playlist for tv shows..."
        echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>"           >  "$PLAYLISTFILETV"
        echo -e "<!-- This Smartplaylist was created by \"$0\" at `date +%F\ %T` -->"      >> "$PLAYLISTFILETV"
        echo -e "<smartplaylist type=\"tvshows\">"                                         >> "$PLAYLISTFILETV"
        echo -e "  <name>$PLAYLISTNAMETV</name>"                                           >> "$PLAYLISTFILETV"
        echo -e "  <match>one</match>"                                                     >> "$PLAYLISTFILETV"
    fi

    ####
    # Create header for HTML-file
    ####
    if [ "$XREL" -eq 1 ]
    then
      # 
      echo -e "<!DOCTYPE html>\n<html lang=\"en\">"                                       >  $XRELFILE
      echo -e "<head>"                                                                    >> $XRELFILE
      echo -e "    <meta charset=\"utf-8\"/>"                                             >> $XRELFILE
      echo -e "    <link rel=\"stylesheet\" type=\"text/css\" href=\"$CSSFILE\" />"       >> $XRELFILE
      echo -e "</head>"                                                                   >> $XRELFILE
      echo -e "<body>"                                                                    >> $XRELFILE
      echo -e "    <h1>$PLAYLISTNAME</h1>"                                                >> $XRELFILE
      echo -e "    <h2>Movies</h2>"                                                       >> $XRELFILE
      echo -e "    <table>"                                                               >> $XRELFILE
      echo -e "      <thead>"                                                             >> $XRELFILE
      echo -e "        <tr>"                                                              >> $XRELFILE
      echo -e "          <th title=\"Number\">#</th>"                                     >> $XRELFILE
      echo -e "          <th title=\"in Database\">&#x1F4E5;</th>"                        >> $XRELFILE
      echo -e "          <th title=\"watched\">&#x1F453;</th>"                            >> $XRELFILE
      echo -e "          <th title=\"Realeases-NFO\">&#x1F4DC;</th>"                      >> $XRELFILE
      echo -e "          <th title=\"amount of nominations\">&#x1F3C6;</th>"              >> $XRELFILE
      echo -e "          <th title=\"Movietitle\">Title</th>"                             >> $XRELFILE
      echo -e "        </tr>"                                                             >> $XRELFILE
      echo -e "      </thead>"                                                            >> $XRELFILE
      echo -e "      <tbody>"                                                             >> $XRELFILE
      
      # copy css file is necessary
      if [ ! -f "$CSSSOURCE" ]
        then
            if [ $VERBOSE -eq 1 ]
              then
                echo -e "css file does not exist!"
            fi
            exit 1
        else
            if [ $VERBOSE -eq 1 ]
              then
                echo -e "Copy css file to html directory."
            fi
            cp "$CSSSOURCE" "$CSSDEST"
      fi
    fi

    if [ $VERBOSE -eq 1 ]
      then
        echo -e "Getting movietitles and printing them to playlist ..."
    fi


    # Read ID and find title
    while read LINE
    do
      NOMINATIONS=`echo "$LINE" | awk '{print $1}'`
      ID=`echo $LINE | awk '{print $2}'`
      TITLE=`echo $LINE | cut -c 13-`
      # Search title in Database using IMDBid
      SQLRESULT=`sqlite3 $DBFILE "SELECT c00, playCount, '"$NOMINATIONS"' as nominations FROM movieview WHERE c09 IS '"$ID"' GROUP BY c00 LIMIT 1"`
      TITLESQL=`echo $TITLE | sed 's/&/%/g'`

      if [ "$SQLRESULT" != "" ]
      then
        PLAYCOUNT=`echo "$SQLRESULT" | awk -F \| '{print $2}'`
        TITLE=`echo "$SQLRESULT" | awk -F \| '{print $1}'`
        INDATABASE="yes"
        # replace certain characters in title to match sql syntax
        TITLESQL=`echo $TITLE | sed 's/&/%/g'`

        # increment MOVIECOUNT
        MOVIECOUNT=$((MOVIECOUNT+1))

        
        if [ "$PLAYCOUNT" = "" ]
        then
          PLAYCOUNT=0
        else
          # increment MOVIECOUNT
          WATCHEDCOUNT=$((WATCHEDCOUNT+1))
        fi

        # Write in playlist
        echo -e "  <rule field=\"title\" operator=\"is\">$TITLESQL</rule>" \
          >> "$PLAYLISTFILE"

      else
        PLAYCOUNT=0
        INDATABASE="no"
        if [ "$TV" = "yes" ]
          then
             # write in tv playlist
             echo -e "<rule field=\"title\" operator=\"is\">$TITLESQL</rule>" \
              >> "$PLAYLISTFILETV"
        fi
      fi

      if [ $VERBOSE -eq 1 ]
        then
          echo -e "$TITLE:\n  PLAYCOUNT: $PLAYCOUNT"
      fi


      if [ $PLAYCOUNT -gt 0 ]
      then 
        WATCHED="yes"
      else
        WATCHED="no"
      fi

      ####
      # Create HTML-file with links to xRel.to
      ####
      if [ "$XREL" -eq 1 ]
      then

        echo -e  "        <tr>"                                                                                        >> $XRELFILE
        echo -e  "          <td title=\"number\"        class=\"number\"></td>"                                         >> $XRELFILE
        echo -en "          <td title=\"in Database?\"  class=\"db $INDATABASE\">"                                      >> $XRELFILE
        if [ "$INDATABASE" = "yes" ]
        then
          # check mark
          echo -en "&#10004;"   >> $XRELFILE
        else
          # X
          echo -en "&#10006;"   >> $XRELFILE
        fi
        echo -e         " </td>"                                                                                       >> $XRELFILE
        echo -en "          <td title=\"watched?\"      class=\"watched $WATCHED\">"                                    >> $XRELFILE
        if [ "$WATCHED" = "yes" ]
        then
          # check mark
          echo -en "&#10004;"   >> $XRELFILE
        else
          # X
          echo -en "&#10006;"   >> $XRELFILE
        fi
        echo -e          "</td>"                                                                                       >> $XRELFILE
        echo -en  "          <td title=\"Realeases-NFO\" class=\"nfo\">"                                               >> $XRELFILE
        echo -en               "<a target=\"_blank\" href=\"http://www.xrel.to/search.html?xrel_search_query=$ID\">"   >> $XRELFILE
        echo -e                "<img src=\"http://www.xrel.to/favicon.ico\" alt=\"xREL\"/></a></td>"                   >> $XRELFILE
        echo -e  "          <td title=\"\">$NOMINATIONS</td>"                                                          >> $XRELFILE
        echo -en "          <td title=\"Movietitle\" class=\"title\">"                                                 >> $XRELFILE
        echo -e              "<a target=\"_blank\" href=\"http://www.imdb.com/title/$ID/\">$TITLE</a></td>"            >> $XRELFILE
        echo -e "        </tr>"                                                                                        >> $XRELFILE

      fi

    done < "$IDSFILE"


    ####
    # Printing footer to playlist
    ####

    if [ $VERBOSE -eq 1 ]
      then
        echo -e "Printing footers ..."
    fi
    echo -e "</smartplaylist>"                                  >> "$PLAYLISTFILE"
    
    if [ "$TV" = "yes" ]
      then
        echo -e "</smartplaylist>"                               >> "$PLAYLISTFILETV"
    fi


    ####
    # Create statistics
    ####
    STATTEXT="Total nominees:  $NOMINEESCOUNT\nin your databse: $MOVIECOUNT\nalready watched: $WATCHEDCOUNT"

    ####
    # Change owner of file
    ####
    chown $USER:$GROUP "$PLAYLISTFILE"
    if [ "$TV" = "yes" ]
      then
         chown $USER:$GROUP "$PLAYLISTFILETV"
    fi

    ####
    # Create footer for HTML-file
    ####
    if [ "$XREL" -eq 1 ]
    then
      echo -e  "      </tbody>"                                  >> $XRELFILE
      echo -e  "    </table>"                                    >> $XRELFILE
      echo -e  "    <h2>Statistics</h2>"                         >> $XRELFILE
      echo -e  "    <div class=\"statistics\">"                  >> $XRELFILE
      echo -en "        Total nominees:  $NOMINEESCOUNT<br>"     >> $XRELFILE
      echo -en         "in your databse: $MOVIECOUNT<br>"        >> $XRELFILE
      echo -en         "already watched: $WATCHEDCOUNT<br>"      >> $XRELFILE
      echo -en "    </div>"                                      >> $XRELFILE
      echo -e  "</body>"                                         >> $XRELFILE
    fi
fi


####
# Printing Infos to stdout and optionally to stats file
####
echo -e ""
echo -e "$STATTEXT"
echo -e ""

if [ $STATS -eq 1 ]
then
  if [ $VERBOSE -eq 1 ]
    then
      echo -e "Printing statistics ..."
  fi
  echo -e "$STATTEXT" > "$STATFILE"
fi



# check if stats have changed since last run


if [ "$MAIL" != "" ]
  then
    
    if [ -f "$STATFILEOLD" ]
      then
        STATDIFF=$(diff $STATFILE $STATFILEOLD)
      else
        STATDIFF="new"
    fi

    if [ "$STATDIFF" != "" ]
      then
        if [ $VERBOSE -eq 1 ]
          then
            echo -e "Stats changed. Sending mails."
        fi
        echo -e "From: $FROM\nSubject: $SUBJECT\n\n$STATTEXT" | $SENDMAIL $MAIL
      else
        if [ $VERBOSE -eq 1 ]
          then
            echo -e "Stats did not change. Not ending mail."
        fi
    fi        
fi


####
# Deleting temp-files
####

if [ $DEBUG -ne 1 ]
  then
    echo -e "Deleting temp-files ..."
    if [ -s "$NOMINEEHTML" ]
      then
        rm "$NOMINEEHTML"
    fi
    if [ -f "$STATFILEOLD" ]
      then
        rm "$STATFILEOLD"
    fi    
  else
    if [ $VERBOSE -eq 1 ]
      then
        echo -e "Not deleting temp-files."
    fi
fi

echo -e "Finished."
exit 0