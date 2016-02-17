#! /bin/sh
# Imagemagic identify, not very good for large JP2 files
identify $1 | sed -r -n "s/^([^ \[]+)(\[0\])? ([^ ]+) ([0-9]+x[0-9]+) .*$/\4/p"
