#!/bin/bash
#################################################################################################################
#
# by Christoph Wempe
# 2016-08-21
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
DATETIME=$(date '+%F %R')
# Event
EVENT="G"

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
echo "####################### $DATETIME #######################"


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
        OLDESTYEAR=`expr $YEAR - 3`
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
        echo "                 Primetime (E)mmy Awards"
        echo "                 (G)olden Globes Awards"
        echo "                 (I)ndependent Spirit Awards"
        echo "                 (R)azzie Awards"
        echo "                 (SAG) Screen Actors Guild Awards"
        echo "                 (SUN) Sundance Film Festival"
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
  e|E )
    EVENT="Emmy Awards"
    EVENTSTRING="emmy"
    EVENTID="ev0000223"
    if [ "$TV" != "no" ]
    then
      TV="yes"
    fi
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
  r|R )
    EVENT="Razzie Awards"
    EVENTSTRING="razzies"
    EVENTID="ev0000558"
    TV="no"
    ;;
  sag|SAG )
    EVENT="SAG Awards"
    EVENTSTRING="sag"
    EVENTID="ev0000598"
    TV="yes"
    ;;
  sun|SUN )
    EVENT="Sundance Film Festival"
    EVENTSTRING="sundance"
    EVENTID="ev0000631"
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

# change dir to $BINDIR for git to work
cd $BINDIR

# Git commit
GITCOMMIT=$(git log --date=format:'%F %R' --pretty=format:'%cd (Commit: %h)' -n 1)
#' fix wrong syntax highlighting in mcedit


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
    echo -e " OLDESTYEAR:     $OLDESTYEAR"
    echo -e " EVENTID:        $EVENTID"
    echo -e " EVENTSTRING:    $EVENTSTRING"
    echo -e " EVENT:          $EVENT"
    echo -e " GITCOMMIT:      $GITCOMMIT"
    echo -e ""
    echo -e "Files:"
    echo -e " BINDIR:         $BINDIR"
    echo -e " CONFIG:         $CONFIG"
    echo -e " DBFILE:         $DBFILE"
    echo -e " NOMINEEURL:     $NOMINEEURL"
    echo -e " NOMINEEHTML:    $NOMINEEHTML"
    echo -e " NOMINEEJSON:    $NOMINEEJSON"
    echo -e " IDSFILE:        $IDSFILE"
    echo -e " PLAYLISTFILE:   $PLAYLISTFILE"
    echo -e " PLAYLISTFILETV: $PLAYLISTFILETV"
    echo -e " XRELFILE:       $XRELFILE"
    echo -e " JSSOURCE:       $JSSOURCE"
    echo -e " JSDEST:         $JSDEST"
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

# check if $NOMINEEJSON exists (and is not empty)
if [ ! -s $NOMINEEJSON -o "$FORCE" -eq 1 ]
  then
    # $NOMINEEJSON does not exist or is empty or force-mode is enabled

    # check if $NOMINEEHTML does not exist or force-mode is enabled
    if [ ! -s $NOMINEEHTML -o "$FORCE" -eq 1 ]
      then
        # Downloading list of nominees from imdb.com
        echo -e "Downloading list of nominees from imdb.com ..."
        wget $NOMINEEURL -O $NOMINEEHTML -q
      else
        echo -e "Using existing \$NOMINEEHTML."
    fi

    # Get JSON from HTML-file
    cat $NOMINEEHTML \
      | grep "IMDbReactWidgets.NomineesWidget.push" \
      | sed "s/IMDbReactWidgets.NomineesWidget.push(.'center-3-react',//" \
      | sed "s/.);$//" \
      | jq . \
      > $NOMINEEJSON

  else
    # $NOMINEEJSON is present and not empty
    if [ "$VERBOSE" -eq 1 ]
      then
        echo -e "Use existing JSON-File."
    fi
fi



