#!/bin/bash
#
# --------------------------------
# VMODEM - Virtual Modem bootstrap
# --------------------------------
# Oliver Molini 2020-2022
#
# Additional credits:
# - Billy Stoughton II for bug fixes and contributions
# - Hamish for helping test Windows 2000 compatibility
#
# Licensed under Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International Public License
# https://creativecommons.org/licenses/by-nc-sa/4.0/

# Tested working out of box with the following client configurations:
#
# o Standard VT100 terminal
# o HyperTerminal
# o PuTTY
#
# PPP dial-up connectivity tested to initialize under the following configurations:
#
# o Windows 3.1
#   - Trumpet Winsock 3.0 revision D
#
# o Windows 95 OSR 2.5 + DUN 1.4
#   - Generic Modem
#     - Standard 28800 bps Modem
#
# o Windows 98
#   - Generic Modem
#     - Standard 9 600 bps modem
#     - Standard 33 600 bps modem
#     - Standard 56 000 bps V90 modem
#     - Standard 56 000 bps X2 modem
#     - Standard 56 000 bps K56Flex modem
#
# o Windows 2000
#   - Generic Modem
#     - Standard 19200 bps Modem
#
# Help us test and add more supported systems! 
# Contact us on Discord, links at the bottom of the Virtual Modem page.
#

# Script version
vmodver=1.7.2 

# CONFIGURATION
# -----------------------
# Variable: serport
# serport specifies which local serial device to use.
# For example, "ttyUSB0" will tell the script to use
# to use /dev/ttyUSB0 for communication.
# Common values: ttyUSB0 or ttyAMA0
#
serport=ttyUSB0

# Variable: baud
# baud will tell the script to open the serial port at
# specified symbol rate. When connecting, make sure
# your client computer uses the same baud than what
# has been specified here.
# Common baud rates: 9600, 19200, 38400, 57600
#
# Default:
# baud=57600
#
#baud=9600
#baud=38400
baud=57600

# Variable: etherp
# Sets the name of the ethernet device for PPP connections.
# 
# eth0 for wired 
# wlan0 for wireless
#
etherp=eth0

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

# Variable: TERM
# Tells the script and environment which type of terminal to emulate.
# It is only useful to change this, if you're using a serial 
# terminal to connect to this script. If you're connecting form a ANSI 
# cabable machine such as DOS, you may want to use TERM="ansi"
#
TERM="vt100"

# EXPORT SHELL VARS
# -----------------
export serport
export baud
export etherp
export TERM

# FUNCTIONS
# ---------
#

#INITIALIZE SERIAL SETTINGS
ttyinit () {
  stty -F /dev/$serport $baud
  stty -F /dev/$serport sane
  stty -F /dev/$serport raw
  stty -F /dev/$serport -echo -icrnl onlcr opost clocal -crtscts
}

# SEND MESSAGE ON SCREEN AND OVER SERIAL
sendtty () {
  # Prints message in console and over serial. Message is given as first parameter.
  message="$1"
  echo -en "$message" | tee /dev/$serport
}

readtty () {
  # Reads input from TTY and stores it in variable given as first parameter
  line=
  while [[ -z "$line" ]]; do
    charhex=`head -c 1 /dev/$serport | xxd -p -`
    char="`echo -e "\x$charhex"`"
    echo -n "$char"
    echo -n "$char" > /dev/$serport
    # Newline received
    if [ "$charhex" = "0d" -o "$charhex" = "0a" ]; then
      line=$buffer
      buffer=
      char=
      sendtty "\n"
    fi
    buffer=$buffer$char
  done
  local __resultvar=$1
  local result="$line"
  eval $__resultvar="'$result'"
}

export -f sendtty
export -f readtty
export -f ttyinit

# Open serial port for use. Allocate file descriptor
# and treat the serial port as a file.
ttyinit
exec 99<>/dev/$serport

