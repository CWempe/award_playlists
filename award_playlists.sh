#!/bin/bash
#################################################################################################################
#
# by Christoph Wempe
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
YEAR=$(date +%Y)
DATETIME=$(date '+%F %R')
# Event
EVENT="G"

# VERBOSE (0/1)
VERBOSE="0"
# Debug (0/1)
DEBUG="0"
# Force sending Mail(0/1)
FORCESEND="0"
# Force (0/1)
FORCE="0"
# FORCEICONS (0/1)
FORCEICONS="0"
# TV shows (0/1)
TV="0"
# Mail address
MAIL=""
# Statistics (0/1)
STATS="1"
# xRel (0/1)
XREL="0"

# define arrays
declare -A WEBSITENAME
declare -A WEBSITEFAVICONURL
declare -A WEBSITESEARCHURL


echo ""
echo "####################### $DATETIME #######################"

while getopts vcdfie:m:y:t:sx opt
  do
    case $opt in
      v)      # Verbose
        VERBOSE="1"
        ;;
      c)      # force
        FORCESEND="1"
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
      i)
        FORCEICONS="1"
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
        OLDESTYEAR=$((YEAR - 4))
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
        if [ "$OPTARG" = "yes" ] || [ "$OPTARG" = "no" ]
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
        echo "usage: $0 [-v] [-c] [-d] [-f] [-i] [-e E] [-y YYYY] [-m address] [-t yes|no] [-s] [-x]"
        echo "example: $0 -vdf -e G -y 2013"
        echo "          [-v] Verbose-Mode: Print more output"
        echo "          [-d] Debug-Mode: No Files removed"
        echo "          [-c] Force-Mode: Send mail even nothing changed"
        echo "          [-f] Force-Mode: Download new Nominee-List; Overwrite existing ID-File"
        echo "          [-i] Force-Mode: Download new favicons"
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
  ca|CA )
    EVENT="Cannes Film Festival"
    EVENTSTRING="cannes"
    EVENTID="ev0000147"
    TV="no"
    ;;
  c|C|cri|CRI )
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
    EVENT="Independent Spirit Awards"
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

# Define Functions
trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

# Function to download favicon
download_favicon() {
  local sitename=$1

  if [ "${sitename}" == "awards" ]
    then
      # This is for the faviocon of this script and not for a search site
      local filename="awards.ico"
      local url="https://www.oscarsdeathrace.com/favicon.ico"
      # The original favicon gets Error 403 when trying to download via wget
      #WEBSITEFAVICONURL[awards]="http://www.oscars.org/favicon.ico"
    else
      local filename="${sitename}.ico"
      local url=${WEBSITEFAVICONURL[$sitename]}
  fi

  # check if file exists
  if [[ ! -f "${FAVICONPATH}/${filename}" || "${FORCEICONS}" == "1" ]]
    then
      if [ "$VERBOSE" -eq 1 ]
        then
          echo -e "Downloading favicon from ${url} to ${FAVICONPATH}/${filename} ..."
      fi
      wget -U "${WEBSITEUSERAGENT}" "${url}" -O "${FAVICONPATH}/${filename}" -q
      chown "$WWWUSER":"$WWWGROUP" "${FAVICONPATH}/${filename}"
    else
      if [ "$VERBOSE" -eq 1 ]
        then
          echo -e "Favicon: ${FAVICONPATH}/${filename} already exists."
      fi
  fi

}

echo "### $EVENT $YEAR"

# Define files and directories
BINDIR="$( cd "$(dirname "$0")" || { echo "Command cd failed!"; exit 1; } ; pwd -P )"
# " to correct syntax highlighting in mcedit
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
# shellcheck disable=SC1091,SC1090
source "$CONFIG"

INDEXHTML="${HTMLDIR}/index.html"

# change dir to $BINDIR for git to work
cd "$BINDIR" || { echo "Command cd failed!"; exit 1; }

# Get last git commit hash
GITCOMMIT=$(${GITBIN} log --date=format:'%F %R' --pretty=format:'%cd (Commit: %h)' -n 1)
#' fix wrong syntax highlighting in mcedit


if [ "$YEAR" = "2017" ] && [ "$EVENTSTRING" = "critics" ]
  then
    # The Critict Choice Awards 2017 show was moved forward to Dec 2016
    NOMINEEURL="http://www.imdb.com/event/$EVENTID/2016/2"
fi

if [ "$VERBOSE" -eq 1 ]
  then
    echo -e ""
    echo -e "Variables:"
    echo -e " DEBUG:          $DEBUG"
    echo -e " VERBOSE:        $VERBOSE"
    echo -e " FORCE:          $FORCE"
    echo -e " FORCEICONS:     $FORCEICONS"
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
    echo -e " HTMLDIRL:       $HTMLDIR"
    echo -e " INDEXHTML:      $INDEXHTML"
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

if [ ! -d "$DATDIR" ]
  then
    echo -e "\$DATDIR does not exist. Creating it now ..."
    mkdir "$DATDIR"
fi

if [ ! -d "$TMPDIR" ]
  then
    echo -e "\$TMPDIR does not exist. Creating it now ..."
    mkdir "$TMPDIR"
fi

if [ ! -s "$DBFILE" ]
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
    chown "$USER":"$GROUP" "$PLVEVENTDIR"
fi

