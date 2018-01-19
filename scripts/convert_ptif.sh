#! /bin/sh

# This file is not directly used by the deployed application. It has its own scripts directory
# with a similar script. The included test_app however does use this file directly.

convert -compress none -define tiff:tile-geometry=256x256 "$1" "ptif:$2"
