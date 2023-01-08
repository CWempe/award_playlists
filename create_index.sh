#!/bin/bash
#################################################################################################################
#
# by Christoph Wempe
#
# This script creates an index.hmtl for all generated award lists.
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









# Define files and directories
BINDIR="$( cd "$(dirname "$0")" || { echo "Command cd failed!"; exit 1; } ; pwd -P )"
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
# shellcheck disable=SC1091,SC1090
source "$CONFIG"


INDEXHTML="${HTMLDIR}/index.html"

# change dir to $BINDIR for git to work
cd "$BINDIR" || { echo "Command cd failed!"; exit 1; }

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
    echo -e " FROM:           $FROM"
    echo -e " MAIL:           $MAIL"
    echo -e " SUBJECT:        $SUBJECT"
    echo -e " YEAR:           $YEAR"
    echo -e " OLDESTYEAR:     $OLDESTYEAR"
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
    echo -e ""
fi















# Search for Award-HTML files

if [ "$VERBOSE" -eq 1 ]
  then
    echo ""
    echo "HTML files:"
    find ${HTMLDIR} -name nominees*.html
fi



# Get all available years
YEARS=$(find ${HTMLDIR} -name nominees*.html | awk -F "_" '{print substr($(NF), 1, length($(NF)-1))}' | sort -u -r)
#' fix wrong syntax highlighting in mcedit

if [ "$VERBOSE" -eq 1 ]
  then
    echo ""
    echo "YEARS: ${YEARS}"
fi



# Get all available events
EVENTS=$(find ${HTMLDIR} -name nominees*.html | awk -F "_" '{print $(NF-1)}' | sort -u)
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




for EVENT in ${EVENTS}; do
  echo -e  "        <tr>"                                                                >> "${INDEXHTML}"
  echo -e  "          <td title=\"${EVENT}\"        class=\"\">${EVENT}</td>"            >> "${INDEXHTML}"
  for YEAR in ${YEARS}; do
    NOMINEEHTML="${HTMLDIR}/nominees_${EVENT}_${YEAR}.html"
    if [ -f "${NOMINEEHTML}" ]
      then
        echo -e  "          <td title=\"${EVENT} ${YEAR}\"  class=\"\"><a href=\"./nominees_${EVENT}_${YEAR}.html\">${YEAR}</a></td>"   >> "${INDEXHTML}"
      else
        echo -e  "          <td title=\"no data\"  class=\"\"></td>"                     >> "${INDEXHTML}"
    fi
  done
  echo -e  "        </tr>"                                                               >> "${INDEXHTML}"
done




    ####
    # Create footer for HTML-file
    ####
      {
  echo -e  "      </tbody>"
#  echo -e  "      <tfoot>"
#  echo -e  "        <tr>"
#  echo -en "          <td></td><td></td><td>"
#  echo -en           "</td><td></td><td></td><td></td><td></td><td></td>"
#  echo -e  "        </tr>"
#  echo -e  "      </tfoot>"
  echo -e  "    </table>"

  echo -e  "    <table class=\"meta\">"
  echo -e  "      <tr><td><i class=\"fas fa-sync-alt\"></td>"
  echo -e  "          <td></i>$DATETIME</td></tr>"
  echo -e  "      <tr><td><i class=\"fas fa-code-branch\"></i></td>"
  echo -e  "          <td>${GITCOMMIT}</td></tr>"
  echo -e  "     <table>"
  echo -e  "  </body>"
  echo -e  "</html>"
} >> "${INDEXHTML}"




















if [ "$VERBOSE" -eq 1 ]
  then
    echo -e "Fished."
fi

exit 0