if [ ! -d "$FAVICONPATH" ]
  then
    if [ "$VERBOSE" -eq 1 ]
      then
        echo -e "Favicon-Directory does not exist yet.\nWill create folder now."
    fi
    mkdir "$FAVICONPATH"
    chown "$WWWUSER":"$WWWGROUP" "$FAVICONPATH"
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
if [ ! -s "$NOMINEEJSON" ] || [ "$FORCE" -eq 1 ]
  then
    # $NOMINEEJSON does not exist or is empty or force-mode is enabled

    # check if $NOMINEEHTML does not exist or force-mode is enabled
    if [ ! -s "$NOMINEEHTML" ] || [ "$FORCE" -eq 1 ]
      then
        # Downloading list of nominees from imdb.com
        echo -e "Downloading list of nominees from imdb.com ..."
        wget "$NOMINEEURL" -O "$NOMINEEHTML" -q
      else
        echo -e "Using existing \$NOMINEEHTML."
    fi

    # Get JSON from HTML-file
    grep "IMDbReactWidgets.NomineesWidget.push" "$NOMINEEHTML" \
      | sed "s/IMDbReactWidgets.NomineesWidget.push(.'center-3-react',//" \
      | sed "s/.);$//" \
      | jq . \
      > "$NOMINEEJSON"

  else
    # $NOMINEEJSON is present and not empty
    if [ "$VERBOSE" -eq 1 ]
      then
        echo -e "Use existing JSON-File."
    fi
fi

# check if $IDSFILE exists (and is not empty)
if [ ! -s "$IDSFILE" ] || [ "$FORCE" -eq 1 ]
  then
    # $IDSFILE does not exist or is empty or force-mode is enabled

    if [ ! -s "$NOMINEEJSON" ]
      then
        echo -e "JSON-file does not exist or is empty!"
        exit 1
    fi

    # Get IMDB-IDs from nominee-list
    < "$NOMINEEJSON" \
        jq '.nomineesWidgetModel.eventEditionSummary.awards[].categories[].nominations[] | if (.primaryNominees[].const | startswith("tt") ) then .primaryNominees[] | [.const, .name] else .secondaryNominees[] | [.const, .name] end | @tsv' \
      | awk '{print "echo  "$0}' | sh \
      | sed 's/\\t/\t/g' \
      | sort \
      | uniq -c \
      | sort -nr \
      > "${IDSFILE}"

  else
    # $IDSFILE is present and not empty
    if [ "$VERBOSE" -eq 1 ]
      then
        echo -e "Use existing IDS-File."
    fi
fi


####
# download favicons to improve side loading
####

if [ "$VERBOSE" -eq 1 ]
  then
    echo -e ""
    echo -e "Defined websites: ${!WEBSITEFAVICONURL[@]}"
    for website in "${!WEBSITEFAVICONURL[@]}"; do
      echo -e "  ${WEBSITENAME[$website]}:"
      echo -e "    WEBSITEFAVICONURL: ${WEBSITEFAVICONURL[$website]}"
      echo -e "    WEBSITESEARCHURL:  ${WEBSITESEARCHURL[$website]}"
    done
    echo -e ""
fi


if [ "$VERBOSE" -eq 1 ]
  then
    echo -e ""
fi

# Download main favicon
download_favicon "awards"

# download favicon for all defined websites
for website in "${!WEBSITEFAVICONURL[@]}"; do
    download_favicon "${website}"
done

if [ "$VERBOSE" -eq 1 ]
  then
    echo -e ""
fi

####
# Generate Playlist
####

# Count nominees
NOMINEESCOUNT=$(wc -l "$IDSFILE" | awk '{print $1}')
MOVIECOUNT=0
WATCHEDCOUNT=0
NOMCOUNT=0
WATCHEDNOMCOUNT=0

