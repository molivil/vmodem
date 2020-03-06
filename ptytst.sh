#/bin/bash
# --------------------------------
# VMODEM - Virtual Modem bootstrap
# --------------------------------
# Oliver Molini 2020 Billy Stoughton II/Lord_NT 2020
#
# Licensed under Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International Public License
# https://creativecommons.org/licenses/by-nc-sa/4.0/
#
#
# !!Requires socat and netcat to function!!
#
# run ptytst.sh once to see pty# generated then adjust the ksnetcat.sh and vmodem.sh scripts accordingly.
#
# the "1st pty#" is for the "ptsnum=" variable in "ksnetcat.sh" the "2nd pty#" is for vmodem.sh. Example for vmodem.sh port: serport=pty/6
#
socat -d  -d pty,raw,echo=0 pty,raw,echo=0 &
killall socat
