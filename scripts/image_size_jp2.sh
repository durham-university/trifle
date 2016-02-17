#! /bin/sh
# Kakadu
kdu_jp2info -i $1 | sed -r -n "s/^ *<width> *([0-9]+) *<\/width> *$/\1/p;s/^ *<height> *([0-9]+) *<\/height> *$/x\1/p" | sed -r "N;s/\\n//"
