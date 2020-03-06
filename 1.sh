#!/bin/bash
# --------------------------------
# VMODEM - Virtual Modem bootstrap
# --------------------------------
# Oliver Molini 2020 Billy Stoughton II/Lord_NT 2020
#
# Licensed under Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International Public License
# https://creativecommons.org/licenses/by-nc-sa/4.0/
#
# RUN PPPD DAEMON
#
# Note on PPPD settings:
# - Make sure the noauth option is set (instead of auth)
# - Make sure the DNS server is defined (add ms-dns 1.2.3.4)
#
# Variable: lcpidle
# Specifies the idle timeout period in seconds for lcp-echo-interval.
# This is to ensure that pppd will not run indefinitely after sudden
# hangup and will relinquish control back to the vmodem.sh.
#
# Default:    lcpidle=5
#
# Variable: etherp
# specifies the default ethernet port that we will use.
#	
# Default:    etherp=eth0
#
lcpidle=5
etherp=eth0

#
# Trumpet Winsock 3.0 revision D for Windows 3.1
# by default requires a fake login shell.
#
# Windows 95 and 98 will not care for a login shell
# unless specifically told to expect one.
#
printf "\n`uname -sn`****\n"
printf "\nUsername: "; sleep 1
printf "\nPassword: "; sleep 1
printf "\nStarting pppd..."
printf "\nPPP>"
# End of fake login prompt.

#disable stty echo
stty -echo

# Set the kernel to router mode
sysctl -q net.ipv4.ip_forward=1

# Share eth0 over ppp0
iptables -t nat -A POSTROUTING -o $etherp -j MASQUERADE
iptables -t filter -A FORWARD -i ppp0 -o $etherp -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -t filter -A FORWARD -i $etherp -o ppp0 -j ACCEPT

# Run PPP daemon and establish a link.
pppd noauth nodetach local lock lcp-echo-interval $lcpidle lcp-echo-failure 3 proxyarp ms-dns 8.8.8.8 10.0.100.1:10.0.100.2 /dev/$serport $baud

# Flush iptables
iptables -t filter -F FORWARD
iptables -t nat -F POSTROUTING

# enable stty echo
stty echo

printf "\nPPP link terminated.\n"
