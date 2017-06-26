#! /bin/sh
if [ $3 = "BW" ] ; then
  CS="sLUM"
else
  CS="sRGB"
fi  

case $4 in
# "printed") kdu_compress -i "$1" -o "$2" -rate 2.4,1.48331273,.91673033,.56657224,.35016049,.21641118,.13374944,.08266171 Creversible=yes Clevels=7 Cblk=\{64,64\} -jp2_space $CS Cuse_sop=yes Cuse_eph=yes Corder=RLCP ORGgen_plt=yes ORGtparts=R Stiles=\{1024,1024\} -double_buffering 10 -num_threads 4 -no_weights ;;
  *) kdu_compress -i "$1" -o "$2" -rate 2.4,1.48331273,.91673033,.56657224,.35016049,.21641118,.13374944,.08266171 Creversible=yes Clevels=7 Cblk=\{64,64\} -jp2_space $CS Cuse_sop=yes Cuse_eph=yes Corder=RLCP ORGgen_plt=yes ORGtparts=R Stiles=\{1024,1024\} -double_buffering 10 -num_threads 4 -no_weights ;;
esac