sendtty "\n"
sendtty "Virtual Modem bootstrap for PPP link v$vmodver\n"
sendtty "Connection speed set to $baud baud.\n"
sendtty "My current IP address is $(hostname -I).\n"
sendtty "\n"
sendtty "TYPE \"HELP\" FOR COMMAND REFERENCE.\n"
sendtty "READY.\n"

# execute hayes commands
dohayes () {
  # default to error result code, if command not recognized
  result=4

  # Debugging
  #sendtty "COMMAND: $hcmd $hparm\n"

  # ATA
  # - A Answer
  if [[ $hcmd == 'A' ]]; then result=0; fi

  # ATD Dial a number
  if [[ $hcmd == 'D' ]]; then
    if [[ ! -z "$hparm" ]]; then
  	  # Ignore if it is ATX4DT
      if [[ $hparm != 'T' ]]; then
      	number=$(echo $hparm |tr -dc '0-9')
      	ringing=1
      	result=0
      fi
    fi
  fi

  # ATE Command echo to host
  # - E0 Commands are not echoed
  # - E1 Commands are echoed
  if [[ $hcmd == 'E' ]]; then
    if [[ $hparm == '' ]]; then echoser=0; result=0; fi
    if [[ $hparm == '0' ]]; then echoser=0; result=0; fi
    if [[ $hparm == '1' ]]; then echoser=1; result=0; fi
  fi

  # ATH Hang up or pick-up.
  # - H0 Go on-hook (Hang up)
  # - H1 Go off-hook
  if [[ $hcmd == 'H' ]]; then result=0; fi

  # ATM Speaker control
  # - M0 Speaker always off
  # - M1 Speaker on until carrier detected
  # - M2 Speaker always on
  # - M3 Speaker on only while answering
  if [[ $hcmd == 'M' ]]; then
    if [[ $hparm == '' ]]; then result=0; fi
    if [[ $hparm == '1' ]]; then result=0; fi
    if [[ $hparm == '2' ]]; then result=0; fi
    if [[ $hparm == '3' ]]; then result=0; fi
  fi

  # ATQn Result codes
  # Q0 Modem returns result codes
  # Q1 Quiet mode. Modem gives no result codes.
  if [[ $hcmd == 'Q' ]]; then
    if [[ $hparm == '' ]]; then resultverbose=0; result=0; fi
    if [[ $hparm == '0' ]]; then resultverbose=0; result=0; fi
    if [[ $hparm == '1' ]]; then resultverbose=2; result=0; fi
  fi

  # S Registers (just auto-accept)
  if [[ $hcmd == 'S' ]]; then
    result=0;
  fi

  # ATV Result codes in numerical or verbose form
  # - V0 Returns the code in numerical form
  # - V1 Full-word result codes
  if [[ $hcmd == 'V' ]]; then
    if [[ $hparm == '' ]]; then resultverbose=0; result=0; fi
    if [[ $hparm == '0' ]]; then resultverbose=0; result=0; fi
    if [[ $hparm == '1' ]]; then resultverbose=1; result=0; fi
  fi

  # ATXn Extended result codes
  # - X0 Disable extended result codes (Hayes Smartmodem 300 compatible result codes)
  # - X1 Add connection speed to basic result codes (e.g. CONNECT 1200)
  # - X2 Add dial tone detection (preventing blind dial, and sometimes preventing ATO)
  # - X3 Add busy signal detection
  # - X4 Add both busy signal and dial tone detection
  # ATX4DT <Phone number>
  # ATX4DT   1 will dial 1.
  # We must also disable RINGING command, Windows 3.11 do not support it and it will hang the connection.
  # This is used in Windows 3.11 Internet Explorer dialup connection. (It is not used by Trumpet! Trumpet use ATDT1)
  if [[ $hcmd == 'X' ]]; then
    if [[ $cmd =~ ATX[0-9]DT ]]; then
      number=$(echo "$cmd" | grep -oP 'DT\s*\K[0-9]+')
      ringing=0
      result=0
    else
      if [[ $hparm == '' ]]; then resultverbose=1; result=0; fi
      if [[ $hparm == '0' ]]; then resultverbose=1; result=0; fi
      if [[ $hparm == '1' ]]; then resultverbose=0; result=0; fi
      if [[ $hparm == '2' ]]; then resultverbose=0; result=0; fi
      if [[ $hparm == '3' ]]; then resultverbose=0; result=0; fi
      if [[ $hparm == '4' ]]; then resultverbose=0; result=0; fi
    fi
  fi
  
  # ATZ Reset modem
  # - Zn  Restore stored profile n
  if [[ $hcmd == 'Z' ]]; then echoser=1; resultverbose=1; carrierdetect=0; result=0; fi

  # AT&Cn Carrier-detect
  # - &C0 Force DCD signal active
  # - &C1 DCD signal indicates true state of remote carrier signal
  if [[ $hcmd == '&C' ]]; then
    if [[ $hparm == '' ]]; then result=0; carrierdetect=0; fi
    if [[ $hparm == '0' ]]; then result=0; carrierdetect=0; fi
    if [[ $hparm == '1' ]]; then result=0; carrierdetect=1; fi
  fi

  # AT&Dn Data Terminal Ready settings
  # - &D0 Modem ignores DTR
  # - &D1 Go to command mode on ON-to-OFF DTR transition.
  # - &D2 Hang up on DTR-drop and go to command mode
  # - &D3 Reset (ATZ) on DTR-drop. Modem hangs up.
  if [[ $hcmd == '&D' ]]; then
    if [[ $hparm == '' ]]; then result=0; fi
    if [[ $hparm == '0' ]]; then result=0; fi
    if [[ $hparm == '1' ]]; then result=0; fi
    if [[ $hparm == '2' ]]; then result=0; fi
    if [[ $hparm == '3' ]]; then result=0; fi
  fi

  # AT&F Restore factory settings
  # - &Fn Use profile n
  if [[ $hcmd == '&F' ]]; then echoser=1; resultverbose=1; carrierdetect=0; result=0; fi

  # AT&K DTE - MODEM Flow control
  # - &K0 Local flow control off
  # - &K1 Not used
  # - &K2 Not used
  # - &K3 RTS/CTS
  # - &K4 XON/XOFF
  # - &K5 Transparent XON/XOFF
  # - &K6 RTS/CTS and XON/XOFF
  if [[ $hcmd == '&K' ]]; then result=0; fi

  # AT&Sn DSR Override
  # - &S0 DSR will remain on at all times.
  # - &S1 DSR will become active after answer tone has been detected and inactive after the carrier has been lost
  if [[ $hcmd == '&S' ]]; then
    if [[ $hparm == '' ]]; then result=0; fi
    if [[ $hparm == '0' ]]; then result=0; fi
    if [[ $hparm == '1' ]]; then result=0; fi
  fi
}

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
    if [ "$echoser" = "1" ]; then sendtty "\n"; fi

    #
    # --- HAYES EMULATION ---
    #
    if [[ $cmd == AT* ]]; then
      # Attention! Client issued an AT command
      #
      # default to error result code, if command not recognized
      result=4; resultc=0

      if [[ $cmd == AT ]]; then result=0; fi

      # Get full hayes string and parse it
      seq=`echo $cmd |cut -b3-`
      ptr=1
      until [ $ptr -gt 64 ]; do
        hchar=$(echo "$seq" |cut -b$ptr)
        #sendtty "$ptr $hchar\n"
        if [[ $hchar =~ [A-Z\&] ]]; then
          if [[ $hchar == '&' ]]; then
            hcmd="$hchar"
            ptr=$((ptr+1))
            hchar=$(echo "$seq" |cut -b$ptr)
            if [[ $hchar =~ [A-Z] ]]; then
              hcmd="$hcmd$hchar"
              until [ $hdone ]; do
                ptr=$((ptr+1))
                hchar=$(echo "$seq" |cut -b$ptr)
                if [[ $hchar =~ [0-9] ]]; then
                  hparm="$hparm$hchar"
                else
                  ptr=$((ptr-1))
                  hdone=1
                fi
              done
            fi
          elif [[ $hchar =~ [A-CE-Z] ]]; then
            hcmd="$hcmd$hchar"
            until [ $hdone ]; do
              ptr=$((ptr+1))
              hchar=$(echo "$seq" |cut -b$ptr)
              if [[ $hchar =~ [0-9] ]]; then
                hparm="$hparm$hchar"
              else
                ptr=$((ptr-1))
                hdone=1
              fi
            done
          elif [[ $hchar == 'D' ]]; then
            hcmd="$hcmd$hchar"
            until [ $hdone ]; do
              ptr=$((ptr+1))
              hchar=$(echo "$seq" |cut -b$ptr)
              if [[ $hchar =~ [0-9PRT,!] ]]; then
                hparm="$hparm$hchar"
              else
                ptr=$((ptr-1))
                hdone=1
              fi
            done
          fi
        fi
        ptr=$((ptr+1))
        if [[ ! -z "$hcmd" ]]; then
          dohayes
          # preserve error if one was encountered
          if [[ $result == '4' ]]; then resultc='4'; fi
        else
          break
        fi
        hcmd=""
        hparm=""
        hdone=""
      done

      if [[ $resultc == '4' ]]; then result='4'; fi

      # ATD Dial number
      if [[ ! -z "$number" ]]; then
        if [[ $resultverbose == 1 && $ringing == 1 ]]; then sendtty "RINGING\n"; else sendtty "1\n"; fi
        sleep 2
        if [ -f "$number.sh" ]; then
          if [[ $resultverbose == 1 ]]; then sendtty "CONNECT $baud\n"; else sendtty "1\n"; fi
          # Assert DCD when carrier detection is turned on (for Trumpet Winsock)
          if [[ $carrierdetect == 1 ]]; then exec 99>&-; fi

          # Tell the terminal to use CR/LF for newlines instead of just CR.
          echo -en "\x1b[20h" > /dev/$serport

          # Run script
          #/sbin/getty -8 -L $serport $baud $TERM -n -l "./$number.sh"
          ./$number.sh

          if [[ $carrierdetect == 1 ]]; then exec 99<>/dev/$serport; fi

          # Reset serial settings
          ttyinit
          result=3
        else
          # Phone number is valid, but no internal script by that name exists
          result=3
        fi
        number=""
      fi

      #
      # --- PRINT RESULT CODE ---
      #
      if [[ $resultverbose == 0 ]]; then
        sendtty "$result\n";
      elif [[ $resultverbose == 1 ]]; then
        if [[ $result == 0 ]]; then sendtty "OK\n"; fi
        if [[ $result == 1 ]]; then sendtty "CONNECT\n"; fi
        if [[ $result == 2 ]]; then sendtty "RING\n"; fi
        if [[ $result == 3 ]]; then sendtty "NO CARRIER\n"; fi
        if [[ $result == 4 ]]; then sendtty "ERROR\n"; fi
        if [[ $result == 5 ]]; then sendtty "CONNECT 1200\n"; fi
        if [[ $result == 6 ]]; then sendtty "NO DIALTONE\n"; fi
        if [[ $result == 7 ]]; then sendtty "BUSY\n"; fi
        if [[ $result == 8 ]]; then sendtty "NO ANSWER\n"; fi
      fi
    fi

    if [[ $cmd = "HELP" ]] || [[ $cmd = "?" ]]; then
      sendtty "Command Reference for Virtual Modem Bootstrap v$vmodver\n"
      sendtty "\n"
      sendtty "General commands:\n"
      sendtty "HELP.......Display this help\n"
      sendtty "LOGIN......Drop to shell\n"
      sendtty "SETUP......Change settings\n"
      sendtty "EXIT.......End this script\n"
      sendtty "\n"
      sendtty "Common Hayes commands:\n"
      sendtty "AT.........Tests serial connection, prints OK if successful\n"
      sendtty "ATE0/ATE1..Switch terminal echo 0-off or 1-on\n"
      sendtty "ATD#.......Fork #.sh and output on terminal\n"
      sendtty "ATD1.......Fork 1.sh, which by default starts a PPP connection\n"
      sendtty "ATZ........Reset modem settings\n"
      sendtty "\n"
      sendtty "To establish connection over PPP, dial 1 (ATDT1)\n"
      sendtty "\n"
      sendtty "READY.\n"
    fi

    if [[ $cmd = "SETUP" ]]; then
      while true; do
        # Display menu
        sendtty "\n"
        sendtty "System Setup\n"
        sendtty "============\n"
        sendtty "1. Change Wireless Network settings\n"
        sendtty "2. Exit\n"
        sendtty "Enter your selection: "
        # Read user input
        readtty selection

        # Wireless network settings
        if [[ "$selection" == "1" ]]; then
          while true; do
            sendtty "\n"
            sendtty "Wi-Fi Settings\n"
            sendtty "==============\n"
            sendtty "1. Connect to new Wi-Fi network\n"
            sendtty "2. Modify password for current Wi-Fi network\n"
            sendtty "3. Disconnect from current Wi-Fi network\n"
            sendtty "4. Display current Wi-Fi connection status\n"
            sendtty "5. Exit\n"
            sendtty "Enter your selection: "
            # Read user input
            readtty selection
            # Connect to new Wi-Fi network
            if [[ "$selection" == "1" ]]; then
              sendtty "Enter SSID: "
              readtty ssid
              sendtty "Enter password: "
              readtty password
              sudo wpa_cli -i wlan0 remove_network 0
              sudo wpa_cli -i wlan0 add_network
              sudo wpa_cli -i wlan0 set_network 0 ssid "\"$ssid\""
              sudo wpa_cli -i wlan0 set_network 0 psk "\"$password\""
              sudo wpa_cli -i wlan0 select_network 0
              sudo wpa_cli -i wlan0 enable_network 0
            # Modify password for current Wi-Fi network
            elif [[ "$selection" == "2" ]]; then
              sendtty "Enter new password: "
              readtty password
              sudo wpa_cli -i wlan0 set_network 0 psk "\"$password\""
            # Disconnect from current Wi-Fi network
            elif [[ "$selection" == "3" ]]; then
              sendtty "Disconnecting from current Wi-Fi network\n"
              sudo wpa_cli -i wlan0 disable_network 0
            # Display current Wi-Fi connection status
            elif [[ "$selection" == "4" ]]; then
              status=$(sudo wpa_cli -i wlan0 status)
              sendtty "\n"
              sendtty "Wi-fi connection status\n"
              sendtty "=======================\n"
              sendtty "$status"
              sendtty "\n"
            # Exit
            elif [[ "$selection" == "5" ]]; then
              break
            # Invalid selection
            else
              sendtty "Invalid selection. Please try again.\n"
            fi
          done
        # Exit
        elif [[ "$selection" == "2" ]]; then
          sendtty "Exited setup\n"
          sendtty "READY.\n"
          break
        # Invalid selection
        else
          sendtty "Invalid selection. Please try again.\n"
        fi
      done
    fi


    # LOGIN  -  FORK LOGIN SESSION
    if [[ $cmd == LOGIN ]]; then
      exec 99>&-
      /sbin/getty -8 -L $serport $baud $TERM
      ttyinit
      exec 99<>/dev/$serport
      sendtty "\n"; sendtty "READY.\n"
    fi

    # EXIT  -  EXIT SCRIPT
    if [ "$cmd" = "EXIT" ]; then sendtty "OK\n"; continue="1"; fi
  fi
  buffer=$buffer$char
done

#Close serial port
exec 99>&-