# check if $IDSFILE exists (and is not empty)
if [ ! -s $IDSFILE -o "$FORCE" -eq 1 ]
  then
    # $IDSFILE does not exist or is empty or force-mode is enabled

    if [ ! -s $NOMINEEJSON ]
      then
        echo -e "JSON-file does not exist or is empty!"
        exit 1
    fi

    # Get IMDB-IDs from nominee-list

    cat $NOMINEEJSON \
      | jq '.nomineesWidgetModel.eventEditionSummary.awards[].categories[].nominations[] | if (.primaryNominees[].const | startswith("tt") ) then .primaryNominees[] | [.const, .name] else .secondaryNominees[] | [.const, .name] end | @tsv' \
      | awk '{print "echo  "$0}' | sh \
      | sort \
      | uniq -c\
      | sort -nr \
      > $IDSFILE

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
    echo -e "  <match>all</match>"                                                     >> "$PLAYLISTFILE"
    echo -e "  <rule field=\"title\" operator=\"is\">"                                 >> "$PLAYLISTFILE"

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
        echo -e "  <match>all</match>"                                                     >> "$PLAYLISTFILETV"
        echo -e "  <rule field=\"title\" operator=\"is\">"                                 >> "$PLAYLISTFILETV"
    fi

    ####
    # Create header for HTML-file
    ####
    if [ "$XREL" -eq 1 ]
    then
      # 
      echo -e "<!DOCTYPE html>"                                                           >  $XRELFILE
      echo -e "<html lang=\"en\">"                                                        >> $XRELFILE
      echo -e "  <head>"                                                                  >> $XRELFILE
      echo -e "    <meta charset=\"utf-8\"/>"                                             >> $XRELFILE
      echo -e "    <title>$EVENT $YEAR</title>"                                           >> $XRELFILE
      echo -e "    <link rel=\"shortcut icon\" type=\"image/x-icon\" href=\"http://www.oscars.org/favicon.ico\" />"       >> $XRELFILE
      echo -e "    <link rel=\"stylesheet\" type=\"text/css\" href=\"$CSSFILE\" />"       >> $XRELFILE
      echo -e "    <link rel=\"stylesheet\" href=\"https://use.fontawesome.com/releases/v5.7.2/css/all.css\" integrity=\"sha384-fnmOCqbTlWIlj8LyTjo7mOUStjsKC4pOpQbqyi7RrhN7udi9RwhKkMHpvLbHG9Sr\" crossorigin=\"anonymous\" />"  >> $XRELFILE
      echo -e "    <script src=\"sorttable.js\"></script>"                                >> $XRELFILE
      echo -e "  </head>"                                                                 >> $XRELFILE
      echo -e "  <body>"                                                                  >> $XRELFILE
      echo -e "    <h1>$PLAYLISTNAME</h1>"                                                >> $XRELFILE
      echo -e "    <h2>Movies</h2>"                                                       >> $XRELFILE
      echo -e "    <p><a target=\"_blank\" href=\"$NOMINEEURL\">IMDB's Awards Central</a></p>"  >> $XRELFILE
      echo -e "    <table class=\"sortable nominations\">"                                      >> $XRELFILE
      echo -e "      <thead>"                                                                   >> $XRELFILE
      echo -e "        <tr>"                                                                    >> $XRELFILE
      echo -e "          <th title=\"Number\" class=\"sorttable_nosort\">#</th>"                                     >> $XRELFILE
      echo -e "          <th title=\"in Database\"><i class=\"fas fa-hdd fa-xs\"></i></th>"                          >> $XRELFILE
      echo -e "          <th title=\"watched\"><i class=\"fas fa-eye fa-xs\"></i></th>"                              >> $XRELFILE
      echo -e "          <th title=\"Links\" class=\"sorttable_nosort\"><i class=\"fas fa-search fa-xs\"></i></th>"  >> $XRELFILE
      echo -e "          <th title=\"amount of nominations\"><i class=\"fas fa-trophy fa-xs\"></i></th>"             >> $XRELFILE
      echo -e "          <th title=\"media type\"><i class=\"fas fa-tags fa-xs\"></i></th>"                          >> $XRELFILE
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

      # copy sorttable.js file is necessary
      if [ ! -f "$JSDEST" ]
        then
            if [ $VERBOSE -eq 1 ]
              then
                echo -e "sorttable.js file does not exist yet. Downloading..."
                echo "wget \"$JSSOURCE\" -o \"$JSDEST\""
            fi
            wget "$JSSOURCE" -O "$JSDEST"
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
      TITLESEARCH=`echo "$TITLE" | sed -r "s/(\ |,|')/%20/g"`
      TITLESEARCHG=`echo "$TITLE" | sed -r "s/(\ |,|')/+/g"`


      if [ $VERBOSE -eq 1 ]
        then
          echo ""
          echo "$TITLE:"
      fi


      if [ "$EVENTSTRING" = "golden-globes" -o "$EVENTSTRING" = "oscars" -o "$EVENTSTRING" = "bafta" -o "$EVENTSTRING" = "independant" -o "$EVENTSTRING" = "sag" ]
      then
        RELEASEYEAR=`expr $YEAR - 1`
      else
        RELEASEYEAR="$YEAR"
      fi

      # get categories for nominations
      readarray CATEGORIES < <(cat "$NOMINEEJSON" \
                    | jq --arg ID $ID ".nomineesWidgetModel.eventEditionSummary.awards[].categories[].nominations[]
                                         | objects | select((.primaryNominees[]? | .const == \"$ID\") or (.secondaryNominees[]? | .const == \"$ID\")) 
                                         | .categoryName | @sh" )

      if [ $VERBOSE -eq 1 ]
        then
          echo "CATEGORIES: "${CATEGORIES[@]}
      fi

      # Search title in Database using IMDBid
      SQLRESULT=`sqlite3 -init <(echo .timeout $DBTIMEOUT) $DBFILE "SELECT c00, playCount, '"$NOMINATIONS"' as nominations FROM movie_view WHERE uniqueid_value IS '"$ID"' AND (uniqueid_type IS 'imdb' OR uniqueid_type IS 'unknown') GROUP BY c00 LIMIT 1"`
      if [ $VERBOSE -eq 1 ]
        then
          echo -e "  SQL movie: sqlite3 -init <(echo .timeout $DBTIMEOUT) $DBFILE \\ \n                \"SELECT c00, playCount, '\"$NOMINATIONS\"' as nominations FROM movie_view WHERE uniqueid_value IS '\"$ID\"' AND (uniqueid_type IS 'imdb' OR uniqueid_type IS 'unknown') GROUP BY c00 LIMIT 1\""
      fi
      # replace certain characters in title to match sql syntax
      TITLESQL=`echo $TITLE | sed "s/\(&\|'\|:\)/%/g"`

          # check if the nominee is a series
          ISSERIES=$(echo ${CATEGORIES[@]} | grep -c "Series" )
          ISSHORT=$(echo ${CATEGORIES[@]}  | grep -c "Short" )
          ISDOCU=$(echo ${CATEGORIES[@]}   | grep -c "Documentary" )
          ISANIME=$(echo ${CATEGORIES[@]}  | grep -c "Animated" )

          if [ $VERBOSE -eq 1 ]
            then
              echo "  ISSERIES: $ISSERIES"
              echo "  ISSHORT:  $ISSHORT"
              echo "  ISDOCU:   $ISDOCU"
              echo "  ISANIME:  $ISANIME"
              echo "  TITLESQL: $TITLESQL"
          fi

      if [ "$SQLRESULT" != "" ]
      then
        PLAYCOUNT=`echo "$SQLRESULT" | awk -F \| '{print $2}'`
        TITLE=`echo "$SQLRESULT" | awk -F \| '{print $1}'`
        TITLESQL=`echo $TITLE | sed "s/\(&\|'\|:\)/%/g"`
        INDATABASE="yes"
        ISSERIES=0
        #ISSHORT=0

        # increment MOVIECOUNT
        MOVIECOUNT=$((MOVIECOUNT+1))


        if [ "$PLAYCOUNT" = "" ]
        then
          PLAYCOUNT=0
        else
          # increment WATCHEDCOUNT
          WATCHEDCOUNT=$((WATCHEDCOUNT+1))
        fi

        # Write in playlist
        echo -e "    <value>$TITLESQL</value>" \
          >> "$PLAYLISTFILE"

      else

          # Search series in Database using Title
          SQLRESULT2=`sqlite3 -init <(echo .timeout $DBTIMEOUT) $DBFILE "SELECT c00, totalCount, watchedCount, '"$NOMINATIONS"' as nominations FROM tvshow_view WHERE c00 IS '$TITLESQL' GROUP BY c00 LIMIT 1"`
          if [ $VERBOSE -eq 1 ]
            then
              echo -e "  SQL series: sqlite3 -init <(echo .timeout $DBTIMEOUT) $DBFILE \\ \n                \"SELECT c00, totalCount, watchedCount, '\"$NOMINATIONS\"' as nominations FROM tvshow_view WHERE c00 IS '\"$TITLESQL\"' GROUP BY c00 LIMIT 1\""
          fi

          if [ "$SQLRESULT2" != "" ]
          then
            TOTALCOUNT=`echo "$SQLRESULT2" | awk -F \| '{print $2}'`
            PLAYCOUNT=`echo "$SQLRESULT2" | awk -F \| '{print $3}'`
            INDATABASE="yes"
            # replace certain characters in title to match sql syntax

            # increment MOVIECOUNT
            MOVIECOUNT=$((MOVIECOUNT+1))

            if [ $VERBOSE -eq 1 ]
              then
                echo -e "  TOTALCOUNT: $TOTALCOUNT"
            fi


            if [ "$PLAYCOUNT" = "" ]
            then
              PLAYCOUNT=0
            else
              # increment WATCHEDCOUNT
              WATCHEDCOUNT=$((WATCHEDCOUNT+1))
            fi


          else
            PLAYCOUNT=0
            INDATABASE="no"
            if [ "$TV" = "yes" ]
              then
                 # write in tv playlist
                 echo -e "    <value>$TITLESQL</value>" \
                  >> "$PLAYLISTFILETV"
            fi

          fi

      fi

      if [ $VERBOSE -eq 1 ]
        then
          echo -e "  PLAYCOUNT: $PLAYCOUNT"
      fi


      # check it is a th show
      if [ $PLAYCOUNT -eq 0 ]
      then 
        WATCHED="no"
        if [ $ISSERIES -gt 0 ]
        then
          WATCHEDNOTE="not watched ($PLAYCOUNT/$TOTALCOUNT)"
        else
          WATCHEDNOTE="not watched"
        fi
      else
        if [ $ISSERIES -gt 0 ]
        then
          # have all episodes been watched
          if [ $PLAYCOUNT -eq $TOTALCOUNT ]
          then
            WATCHED="yes"
            WATCHEDNOTE="watched ($PLAYCOUNT/$TOTALCOUNT)"
          else
            WATCHED="partly"
            WATCHEDNOTE="watched ($PLAYCOUNT/$TOTALCOUNT)"
          fi
        else
          # it is a movie
          WATCHED="yes"
          WATCHEDNOTE="watched"
        fi
      fi

      ####
      # Create HTML-file with links to xRel.to
      ####
      if [ "$XREL" -eq 1 ]
      then

        echo -e  "        <tr>"                                                                                         >> $XRELFILE
        echo -e  "          <td title=\"number\"        class=\"number\"></td>"                                         >> $XRELFILE
        echo -en "          <td title=\"in Database?\"  class=\"db $INDATABASE\" "                                      >> $XRELFILE
        if [ "$INDATABASE" = "yes" ]
        then
          # check mark
          echo -en "sorttable_customkey=\"1\"><i class=\"fas fa-check fa-sm\"></i>"         >> $XRELFILE
        else
          # X
          echo -en "sorttable_customkey=\"2\"><i class=\"fas fa-times fa-sm\"></i>"         >> $XRELFILE
        fi
        echo -e         " </td>"                                                                                       >> $XRELFILE
        echo -en "          <td title=\"$WATCHEDNOTE\" class=\"watched $WATCHED\" "         >> $XRELFILE
        case "$WATCHED" in
          yes)
            # check mark
            echo -en "sorttable_customkey=\"1\"><i class=\"fas fa-check fa-sm\"></i>"       >> $XRELFILE
            ;;
          partly)
            # O
            echo -en "sorttable_customkey=\"2\"><i class=\"fas fa-chart-pie fa-sm\"></i>"   >> $XRELFILE
            ;;
          *)
            # X
            echo -en "sorttable_customkey=\"3\"><i class=\"fas fa-times fa-sm\"></i>"       >> $XRELFILE
        esac

        echo -e          "</td>"                                                                                                          >> $XRELFILE

        echo -e  "          <td title=\"Links\" class=\"links\">"                                                                         >> $XRELFILE

        echo -e  "             <a target=\"_blank\" href=\"https://www.imdb.com/title/$ID/\">"                                             >> $XRELFILE
        echo -e  "               <img src=\"https://www.imdb.com/favicon.ico\" alt=\"The Movie DB\" height=16/></a>"                       >> $XRELFILE

        echo -e  "             <a target=\"_blank\" href=\"https://www.themoviedb.org/search?query=$TITLESEARCH\">"                       >> $XRELFILE
        echo -e  "               <img src=\"https://www.themoviedb.org/favicon.ico\" alt=\"The Movie DB\" height=16/></a>"                >> $XRELFILE

        echo -e  "             <a target=\"_blank\" href=\"https://www.xrel.to/search.html?xrel_search_query=$ID\">"                      >> $XRELFILE
        echo -e  "               <img src=\"https://www.xrel.to/favicon.ico\" alt=\"xREL\"/></a>     "                                     >> $XRELFILE

        echo -e  "             <a target=\"_blank\" href=\"https://thepiratebay.org/search/$TITLESEARCH%20$RELEASEYEAR/0/99/200\">"       >> $XRELFILE
        echo -e  "               <img src=\"https://thepiratebay.org/favicon.ico\" alt=\"The Pirate Bay\"/></a>"                          >> $XRELFILE

        echo -e  "             <a target=\"_blank\" href=\"https://rarbg.to/torrents.php?search=$TITLESEARCH%20$RELEASEYEAR&order=seeders&by=DESC\">" >> $XRELFILE
        echo -e  "               <img src=\"https://rarbg.to/favicon.ico\" alt=\"RARBG\"/></a>"                                           >> $XRELFILE

        echo -e  "             <a target=\"_blank\" href=\"https://www.limetorrents.zone/search/all/${TITLESEARCH}-${RELEASEYEAR}/seeds/1/\">"    >> $XRELFILE
        echo -e  "               <img src=\"https://www.limetorrents.zone/favicon.ico\" alt=\"LimeTorrents\"/></a>"                       >> $XRELFILE

        echo -e  "             <a target=\"_blank\" href=\"http://extratorrent.host/search/?search=${TITLESEARCH}%20${RELEASEYEAR}&srt=seeds&order=desc\">"    >> $XRELFILE
        echo -e  "               <img src=\"https://extratorrent.host/images/favicon.ico\" alt=\"Extratorrent\"/></a>"                       >> $XRELFILE

        echo -e  "             <a target=\"_blank\" href=\"https://www.google.de/search?safe=off&site=webhp&source=hp&q=$TITLESEARCHG\">" >> $XRELFILE
        echo -e  "               <img src=\"https://www.google.com/favicon.ico\" alt=\"Google\" height=16/></a>"                          >> $XRELFILE

        echo -e  "             </td>"                                                                                                     >> $XRELFILE
        echo -e  "          <td title=\"nominated in:"                                                                                    >> $XRELFILE

        for cat in "${CATEGORIES[@]}"
        do
          echo "      "$cat | sed 's/"//g'                                                                                                >> $XRELFILE
        done

        echo -e  " \"class=\"nomcount\">$NOMINATIONS</td>"                                                                             >> $XRELFILE
        echo -e  "          <td title=\"media type\" class=\"media_type\" "                                                               >> $XRELFILE

        if [ $VERBOSE -eq 1 ]
          then
            echo -e "  EVENTSTRING: $EVENTSTRING"
            echo -e "  ISSERIES:    $ISSERIES"
            echo -e "  ISSHORT:     $ISSHORT"
            echo -e "  ISDOCU:      $ISDOCU"
            echo -e "  ISANIME:     $ISANIME"
        fi


        if [ $ISSHORT -gt 0 ]
        then
          # tv icon
          MOVIELENGHT="Short"
        else
          # film icon
          MOVIELENGHT="Movie"
        fi

        if [ $ISDOCU -gt 0 ]
        then
          # video icon
          echo -en " sorttable_customkey=\"${MOVIELENGHT}_4\"><i title=\"Documentary ${MOVIELENGHT}\" class=\"${MOVIELENGHT} fas fa-video fa-sm\"></i>"   >> $XRELFILE
        else
          if [ $ISANIME -gt 0 ]
          then
            # paint-brush icon
            echo -en " sorttable_customkey=\"${MOVIELENGHT}_2\"><i title=\"Animated ${MOVIELENGHT}\" class=\"${MOVIELENGHT} fas fa-paint-brush fa-sm\"></i>"   >> $XRELFILE
          else
            if [ $ISSERIES -gt 0 ]
            then
              # tv icon
              echo -en " sorttable_customkey=\"${MOVIELENGHT}_3\"><i title=\"Limited Series or movie made for TV\" class=\"${MOVIELENGHT} fas fa-tv fa-sm\"></i>"   >> $XRELFILE
            else
              # film icon
              echo -en " sorttable_customkey=\"${MOVIELENGHT}_1\"><i title=\"${MOVIELENGHT}\" class=\"${MOVIELENGHT} fas fa-film\"></i>"   >> $XRELFILE
            fi
          fi
        fi

        echo -en            "</a></td>"   >> $XRELFILE
        echo -en "          <td title=\"Movietitle\" class=\"title\">"                                                                    >> $XRELFILE
        echo -e              "<a target=\"_blank\" href=\"http://www.imdb.com/title/$ID/\">$TITLE</a></td>"                               >> $XRELFILE
        echo -e "        </tr>"                                                                                                           >> $XRELFILE

      fi

    done < "$IDSFILE"


    ####
    # Printing footer to playlist
    ####

    if [ $VERBOSE -eq 1 ]
      then
        echo -e "Printing footers ..."
    fi
    echo -e "  </rule>"                                                            >> "$PLAYLISTFILE"
    echo -e "  <rule field=\"year\" operator=\"greaterthan\">$OLDESTYEAR</rule>"   >> "$PLAYLISTFILE"
    echo -e "</smartplaylist>"                                                     >> "$PLAYLISTFILE"
    
    if [ "$TV" = "yes" ]
      then
        echo -e "  </rule>"                                      >> "$PLAYLISTFILETV"
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
      echo -e  "      </tbody>"                                                              >> $XRELFILE
      echo -e  "      <tfoot>"                                                               >> $XRELFILE
      echo -e  "        <tr>"                                                                >> $XRELFILE
      echo -en "          <tr><td>$NOMINEESCOUNT</td><td>$MOVIECOUNT</td><td>$WATCHEDCOUNT"  >> $XRELFILE
      echo -en           "</td><td></td><td></td><td></td><td></td></tr>"                    >> $XRELFILE
      echo -e  "        </tr>"                                                               >> $XRELFILE
      echo -e  "      </tfoot>"                                                              >> $XRELFILE
      echo -e  "    </table>"                                               >> $XRELFILE

      echo -e  "    <br>"                                                   >> $XRELFILE
      echo -e  "    <table class=\"meta\">"                                 >> $XRELFILE
      echo -e  "      <tr><td><i class=\"fas fa-sync-alt\"></td>"           >> $XRELFILE
      echo -e  "          <td></i>$DATETIME</td></tr>"                      >> $XRELFILE
      echo -e  "      <tr><td><i class=\"fas fa-code-branch\"></i></td>"    >> $XRELFILE
      echo -e  "          <td>${GITCOMMIT}</td></tr>"                       >> $XRELFILE
      echo -e  "     <table>"                                               >> $XRELFILE
      echo -e  "  </body>"                                                  >> $XRELFILE
      echo -e  "</html>"                                                    >> $XRELFILE
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
            echo -e "Stats did not change. Not sending mail."
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