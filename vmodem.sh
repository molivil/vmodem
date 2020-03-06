#!/bin/bash
#
# --------------------------------
# VMODEM - Virtual Modem bootstrap
# --------------------------------
# Oliver Molini 2019 Billy Stoughton II/Lord_NT 2020
#
# Licensed under Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International Public License
# https://creativecommons.org/licenses/by-nc-sa/4.0/
#
# Tested working out of box with the following host configurations:
#
# o Most Standard VT100 terminals and terminal emulations
# o HyperTerminal
# o PuTTY
#
# PPP connectivity will initialize correctly under the following configurations:
#
# o Microsoft Windows 3.1
# - Generic
#     - Standard 14400 or 28800 bps Modem
#     - Trumpet Winsock (Dial ATDT1)
#
# o Microsoft Windows 95,98?
# - Generic
#     - Standard 28800 bps Modem
#     - Trumpet Winsock (Dial ATDT1)
#
# o Microsoft Windows 9x.ME - Windows 10
#   - Generic
#     - Standard 28800 bps Modem
#     - Standard 33600 bps Modem <-- Win2k and UP use this modem
#     (::NOTE:: dial ATDT2 to disable fake login if needed WinNT 3.51 - 10)
#
# o Serial Line Setup
#   - Baud 57600 8,N,1 'No Flow Control'
#
# o Lynx
#   - Type lynx to start a Lynx Web Browser session from your terminal. (!!if lynx is installed on your pi!!)
#
# o Local Login
#   - Type login to get a Linux Login Shell session from your terminal.
#
# o Telnet Session
#   - Type telnet to get a telnet session

# ::NOTE:: !!if you have a 8250 UART you must use speeds of 19200 baud or lower!!

# Temperature script variables do not mess with please :) Lord_NT !!requires sed, awk and a raspberry pi !!
#degf=(`vcgencmd measure_temp | sed -e 's/temp=//g' | sed "s/['']C//g" | awk '{print $stdout * 1.8 + 32}'`)
#degc=(`vcgencmd measure_temp | sed -e "s/temp=//g" | sed "s/['']C//g"`)

# Script version
vmodver=1.4.2b_NT

# CONFIGURATION
# -----------------------

# Variable: term
# term sets tty terminal type. ansi or vt100 default=vt100.
term=vt100

# Variable: serport
# serport specifies which local serial device to use.
# For example, using "ttyAMA0" will tell the script
# to use /dev/ttyAMA0 for communication.
#
# Default:
# serport=ttyUSB0
#
serport=ttyUSB0

# Variable: baud
# baud will tell the script to open the serial port at
# specified symbol rate. When connecting, make sure
# your client computer uses the same baud than what
# has been specified here.
# Common baud rates: 9600, 19200, 38400, 57600, 115200
#
# Default:
# baud=57600
#
baud=57600

# Variable: echoser
# echoser sets the default behaviour of echoing serial
# data back to the client terminal. The default is 1.
#
echoser=1

# Variable: resultverbose
# Controls default behavior when printing Hayes result
# codes. 
# When 0, prints result codes in numerical form. (eg. 0)
# When 1, prints result codes in english. (eg. CONNECT)
# Default is 1.
resultverbose=1

# EXPORT SHELL VARS
# -----------------
export serport
export baud

# FUNCTIONS
# ---------
#

#INITIALIZE SERIAL SETTINGS
ttyinit () {
  stty -F /dev/$serport $baud
  stty -F /dev/$serport sane
  stty -F /dev/$serport raw
  stty -F /dev/$serport -echo -icrnl clocal
}

# SEND MESSAGE ON SCREEN AND OVER SERIAL
sendtty () {
  echo -en "$1\n";
  echo -en "$1\x0d\x0a" >/dev/$serport
}

# Open serial port for use. Allocate file descriptor
# and treat the serial port as a file.
ttyinit
exec 99<>/dev/$serport

sendtty ""
sendtty "VMODEM - Virtual Modem bootstrap for PPP link v$vmodver"
sendtty "'Oliver Molini' 2020 'Billy Stoughton II/Lord_NT' 2020"
sendtty "Connection speed set to $baud baud"
sendtty ""
sendtty "TYPE HELP FOR COMMANDS"
sendtty "READY."