if [ "$NOMINEESCOUNT" -eq 0 ]
  then
    STATTEXT="No nominees!"
  else

    ####
    # Printing header to playlist
    ####
    echo -e "Printing header to playlist ..."
    {
      echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>"
      echo -e "<!-- This Smartplaylist was created by \"$0\" at $(date +%F\ %T) -->"
      echo -e "<smartplaylist type=\"movies\">"
      echo -e "  <name>$PLAYLISTNAME</name>"
      echo -e "  <match>all</match>"
      echo -e "  <rule field=\"title\" operator=\"is\">"
    } > "$PLAYLISTFILE"

    if [ "$TV" = "yes" ]
      then
        ####
        # Printing header to playlist for tv shows
        ####
        echo -e "Printing header to playlist for tv shows..."
        {
          echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>"
          echo -e "<!-- This Smartplaylist was created by \"$0\" at $(date +%F\ %T) -->"
          echo -e "<smartplaylist type=\"tvshows\">"
          echo -e "  <name>$PLAYLISTNAMETV</name>"
          echo -e "  <match>all</match>"
          echo -e "  <rule field=\"title\" operator=\"is\">"
        }  >  "$PLAYLISTFILETV"
    fi

    ####
    # Create header for HTML-file
    ####
    if [ "$XREL" -eq 1 ]
    then
      {
        echo -e "<!DOCTYPE html>"
        echo -e "<html lang=\"en\">"
        echo -e "  <head>"
        echo -e "    <meta charset=\"utf-8\"/>"
        if [[ "${CSSFILE}" == "awards_dark.css" ]]
          then
            echo -e "    <meta name=\"theme-color\" content=\"#212121\">"
        fi
        echo -e "    <meta name=\"viewport\" content=\"width=device-width\">"
        echo -e "    <title>$EVENT $YEAR</title>"
        echo -e "    <link rel=\"shortcut icon\" type=\"image/x-icon\" href=\"${FAVICONDIR}/awards.ico\" />"
        echo -e "    <link rel=\"stylesheet\" type=\"text/css\" href=\"$CSSFILE\" />"
        echo -e "    <link rel=\"stylesheet\" href=\"https://use.fontawesome.com/releases/v5.7.2/css/all.css\" integrity=\"sha384-fnmOCqbTlWIlj8LyTjo7mOUStjsKC4pOpQbqyi7RrhN7udi9RwhKkMHpvLbHG9Sr\" crossorigin=\"anonymous\" />"
        echo -e "    <script src=\"sorttable.js\"></script>"
        echo -e "  </head>"
        echo -e "  <body>"
        echo -e "    <h1>$PLAYLISTNAME</h1>"
        echo -e "    <h2>Movies</h2>"
        echo -e "    <p><a target=\"_blank\" href=\"$NOMINEEURL\">IMDB's Awards Central</a></p>"
        echo -e "    <table class=\"sortable nominations\">"
        echo -e "      <thead>"
        echo -e "        <tr>"
        echo -e "          <th title=\"Number\" class=\"sorttable_nosort\">#</th>"
        echo -e "          <th title=\"in Database\"><i class=\"fas fa-hdd fa-xs\"></i></th>"
        echo -e "          <th title=\"watched\"><i class=\"fas fa-eye fa-xs\"></i></th>"
        echo -e "          <th title=\"Links\" class=\"sorttable_nosort\"><i class=\"fas fa-search fa-xs\"></i></th>"
        echo -e "          <th title=\"amount of nominations\"><i class=\"fas fa-trophy fa-xs\"></i></th>"
        echo -e "          <th title=\"most important nomination\"><i class=\"fas fa-star fa-xs\"></i></th>"
        echo -e "          <th title=\"media type\"><i class=\"fas fa-tags fa-xs\"></i></th>"
        echo -e "          <th title=\"Movietitle\">Title</th>"
        echo -e "        </tr>"
        echo -e "      </thead>"
        echo -e "      <tbody>"
      } >  "$XRELFILE"

      # copy css file is necessary
      if [ ! -f "$CSSSOURCE" ]
        then
            if [ "$VERBOSE" -eq 1 ]
              then
                echo -e "css file does not exist!"
            fi
            exit 1
        else
            if [ "$VERBOSE" -eq 1 ]
              then
                echo -e "Copy css file to html directory."
            fi
            cp "$CSSSOURCE" "$CSSDEST"
      fi

      # copy sorttable.js file is necessary
      if [ ! -f "$JSDEST" ]
        then
            if [ "$VERBOSE" -eq 1 ]
              then
                echo -e "sorttable.js file does not exist yet. Downloading..."
                echo "wget \"$JSSOURCE\" -o \"$JSDEST\""
            fi
            wget "$JSSOURCE" -O "$JSDEST"
            chown "$WWWUSER":"$WWWGROUP" "$JSDEST"
      fi
    fi

    if [ "$VERBOSE" -eq 1 ]
      then
        echo -e "Getting movietitles and printing them to playlist ..."
    fi

    # Read ID and find title
    while read -r LINE
    do
      NOMINATIONS=$(echo "$LINE" | awk '{print $1}')
      ID=$(echo "$LINE" | awk '{print $2}')
      TITLE=$(echo "$LINE" | cut -f 2)
      TITLESEARCH=$(echo "$TITLE" | sed -r "s/(\ |,|')/%20/g")
      TITLESEARCHG=$(echo "$TITLE" | sed -r "s/(\ |,|')/+/g")

      if [ "$VERBOSE" -eq 1 ]
        then
          echo "###################"
          echo "## $TITLE:"
          echo "ID:    $ID"
          echo "LINE:  $LINE"
      fi

      if [ "$EVENTSTRING" = "golden-globes" ] || [ "$EVENTSTRING" = "oscars" ] || [ "$EVENTSTRING" = "bafta" ] || [ "$EVENTSTRING" = "independant" ] || [ "$EVENTSTRING" = "sag" ]
      then
        RELEASEYEAR=$((YEAR - 1))
      else
        RELEASEYEAR="$YEAR"
      fi

      # get categories for nominations
      readarray CATEGORIES < <(< "$NOMINEEJSON" \
                                   jq --arg ID "$ID" ".nomineesWidgetModel.eventEditionSummary.awards[].categories[].nominations[]
                                 | objects | select((.primaryNominees[]? | .const == \"$ID\") or (.secondaryNominees[]? | .const == \"$ID\"))
                                 | .categoryName | @sh" )

      if [ "$VERBOSE" -eq 1 ]
        then
          echo "CATEGORIES: " "${CATEGORIES[@]}"
      fi

      # Search title in Database using IMDBid
      SQLRESULT=$(sqlite3 -init <(echo .timeout "$DBTIMEOUT") -separator ';;;' "$DBFILE" "SELECT c00, playCount, '$NOMINATIONS' as nominations, strFileName FROM movie_view WHERE uniqueid_value IS '$ID' AND (uniqueid_type IS 'imdb' OR uniqueid_type IS 'unknown') GROUP BY c00 LIMIT 1")
      if [ "$VERBOSE" -eq 1 ]
        then
          echo -e "  SQL movie: sqlite3 -init <(echo .timeout -separator ';;;' $DBTIMEOUT) $DBFILE \\ \n                \"SELECT c00, playCount, '\"$NOMINATIONS\"' as nominations, strFileName FROM movie_view WHERE uniqueid_value IS '\"$ID\"' AND (uniqueid_type IS 'imdb' OR uniqueid_type IS 'unknown') GROUP BY c00 LIMIT 1\""
      fi
      # replace certain characters in title to match sql syntax
      # shellcheck disable=SC2001
      TITLESQL=$(echo "$TITLE" | sed "s/\(&\|'\|:\)/%/g")
      # " to correct syntax highlighting in mcedit

          # check categories
          ISSERIES=$(echo "${CATEGORIES[@]}"     | grep -c "Series" )
          ISSHORT=$(echo "${CATEGORIES[@]}"      | grep -c "Short" )
          ISTV=$(echo "${CATEGORIES[@]}"         | grep -c "Television" )
          ISDOCU=$(echo "${CATEGORIES[@]}"       | grep -c "Documentary" )
          ISANIME=$(echo "${CATEGORIES[@]}"      | grep -c "Animated" )
          ISBOXOFFICE=$(echo "${CATEGORIES[@]}"  | grep -c "Box Office Achievement" )
          BESTMOVIE=$(echo "${CATEGORIES[@]}"    | grep -c -e "Best Motion Picture of the Year" \
                                                           -e "Best Motion Picture - Comedy" \
                                                           -e "Best Motion Picture - Musical" \
                                                           -e "Best Motion Picture, Drama" \
                                                           -e "Best Motion Picture, Musical or Comedy" \
                                                           -e "Outstanding Drama Series" \
                                                           -e "Outstanding Comedy Series" \
                                                           -e "Outstanding Limited Series" \
                                                           -e "Outstanding Television Movie" \
                                                           -e "Worst Picture" \
                                                           -e "Best Television" )
          BESTFOREIGN=$(echo "${CATEGORIES[@]}"  | grep -c -e "Foreign" \
                                                           -e "Non-English Language" \
                                                           -e "Best International Feature Film" )
          BESTANIME=$(echo "${CATEGORIES[@]}"    | grep -c "Animated" )
          BESTACTOR=$(echo "${CATEGORIES[@]}"    | grep -c -e "Actress" \
                                                           -e "Actor" \
                                                           -e "Performance" )
          BESTSONG=$(echo "${CATEGORIES[@]}"     | grep -c -e "Song" )
          BESTDIR=$(echo "${CATEGORIES[@]}"      | grep -c -e "Director" -e "Directing" )
          BESTPLAY=$(echo "${CATEGORIES[@]}"     | grep -c -e "Screenplay" -e "Writing" )
          BESTCAM=$(echo "${CATEGORIES[@]}"      | grep -c -e "Cinematography" )
          BESTEDIT=$(echo "${CATEGORIES[@]}"     | grep -v "Sound Editing" | grep -c -e "Editing" )

          # increment NOMCOUNT
          NOMCOUNT=$((NOMCOUNT+NOMINATIONS))

          if [ "$VERBOSE" -eq 1 ]
            then
              echo "  ISSERIES:    $ISSERIES"
              echo "  ISSHORT:     $ISSHORT"
              echo "  ISDOCU:      $ISDOCU"
              echo "  ISANIME:     $ISANIME"
              echo "  ISBOXOFFICE: $ISBOXOFFICE"
              echo "  TITLESQL:    $TITLESQL"
              echo "  NOMCOUNT:    $NOMCOUNT"
          fi

      if [ "$SQLRESULT" != "" ]
      then
        # in movie_view ...

        # increment MOVIECOUNT
        MOVIECOUNT=$((MOVIECOUNT+1))

        PLAYCOUNT=$(echo "$SQLRESULT" | awk -F ";;;" '{print $2}')
        TITLE=$(echo "$SQLRESULT" | awk -F ";;;" '{print $1}')
        FILENAME=$(echo "$SQLRESULT" | awk -F ";;;" '{print $4}')
        # shellcheck disable=SC2001
        TITLESQL=$(echo "$TITLE" | sed "s/\(&\|'\|:\)/%/g")
        # " to correct syntax highlighting in mcedit

        if [[ "${FILENAME}" == *"TRAILERONLY"* ]]
          then
            INDATABASE="no"
          else
            INDATABASE="yes"
        fi
        ISSERIES=0
        #ISSHORT=0


        if [ "$PLAYCOUNT" = "" ]
        then
          PLAYCOUNT=0
        else
          # increment WATCHEDCOUNT
          WATCHEDCOUNT=$((WATCHEDCOUNT+1))
          # increment WATCHEDNOMCOUNT
          WATCHEDNOMCOUNT=$((WATCHEDNOMCOUNT+NOMINATIONS))
        fi

        # Write in playlist
        echo -e "    <value>$TITLESQL</value>" \
          >> "$PLAYLISTFILE"

      else
          FILENAME="not in Database"
          if [ "$TV" == "yes" ]
            then
              # Search in tvshow_view tabel using title if nothing was found in movie_view ans it is a series (tv show)
              SQLRESULT2=$(sqlite3 -init <(echo .timeout "$DBTIMEOUT") -separator ';;;' "$DBFILE" "SELECT c00, totalCount, watchedCount, '$NOMINATIONS' as nominations FROM tvshow_view WHERE c00 IS '$TITLESQL' COLLATE NOCASE GROUP BY c00 LIMIT 1")
              if [ "$VERBOSE" -eq 1 ]
                then
                  echo -e "  SQL series: sqlite3 -init <(echo .timeout $DBTIMEOUT) -separator ';;;' $DBFILE \"SELECT c00, totalCount, watchedCount, '\"$NOMINATIONS\"' as nominations FROM tvshow_view WHERE c00 IS '\"$TITLESQL\"' COLLATE NOCASE GROUP BY c00 LIMIT 1\""
                  echo -e "  SQLRESULT2: $SQLRESULT2"
              fi

              if [ "$SQLRESULT2" != "" ]
              then
                # In tvshow_view ...
                TOTALCOUNT=$(echo "$SQLRESULT2" | awk -F ";;;" '{print $2}')
                PLAYCOUNT=$(echo "$SQLRESULT2" | awk -F ";;;" '{print $3}')
                INDATABASE="yes"
                # replace certain characters in title to match sql syntax

                # increment MOVIECOUNT
                MOVIECOUNT=$((MOVIECOUNT+1))

                if [ "$VERBOSE" -eq 1 ]
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
                # not in tvshow_view ...
                PLAYCOUNT=0
                INDATABASE="no"
              fi


              if [ "$TV" = "yes" ]
                then
                    # write in tv playlist
                    echo -e "    <value>$TITLESQL</value>" \
                    >> "$PLAYLISTFILETV"
              fi
          else
              PLAYCOUNT=0
              INDATABASE="no"
          fi
      fi

      if [ "$VERBOSE" -eq 1 ]
        then
          echo -e "  PLAYCOUNT: $PLAYCOUNT"
          echo -e "  FILENAME:  $FILENAME"
      fi

      # check it is a th show
      if [ "$PLAYCOUNT" -eq 0 ]
      then
        WATCHED="no"
        if [ "$ISSERIES" -gt 0 ]
        then
          WATCHEDNOTE="not watched ($PLAYCOUNT/$TOTALCOUNT)"
        else
          WATCHEDNOTE="not watched"
        fi
      else
        if [ "$ISSERIES" -gt 0 ]
        then
          # have all episodes been watched
          if [ "$PLAYCOUNT" -eq "$TOTALCOUNT" ]
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

      if [ "$ISSHORT" -gt 0 ]
      then
        MOVIELENGHT="Short"
        LENGHTSYMBOL="fas fa-tv fa-xs"
      else
        if [ "$ISTV" -gt 0 ]
        then
          MOVIELENGHT="TV"
          LENGHTSYMBOL="fas fa-tv fa-xs"
        else
          MOVIELENGHT="Movie"
          LENGHTSYMBOL="fas fa-film fa-sm"
        fi
      fi

      ####
      # Create HTML-file with links to xRel.to
      ####
      if [ "$XREL" -eq 1 ]
      then
        {
          echo -e  "        <tr>"
          echo -e  "          <td title=\"number\"        class=\"number\"></td>"
          echo -en "          <td title=\"${FILENAME}\"  class=\"db $INDATABASE\" "
          if [ "$INDATABASE" = "yes" ]
          then
            # check mark
            echo -en "sorttable_customkey=\"1\"><i class=\"fas fa-check fa-sm\"></i>"
          else
            # X
            echo -en "sorttable_customkey=\"2\"><i class=\"fas fa-times fa-sm\"></i>"
          fi
          # shellcheck disable=SC2291
          echo -e         " </td>"
          echo -en "          <td title=\"$WATCHEDNOTE\" class=\"watched $WATCHED\" "
          case "$WATCHED" in
            yes)
              # check mark
              echo -en "sorttable_customkey=\"1\"><i class=\"fas fa-check fa-sm\"></i>"
              ;;
            partly)
              # O
              echo -en "sorttable_customkey=\"2\"><i class=\"fas fa-percent fa-sm\"></i>"
              ;;
            *)
              # X
              echo -en "sorttable_customkey=\"3\"><i class=\"fas fa-times fa-sm\"></i>"
          esac

          # shellcheck disable=SC2291
          echo -e          "</td>"
          echo -e  "          <td class=\"links\">"

          # Create search links with icon for each defined website
          for website in "${!WEBSITENAME[@]}"; do
              echo -e  "             <a target=\"_blank\" title=\"$(eval echo ${WEBSITENAME[$website]})\" href=\"$(eval echo ${WEBSITESEARCHURL[$website]})\">"
              echo -e  "               <img src=\"${FAVICONDIR}/$website.ico\" alt=\"$(eval echo ${WEBSITENAME[$website]})\" height=16/></a>"
          done

          echo -e  "             </td>"
          echo -e  "          <td class=\"nomcount\">${NOMINATIONS}</td>"
          echo -en "<td class=\"nomsymbol\" sorttable_customkey=\""

          if [ "$BESTMOVIE" -gt 0 ]
          then
            echo -e  "01_${MOVIELENGHT}\"><i class=\"fas fa-star fa-xs\""
          elif [ "$BESTACTOR" -gt 0 ]
          then
            echo -e  "02_${MOVIELENGHT}\"><i class=\"fas fa-user fa-sm\""
          elif [ "$BESTDIR" -gt 0 ]
          then
            echo -e  "03_${MOVIELENGHT}\"><i class=\"fas fa-bullhorn fa-sm\""
          elif [ "$BESTPLAY" -gt 0 ]
          then
            echo -e  "04_${MOVIELENGHT}\"><i class=\"fas fa-book fa-sm\""
          elif [ "$BESTSONG" -gt 0 ]
          then
            echo -e  "05_${MOVIELENGHT}\"><i class=\"fas fa-music fa-sm\""
          elif [ "$BESTCAM" -gt 0 ]
          then
            echo -e  "06_${MOVIELENGHT}\"><i class=\"fas fa-video fa-sm\""
          elif [ "$BESTEDIT" -gt 0 ]
          then
            echo -e  "07_${MOVIELENGHT}\"><i class=\"fas fa-cut fa-sm\""
          elif [ "$BESTANIME" -gt 0 ]
          then
            echo -e  "08_${MOVIELENGHT}\"><i class=\"fas fa-paint-brush fa-xs\""
          elif [ "$BESTFOREIGN" -gt 0 ]
          then
            echo -e  "09_${MOVIELENGHT}\"><i class=\"fas fa-closed-captioning fa-sm\""
          elif [ "$ISDOCU" -gt 0 ]
          then
            echo -e  "10_${MOVIELENGHT}\"><i class=\"fas fa-camera fa-sm\""
          elif [ "$ISANIME" -gt 0 ]
          then
            echo -e  "11_${MOVIELENGHT}\"><i class=\"fas fa-paint-brush fa-sm\""
          elif [ "$ISBOXOFFICE" -gt 0 ]
          then
            echo -e  "11_${MOVIELENGHT}\"><i class=\"fas fa-ticket-alt fa-sm\""
          elif [ "$ISSHORT" -gt 0 ]
          then
            echo -e  "10_${MOVIELENGHT}\"><i class=\"fas fa-star fa-sm\""
          else
            echo -e  "99_${MOVIELENGHT}\"><i class=\"fas fa-tools fa-sm\""
          fi

          echo -e  " title=\"nominated in:"
          for cat in "${CATEGORIES[@]}"
          do
            echo "      " "$cat" | sed 's/"//g'
          done
          echo -e  "\"></i></td>"

          echo -e  "          <td title=\"media type\" class=\"media_type\" "

          if [ "$VERBOSE" -eq 1 ]
            then
              echo -e "  EVENTSTRING: $EVENTSTRING"
              echo -e "  ISSERIES:    $ISSERIES"
              echo -e "  ISSHORT:     $ISSHORT"
              echo -e "  ISDOCU:      $ISDOCU"
              echo -e "  ISANIME:     $ISANIME"
          fi

          if [ "$ISDOCU" -gt 0 ]
          then
            # video icon
            echo -en " sorttable_customkey=\"${MOVIELENGHT}_4\"><i title=\"Documentary ${MOVIELENGHT}\" class=\"${LENGHTSYMBOL}\"></i>"
          else
            if [ "$ISANIME" -gt 0 ]
            then
              # paint-brush icon
              echo -en " sorttable_customkey=\"${MOVIELENGHT}_2\"><i title=\"Animated ${MOVIELENGHT}\" class=\"${LENGHTSYMBOL}\"></i>"
            else
              if [ "$ISSERIES" -gt 0 ]
              then
                # tv icon
                echo -en " sorttable_customkey=\"${MOVIELENGHT}_3\"><i title=\"Limited Series or movie made for TV\" class=\"${LENGHTSYMBOL}\"></i>"
              else
                # film icon
                echo -en " sorttable_customkey=\"${MOVIELENGHT}_1\"><i title=\"${MOVIELENGHT}\" class=\"${LENGHTSYMBOL}\"></i>"
              fi
            fi
          fi

          # shellcheck disable=SC2291
          echo -en            "</a></td>"   >> "$XRELFILE"
          echo -en "          <td title=\"Movietitle\" class=\"title\">"
          # shellcheck disable=SC2291
          echo -e              "<div class=\"title_shortening\"><a target=\"_blank\" href=\"http://www.imdb.com/title/$ID/\">$TITLE</a></div></td>"
          echo -e "        </tr>"
        } >> "$XRELFILE"
      fi

    done < "$IDSFILE"


    ####
    # Printing footer to playlist
    ####

    if [ "$VERBOSE" -eq 1 ]
      then
        echo -e "Printing footers ..."
    fi
    {
      echo -e "  </rule>"
      echo -e "  <rule field=\"year\" operator=\"greaterthan\">$OLDESTYEAR</rule>"
      echo -e "</smartplaylist>"
    } >> "$PLAYLISTFILE"

    if [ "$TV" = "yes" ]
      then
        {
          echo -e "  </rule>"
          echo -e "</smartplaylist>"
        } >> "$PLAYLISTFILETV"
    fi

    ####
    # Create statistics
    ####
    if [ "$VERBOSE" -eq 1 ]
      then
        echo -e "  NOMCOUNT: $NOMCOUNT"
    fi
    if [ "$NOMINEESCOUNT" -gt 0 ]
      then
        STATTEXT="in your databse:            $MOVIECOUNT/$NOMINEESCOUNT ($(( 100*MOVIECOUNT/NOMINEESCOUNT )) %)\nalready watched:          $WATCHEDCOUNT/$NOMINEESCOUNT ($(( 100*WATCHEDCOUNT/NOMINEESCOUNT )) %)\n"
      else
        STATTEXT="in your databse:            $MOVIECOUNT/$NOMINEESCOUNT \n"
    fi
    if [ "$NOMCOUNT" -gt 0 ]
      then
        STATTEXT="${STATTEXT}watched nominations:  $WATCHEDNOMCOUNT/$NOMCOUNT ($(( 100*WATCHEDNOMCOUNT/NOMCOUNT )) %)"
      else
        STATTEXT="${STATTEXT}watched nominations:  $WATCHEDNOMCOUNT/$NOMCOUNT"
    fi

    ####
    # Change owner of file
    ####
    chown "$USER":"$GROUP" "$PLAYLISTFILE"
    if [ "$TV" = "yes" ]
      then
         chown "$USER":"$GROUP" "$PLAYLISTFILETV"
    fi

    ####
    # Create footer for HTML-file
    ####
    if [ "$XREL" -eq 1 ]
    then
      {
        echo -e  "      </tbody>"
        echo -e  "      <tfoot>"
        echo -e  "        <tr align=\"right\">"
        echo -en "          <td>$NOMINEESCOUNT</td><td>$MOVIECOUNT</td><td>$WATCHEDCOUNT"
        # shellcheck disable=SC2291
        echo -en           "</td><td></td><td colspan=\"3\">${WATCHEDNOMCOUNT}/${NOMCOUNT}</td><td></td>"
        echo -e  "        </tr>"
        echo -e  "      </tfoot>"
        echo -e  "    </table>"

        if [ "${LINK_ODR}" -eq 1 ] && [ ${EVENTSTRING} = "oscars" ]
          then
            # shellcheck disable=SC2140
            echo -e  "    <p><a target="_blank" href="https://oscarsdeathrace.com/">Oscar Death Race</a> (<a target="_blank" href="https://discord.com/channels/285429851463221258/831261774342258769">Discord</a>, <a target="_blank" href="https://www.reddit.com/r/oscarsdeathrace/">Reddit</a>)</p>"
        fi

        echo -e  "<!--"
        echo -e  "#STATS#${NOMINEESCOUNT}#${MOVIECOUNT}#${WATCHEDCOUNT}#${WATCHEDNOMCOUNT}"
        echo -e  "for index.html"
        echo -e  "//-->"
        echo -e  "    </br>"
        echo -e  "    <table class=\"meta\">"
        echo -e  "      <tr title=\"Last site update\"><td><i class=\"fas fa-sync-alt\"></td>"
        echo -e  "          <td></i>$DATETIME</td></tr>"
        echo -e  "      <tr title=\"Last database update\"><td><i class=\"fas fa-database\"></td>"
        echo -e  "          <td></i>$(date -r "${DBFILE}" +"%Y-%m-%d %H:%M")</td></tr>"
        echo -e  "      <tr title=\"Last repository commit\"><td><i class=\"fas fa-code-branch\"></i></td>"
        echo -e  "          <td>${GITCOMMIT}</td></tr>"
        echo -e  "     <table>"
        echo -e  "  </body>"
        echo -e  "</html>"
      } >> "$XRELFILE"
    fi
