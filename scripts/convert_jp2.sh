#! /bin/sh

kdu_compress -i $1 -o $2 -rate 1.5  Clayers=1 Clevels=7 "Cprecincts={256,256},{256,256},{128,128}" "Corder=RPCL" "ORGgen_plt=yes" "ORGtparts=R" "Cblk={64,64}" Cuse_sop=yes
