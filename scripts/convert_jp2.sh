#! /bin/sh

# This file is not directly used by the deployed application. It has its own scripts directory
# with a similar script. The included test_app however does use this file directly.

if [ $3 = "BW" ] ; then
  CS="sLUM"
else
  CS="sRGB"
fi  

case $4 in
  watermark)
  SIZE=`convert "$1" -format "%wx%h" info:`
  EXTENSION=`echo "$1" | sed 's/.*\.//'`
  TMPFILE=`mktemp /tmp/trifle_convert.XXXXXX.$EXTENSION`
  WATERMARKFILE="/home/qgkb58/hydra/test_watermark.png"
  if [ $CS = "sRGB" ] ; then
    convert -gravity center -compose dissolve -define compose:args=10% -composite -geometry $SIZE "$1" "$WATERMARKFILE" -depth 8 -type TrueColorMatte "$TMPFILE"
  else
    convert -gravity center -compose dissolve -define compose:args=10% -composite -geometry $SIZE "$1" "$WATERMARKFILE" -depth 8 -type GrayscaleMatte "$TMPFILE"
  fi
  kdu_compress -i "$TMPFILE" -o "$2" -rate 2.4,1.48331273,.91673033,.56657224,.35016049,.21641118,.13374944,.08266171 Creversible=yes Clevels=7 Cblk=\{64,64\} -jp2_space $CS Cuse_sop=yes Cuse_eph=yes Corder=RLCP ORGgen_plt=yes ORGtparts=R Stiles=\{1024,1024\} -double_buffering 10 -num_threads 4 -no_weights
  rm $TMPFILE
  ;;
# "printed") kdu_compress -i "$1" -o "$2" -rate 2.4,1.48331273,.91673033,.56657224,.35016049,.21641118,.13374944,.08266171 Creversible=yes Clevels=7 Cblk=\{64,64\} -jp2_space $CS Cuse_sop=yes Cuse_eph=yes Corder=RLCP ORGgen_plt=yes ORGtparts=R Stiles=\{1024,1024\} -double_buffering 10 -num_threads 4 -no_weights ;;
  *) kdu_compress -i "$1" -o "$2" -rate 2.4,1.48331273,.91673033,.56657224,.35016049,.21641118,.13374944,.08266171 Creversible=yes Clevels=7 Cblk=\{64,64\} -jp2_space $CS Cuse_sop=yes Cuse_eph=yes Corder=RLCP ORGgen_plt=yes ORGtparts=R Stiles=\{1024,1024\} -double_buffering 10 -num_threads 4 -no_weights ;;
esac