fi

# change owner of html file
chown "$WWWUSER":"$WWWGROUP" "$XRELFILE"


####
# Printing Infos to stdout and optionally to stats file
####
echo -e ""
echo -e "$STATTEXT"
echo -e ""

if [ "$STATS" -eq 1 ]
then
  if [ "$VERBOSE" -eq 1 ]
    then
      echo -e "Printing statistics ..."
  fi
  echo -e "$STATTEXT" > "$STATFILE"
fi


####
# Send mail
####

# Generate URL for Mail
if [ "${URLROOT}" != "" ]
  then
    URLTEXT="\n\n${URLROOT}/${FILENAMEPREFIX}.html"
  else
    URLTEXT=""
fi
if [ "${LINK_ODR}" -eq 1 ] && [ ${EVENTSTRING} = "oscars" ]
  then
    URLTEXT="${URLTEXT}\n\nhttps://oscarsdeathrace.com/"
fi

# check if stats have changed since last run
if [ "$MAIL" != "" ]
  then
    if [ -f "$STATFILEOLD" ]
      then
        STATDIFF=$(diff "$STATFILE" "$STATFILEOLD")
      else
        STATDIFF="new"
    fi

    if [ "$STATDIFF" != "" ] || [ "${FORCESEND}" = "1" ]
      then
        if [ "$VERBOSE" -eq 1 ]
          then
            echo -e "Stats changed or sending is forced. Sending mails."
        fi
        echo -e "From: ${FROM}\nSubject: ${SUBJECT}\n\n${STATTEXT}${URLTEXT}" | "${SENDMAIL}" "${MAIL}"
      else
        if [ "$VERBOSE" -eq 1 ]
          then
            echo -e "Stats did not change. Not sending mail."
        fi
    fi
