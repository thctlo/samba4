#!/bin/bash

##
## Version      : 1.1.0
## release d.d. : 20-12-2017
## Author       : L. van Belle
## E-mail       : louis@van-belle.nl
## Copyright    : Free as free can be, copy it, change it if needed.
## Sidenote     : if you change things, please inform me

# This script checks you setup for the basic settings. 
# 

BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
UNDERLINE=$(tput smul)

error() {
  printf "%40s\n" "${RED}$@${NORMAL}"
}

warning() {
  printf "%40s\n" "${YELLOW}$@${NORMAL}"
}

warning_underline() {
  printf "%40s\n" "${YELLOW}${UNDERLINE}$@${NORMAL}"
}

check_run_as_sudo_root() {
  if ! [[ $EUID -eq 0 ]]; then
    error "This script should be run using sudo or by root."
    exit 1
  fi
}

#
######## LEAVE THESE HERE AND DONT CHANGE THESE 3 !!!!!!
## hostname in single word, but you dont need to change this
SETHOSTNAME=`hostname -s`
## domainname.tld, but if you installed correct, you dont need to change this
SETDNSDOMAIN=`hostname -d`
## hostname.domainname.tld, but if you installed correct, you dont need to change this
SETFQDN=`hostname -f`
## the ip of the server, if you resolv.conf is correctly setup.
SETSERVERIP1=`hostname -i`
SETSERVERIP2=`hostname -I`
if [ "${SETSERVERIP1}" = "${SETSERVERIP2}" ]; then 
    SETSERVERIP="${SETSERVERIP1}"
else
    SETSERVERIP="${SETSERVERIP2}"
fi

##################################################################

## DONT CHANGE BELOW Please

check_run_as_sudo_root

# Added -H now it also works for a member server. ( thanks Roy Eastwood for reporting )
SAMBA_DC_FSMO=$(samba-tool fsmo show -H ldap://${SETDNSDOMAIN} | cut -d"," -f2 | head -n1 | cut -c4-100)
SAMBA_DC_FSMO_SITE=$(samba-tool fsmo show -H ldap://${SETDNSDOMAIN} | cut -d"," -f4 | head -n1 | cut -c4-100)
SAMBA_DC_NC=$(samba-tool fsmo show -H ldap://${SETDNSDOMAIN} | cut -d"," -f7,8,9| head -n1)

## get DC's
DCS=$(host -t SRV _kerberos._udp.${SETDNSDOMAIN} | awk '{print $NF}'| sed 's/.$//')
SAMBA_DC1=$(echo "$DCS" | sed -n 1p)
SAMBA_DC2=$(echo "$DCS" | sed -n 2p)
## get the ip of the DC's
if [ -z "${SAMBA_DC1}" ] && [ -z "${SAMBA_DC2}" ]; then
    echo "Could not obtain an ipaddress for any AD DC.. Exiting"
    exit 1
fi
if [ -z "${SAMBA_DC2}" ]; then
    SAMBA_DC1_IP=$(host -t A ${SAMBA_DC1} | awk '{print $NF}')
    SAMBA_DC2_IP=""
else
    SAMBA_DC1_IP=$(host -t A ${SAMBA_DC1} | awk '{print $NF}')
    SAMBA_DC2_IP=$(host -t A ${SAMBA_DC2} | awk '{print $NF}')
fi


SAMBA_NT_DOMAINNAME=$(samba-tool domain info ${SAMBA_DC1} | grep Netbios | cut -d":" -f2 | cut -c2-100)
SAMBA_KERBEROS_NAME=$(cat /etc/krb5.conf | grep default_realm | cut -d"=" -f2 | cut -c2-100)

#
echo "This script was tested with Debian Jessie and Stretch"
echo "Server info:                    detected           (command and where to look)"
echo "This server hostname          = ${SETHOSTNAME}	(hostname -s and /etc/hosts and DNS server)"
echo "This server FQDN (hostname)   = ${SETFQDN}	(hostname -f and /etc/hosts and DNS server)"
echo "This server primary dnsdomain = ${SETDNSDOMAIN}	(hostname -d and /etc/resolv.conf and DNS server)"
echo "This server IP address(ses)   = ${SETSERVERIP}	(hostname -i (-I) and /etc/networking/interfaces and DNS server"
echo "The DC with FSMO roles        = ${SAMBA_DC_FSMO}	(samba-tool fsmo show)"
echo "The DC (with FSMO) Site name  = ${SAMBA_DC_FSMO_SITE}	(samba-tool fsmo show)"
echo "The Default Naming Context    = ${SAMBA_DC_NC}	(samba-tool fsmo show)"
echo "The Kerberos REALM name used  = ${SAMBA_KERBEROS_NAME}	(kinit and /etc/krb5.conf and resolving)"

if [ -z "${SAMBA_DC2}" ]; then
    SAMBA_DC1_IP=$(host -t A ${SAMBA_DC1} | awk '{print $NF}')
    echo "The IP address of DC ${SAMBA_DC1}        = ${SAMBA_DC1_IP}"
else
    SAMBA_DC1_IP=$(host -t A ${SAMBA_DC1} | awk '{print $NF}')
    SAMBA_DC2_IP=$(host -t A ${SAMBA_DC2} | awk '{print $NF}')
    echo "The IP address of DC ${SAMBA_DC1}        = ${SAMBA_DC1_IP}"
    echo "The IP address of DC ${SAMBA_DC2}        = ${SAMBA_DC2_IP}"
fi
