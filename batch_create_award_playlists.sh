#!/bin/sh
# This script creates mutiple award_plalists in one run
#
# Usage: ./batch_create_award_playlists.sh FISRTYEAR LASTYEAR "award show letters in quotes"
# Example: ./batch_create_award_playlists.sh 2010 2030 "a b ca cri e g i r sag sun a"

echo "first year: $1"
echo "last year: $2"
echo "Events: $3"


for EVENT in $3
  do
    for YEAR in $(seq $1 $2)
      do
        echo "$EVENT $YEAR"
        /storage/scripts/award_playlists/award_playlists.sh -e $EVENT -y $YEAR -x
    done
done