fi


####
# create index.html
####

# Search for Award-HTML files
if [ "$VERBOSE" -eq 1 ]
  then
    echo ""
    echo "HTML files:"
    find "${HTMLDIR}" -name 'nominees*.html'
fi

# Get all available years
YEARS=$(find "${HTMLDIR}" -name 'nominees*.html' | awk -F "_" '{print substr($(NF), 1, length($(NF)-1))}' | sort -u -r)
#' fix wrong syntax highlighting in mcedit

if [ "$VERBOSE" -eq 1 ]
  then
    echo ""
    echo "YEARS: ${YEARS}"
fi



# Get all available events
EVENTS=$(find "${HTMLDIR}" -name 'nominees*.html' | awk -F "_" '{print $(NF-1)}' | sort -u)
#' fix wrong syntax highlighting in mcedit

if [ "$VERBOSE" -eq 1 ]
  then
    echo ""
    echo "EVENTS: ${EVENTS}"
fi


# Create header of index.html
{
   echo -e "<!DOCTYPE html>"
   echo -e "<html lang=\"en\">"
   echo -e "  <head>"
   echo -e "    <meta charset=\"utf-8\"/>"
   if [[ "${CSSFILE}" == "awards_dark.css" ]]
     then
       echo -e "    <meta name=\"theme-color\" content=\"#212121\">"
   fi
   echo -e "    <meta name=\"viewport\" content=\"width=device-width\">"
   echo -e "    <title>Award Shows</title>"
   echo -e "    <link rel=\"shortcut icon\" type=\"image/x-icon\" href=\"favicons/awards.ico\" />"
   echo -e "    <link rel=\"stylesheet\" type=\"text/css\" href=\"$CSSFILE\" />"
   echo -e "    <link rel=\"stylesheet\" href=\"https://use.fontawesome.com/releases/v5.7.2/css/all.css\" integrity=\"sha384-fnmOCqbTlWIlj8LyTjo7mOUStjsKC4pOpQbqyi7RrhN7udi9RwhKkMHpvLbHG9Sr\" crossorigin=\"anonymous\" />"
   echo -e "    <script src=\"sorttable.js\"></script>"
   echo -e "  </head>"
   echo -e "  <body>"
   echo -e "    <h1>Award Shows</h1>"
#   echo -e "    <h2>Award Shows</h2>"
   echo -e "    <table class=\"sortable shows\">"
   echo -e "      <thead>"
   echo -e "        <tr>"
   echo -e "          <th title=\"Event\" class=\"\">Event</th>"
   for YEAR in ${YEARS}; do
     echo -e "          <th title=\"${YEAR}\" class=\"sorttable_nosort\">${YEAR}</th>"
   done
   echo -e "        </tr>"
   echo -e "      </thead>"
   echo -e "      <tbody>"
 } >  "$INDEXHTML"


