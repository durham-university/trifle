#! /bin/sh

convert -compress none -define tiff:tile-geometry=256x256 $1 ptif:$2
