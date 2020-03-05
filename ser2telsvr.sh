#/bin/bash
# Lord_NT 2020
#
# !!Requires socat and netcat to function!!
#
# run ser2telsvr.sh once to see pty# generated then adjust the ksnetcat.sh and vmodem.sh scripts accordingly.
#
# the "1st pty#" is for the "ptsnum=" variable in "ksnetcat.sh" the "2nd pty#" is for vmodem.sh. Example for vmodem.sh port: serport=pty/6
BACK_PID=$!
socat -d  -d pty,raw,echo=0 pty,raw,echo=0 &
./ksnetcat.sh