# MAIN LOOP
while [ "$continue" != "1" ]; do
  charhex=`head -c 1 /dev/$serport | xxd -p -`
  char="`echo -e "\x$charhex"`"

  #ECHO SERIAL INPUT TO TTY
  echo -n "$char"

  #ECHO SERIAL INPUT
  if [ "$echoser" = "1" ]; then echo -n "$char" > /dev/$serport; fi

  #CHECK IF NEWLINE IS SENT
  if [ "$charhex" = "0d" -o "$charhex" = "0a" ]; then
    line=$buffer
    # PARSE COMMAND
    cmd=`echo -en $buffer | tr a-z A-Z`
    buffer=
    char=

    #NEWLINE SENT - ECHO NEWLINE TO CONSOLE
    if [ "$echoser" = "0" ]; then echo; fi
    if [ "$echoser" = "1" ]; then sendtty; fi

    #
    # --- HAYES EMULATION ---
    #
    if [[ $cmd == AT* ]]; then
      # ok, the client issued an AT command
      #
      # default to error result code, if command not recognized
      result=4

      if [[ $cmd == AT ]]; then result=0; fi

      # Get hayes string
      seq=`echo $cmd |cut -b3-`
      # ATA
      if [[ $seq == A ]]; then result=0; fi

      # ATH Go on-hook, hang up.
      if [[ $seq == H* ]]; then result=0; fi  # H0 Go on-hook (Hang up)
      if [[ $seq == H1* ]]; then result=0; fi # H1 Go off-hook

      # ATZ Reset modem
      if [[ $seq == Z* ]]; then echoser=1; resultverbose=1; result=0; fi      # Zn  Restore stored profile n

      # AT&F Restore factory settings
      if [[ $seq == *\&F* ]]; then echoser=1; resultverbose=1; result=0; fi   # &Fn Use profile n

      # ATE Command echo to host
      if [[ $seq == *E0* ]]; then echoser=0; result=0; fi        # E0 Commands are not echoed
      if [[ $seq == *E1* ]]; then echoser=1; result=0; fi       # E1 Commands are echoed

      # ATV Result codes in numerical or verbose form
      if [[ $seq == *V0* ]]; then resultverbose=1; result=0; fi  # V0 Returns the code in numerical form
      if [[ $seq == *V1* ]]; then resultverbose=1; result=0; fi # V1 Full-word result codes

      # ATM Speaker control
      if [[ $seq == *M* ]]; then result=0; fi                   # M0 Speaker always off
      if [[ $seq == *M1* ]]; then result=0; fi                  # M1 Speaker on until carrier detected
      if [[ $seq == *M2* ]]; then result=0; fi                  # M2 Speaker always on
      if [[ $seq == *M3* ]]; then result=0; fi                  # M3 Speaker on only while answering

      # AT&Cn Carrier-detect
      if [[ $seq == *C0* ]]; then result=0; fi
      if [[ $seq == *C1* ]]; then result=0; fi

      # AT&Dn Data Terminal Ready settings
      if [[ $seq == *D0* ]]; then result=0; fi                # Modem ignores DTR
      if [[ $seq == *D1* ]]; then result=0; fi                # Go to command mode on ON-to-OFF DTR transition.
      if [[ $seq == *D2* ]]; then result=0; fi                # Hang up on DTR-drop and go to command mode
      if [[ $seq == *D3* ]]; then result=0; fi                # Reset (ATZ) on DTR-drop. Modem hangs up.

      # AT&Sn DSR Override
      if [[ $seq == *S0* ]]; then result=0; fi # &S0 DSR will remain on at all times.
      if [[ $seq == *S1* ]]; then result=0; fi # &S1 DSR will become active after answer tone has been detected and inactive after the carrier has been lost

      # ATQn Result codes
      if [[ $seq == *Q0* ]]; then resultverbose=1; result=0; fi # Q0 Modem returns result codes
      if [[ $seq == *Q1* ]]; then resultverbose=2; result=0; fi # Q1 Quiet mode. Modem gives no result codes.

      # ATXn Extended result codes
      if [[ $seq == *X0* ]]; then resultverbose=1; result=0; fi     # X0 Disable extended result codes (Hayes Smartmodem 300 compatible result codes)
      if [[ $seq == *X1* ]]; then resultverbose=1; result=0; fi     # X1 Add connection speed to basic result codes (e.g. CONNECT 1200)
      if [[ $seq == *X2* ]]; then resultverbose=1; result=0; fi     # X2 Add dial tone detection (preventing blind dial, and sometimes preventing ATO)
      if [[ $seq == *X3* ]]; then resultverbose=1; result=0; fi     # X3 Add busy signal detection
      if [[ $seq == *X4* ]]; then resultverbose=1; result=0; fi     # X4 Add both busy signal and dial tone detection

      # Windows Modem Diagnostic Faker Lord_NT
      if [[ $seq == *GMM* ]]; then resultverbose=1; result=0; fi
      if [[ $seq == *FCLASS=?* ]]; then resultverbose=0; result=0; fi
      if [[ $seq == *CLS* ]]; then resultverbose=1; result=0; fi
      if [[ $seq == *GCI?* ]]; then resultverbose=1; result=0; fi
      if [[ $seq == *GCI=?* ]]; then resultverbose=1; result=0; fi
      if [[ $seq == *ATI1* ]]; then resultverbose=1; result=0; fi
      if [[ $seq == *ATI2* ]]; then resultverbose=1; result=0; fi
      if [[ $seq == *ATI3* ]]; then resultverbose=1; result=0; fi
      if [[ $seq == *ATI4* ]]; then resultverbose=1; result=0; fi
      if [[ $seq == *ATI5* ]]; then resultverbose=1; result=0; fi
      if [[ $seq == *ATI6* ]]; then resultverbose=1; result=0; fi
      if [[ $seq == *ATI7* ]]; then resultverbose=1; result=0; fi
      if [[ $seq == *q* ]]; then resultverbose=0; fi

      # ATD Dial number
      if [[ $cmd == ATD* ]]; then
        # Get number, if applicable
        number=`echo $seq |tr -dc '0-9'`
        if [ ! -z "$number" ]; then
          if [[ $resultverbose == 1 ]]; then sendtty "RINGING"; fi
          if [ -f "$number.sh" ]; then
            if [[ $resultverbose == 1 ]]; then sendtty "CONNECT $baud"; else sendtty "1"; fi
            # Execute dialed script
            /sbin/getty -8 -L $serport $baud $term -n -l "./$number.sh"
            # Reset serial settings
            ttyinit
            result=3
          else
            # Phone number is valid, but no internal script by that name exists
            result=3
          fi
        else
          # No number specified, return OK status code
          result=0
        fi
      fi

      #
      # --- PRINT RESULT CODE ---
      #
      if [[ $resultverbose == 0 ]]; then
        sendtty $result;
      elif [[ $resultverbose == 1 ]]; then
        if [[ $result == 0 ]]; then sendtty "OK"; fi
        if [[ $result == 1 ]]; then sendtty "CONNECT"; fi
        if [[ $result == 2 ]]; then sendtty "RING"; fi
        if [[ $result == 3 ]]; then sendtty "NO CARRIER"; fi
        if [[ $result == 4 ]]; then sendtty "ERROR"; fi
        if [[ $result == 5 ]]; then sendtty "CONNECT 1200"; fi
        if [[ $result == 6 ]]; then sendtty "NO DIALTONE"; fi
        if [[ $result == 7 ]]; then sendtty "BUSY"; fi
        if [[ $result == 8 ]]; then sendtty "NO ANSWER"; fi
      fi
    fi

    if [[ $cmd = HELP ]]; then
      sendtty "Command Reference for Virtual Modem Bootstrap v$vmodver"
      sendtty
      sendtty "AT......Tests modem link, prints OK if successful"
      sendtty "ATE0....Switch terminal echo off"
      sendtty "ATE1....Switch terminal echo on"
      sendtty "ATD?....Fork program ?.sh and output on terminal"
      sendtty "ATDT1...Open PPPD connection"
      sendtty "ATZ.....Reset modem settings"
      sendtty "HELP....Display command reference"
      sendtty "LOGIN...Fork a new linux login on serial"
      sendtty "LYNX....Start the Lynx text web browser"
      sendtty "TELNET..Start a telnet session"
      sendtty "TEMP....Raspberry Pi 'only' Measures SOC temp and displays"
      sendtty "EXIT....End this script"
      sendtty
      sendtty "To establish connection over PPP, dial 1 using tone dialing (ATDT1)"
      sendtty
      sendtty "READY."
    fi

    # LOGIN  -  FORK LOGIN SESSION
    if [[ $cmd == LOGIN ]]; then
      exec 99>&-
      /sbin/getty -8 -n -L $serport $baud $term
      ttyinit
      exec 99<>/dev/$serport
      sendtty; sendtty "READY."
    fi

    # TEMP  -  RASPI TEMP DISPLAY Lord_NT ::enable only if you have a raspberry pi::
#    if [[ $cmd = TEMP ]]; then
# 	sendtty "\e[31mRaspberry \e[32mPi \e[39mSOC Temperature Sensor"
# 	sendtty "\e[91m$degf Degrees Fahrenheit"
# 	sendtty "\e[96m$degc Degrees Celsius"
# 	sleep 2
#    fi

    # LYNX  -  FORK LYNX SESSION (!!make sure you have lynx installed!!)
    if [[ $cmd == LYNX ]]; then
      exec 99>&-
      /sbin/getty -8 -L $serport $baud $term -n -l "st_lynx.sh"
      ttyinit
      exec 99<>/dev/$serport
      sendtty; sendtty "READY."
    fi
    
    # EXIT  -  EXIT SCRIPT
    if [ "$cmd" = "EXIT" ]; then sendtty "OK"; continue="1"; fi
  fi
  buffer=$buffer$char
done

#Close serial port
exec 99>&-