# Create body of index table
for EVENT in ${EVENTS}; do

  # Define Event
  case $EVENT in
    bafta )
      EVENTNAME="BAFTA"
      ;;
    cannes )
      EVENTNAME="Cannes Film Festival"
      ;;
    critics )
      EVENTNAME="Critics Choice"
      ;;
    emmy )
      EVENTNAME="Emmy Awards"
      ;;
    golden-globes )
      EVENTNAME="Golden Globe Awards"
      ;;
    independant )
      EVENTNAME="Independent Spirit Awards"
      ;;
    razzies )
      EVENTNAME="Razzie Awards"
      ;;
    sag )
      EVENTNAME="SAG Awards"
      ;;
    sundance )
      EVENTNAME="Sundance Film Festival"
      ;;
    oscars )
      EVENTNAME="Academy Awards"
      ;;
  esac


  echo -e  "        <tr>"                                                                >> "${INDEXHTML}"
  echo -e  "          <td title=\"${EVENTNAME}\"        class=\"\">${EVENTNAME}</td>"    >> "${INDEXHTML}"
  for YEAR in ${YEARS}; do
    NOMINEEHTML="${HTMLDIR}/nominees_${EVENT}_${YEAR}.html"
    if [ -f "${NOMINEEHTML}" ]
      then
        if EVENTSTATS=$(grep "#STATS" "${NOMINEEHTML}")
          then
            EVENTMOVIES=$(echo "${EVENTSTATS}" | awk -F# '{print $3}')
            EVENTMOVIESWATCHED=$(echo "${EVENTSTATS}" | awk -F# '{print $5}')
            EVENTMOVIESWATCHEDPERCENTAGE=$((100*EVENTMOVIESWATCHED/EVENTMOVIES))
            echo -e  "          <td title=\"watched ${EVENTMOVIESWATCHED} of ${EVENTMOVIES}\"  class=\"event\"><a href=\"./nominees_${EVENT}_${YEAR}.html\"><div class=\"pie animate\" style=\"--p:${EVENTMOVIESWATCHEDPERCENTAGE};\">${EVENTMOVIESWATCHEDPERCENTAGE} %</div></a></td>"   >> "${INDEXHTML}"
          else
            echo -e  "          <td title=\"no data\"  class=\"event\"><a href=\"./nominees_${EVENT}_${YEAR}.html\">n/a</a></td>"   >> "${INDEXHTML}"
        fi
      else
        echo -e  "          <td title=\"no data\"  class=\"event\"></td>"                >> "${INDEXHTML}"
    fi
  done
  echo -e  "        </tr>"                                                               >> "${INDEXHTML}"
done


# Create footer for HTML-file
{
  echo -e  "      </tbody>"
#  echo -e  "      <tfoot>"
#  echo -e  "        <tr>"
#  echo -en "          <td></td><td></td><td>"
#  echo -en           "</td><td></td><td></td><td></td><td></td><td></td>"
#  echo -e  "        </tr>"
#  echo -e  "      </tfoot>"
  echo -e  "    </table>"

  echo -e  "    </br>"

  echo -e  "    <table class=\"meta\">"
  echo -e  "      <tr title=\"Last site update\"><td><i class=\"fas fa-sync-alt\"></td>"
  echo -e  "          <td></i>$DATETIME</td></tr>"
  echo -e  "      <tr title=\"Last database update\"><td><i class=\"fas fa-database\"></td>"
  echo -e  "          <td></i>$(date -r "${DBFILE}" +"%Y-%m-%d %H:%M")</td></tr>"
  echo -e  "      <tr title=\"Last repository commit\"><td><i class=\"fas fa-code-branch\"></i></td>"
  echo -e  "          <td>${GITCOMMIT}</td></tr>"
  echo -e  "     <table>"
  echo -e  "  </body>"
  echo -e  "</html>"
} >> "${INDEXHTML}"












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
    if [ "$VERBOSE" -eq 1 ]
      then
        echo -e "Not deleting temp-files."
    fi
fi

echo -e "Finished."
exit 0