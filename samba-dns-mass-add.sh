#!/bin/bash

# This tool is used to mass add dns records.
# it works, but no error checking is done. 

# Info: https://wiki.samba.org/index.php/DNS_Administration 
# 
# It wil create a hostname-nr A and PTR records. 
# If needed it creates you reverse zone also. 


###############################################################
## hostname in single word, but you dont need to change this
SETHOSTNAME=`hostname -s`
## domainname.tld, but if you installed correct, you dont need to change this
SETDNSDOMAIN=`hostname -d`
## hostname.domainname.tld, but if you installed correct, you dont need to change this
SETFQDN=`hostname -f`
###############################################################


SETTPUT=`which tput`
if [ -z ${SETTPUT} ]; then
    echo "program tput not found, installing it now.. please wait"
    apt-get update > /dev/null
    apt-get install -y --no-install-recommends ncurses-bin > /dev/null
fi

RED=$(${SETTPUT} setaf 1)
NORMAL=$(${SETTPUT} sgr0)
GREEN=$(${SETTPUT} setaf 2)
YELLOW=$(${SETTPUT} setaf 3)
UNDERLINE=$(${SETTPUT} smul)
WHITE=$(${SETTPUT} setaf 7)
BOLD=$(${SETTPUT} bold)

message() {
  printf "%40s\n" "${WHITE}${BOLD}$@${NORMAL}"
}
good() {
  printf "%40s\n" "${GREEN}$@${NORMAL}"
}
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
configured_script() {
    if [ "${CONFIGURED}" = "no" ]; then
        error "####################################################"
        error "You need to configure this script first to run it. "
        echo " "
        error "exiting script now... "
        exit 0
    fi
}

configured_script
check_run_as_sudo_root

DOWNCOUNTER=1
UPCONTER=1

echo "Tool for createing lots DNS records"
echo "A few questions"
read -p "What is the name of the dns zone to add to ( example: $SETDNSDOMAIN ) : " SET_INPUT_ZONE
read -p "What is the IP range ( example : $(ip route|grep -v default | cut -d"/" -f1) ) : " SET_INPUT_IP_RANGE
read -p "What is the hostname without numbers ( example input : printer ) results in printer-NR : " SET_INPUT_PREHOSTNAME
read -p "Enter the start IP 1-254: " DOWNCOUNTER
UPCOUNTER=$(( $DOWNCOUNTER +1 ))
read -p "Enter the end IP ${UPCOUNTER}-254: " UPCOUNTER
read -p "Enable PTR ( type: yes or no ) : " SET_PTR


if [ $DOWNCOUNTER -ge $UPCOUNTER ]; then
    echo "error, your start is higher or equal then the end ip"
    exit 0
fi

## get DC's
DCS=$(host -t SRV _kerberos._udp.${SETDNSDOMAIN} | awk '{print $NF}')
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
SAMBA_NT_ADMIN_USER="Administrator"
SAMBA_NT_ADMIN_PASS=""

if [ -z "${SAMBA_NT_ADMIN_PASS}" ]; then
    while [ "${SAMBA_NT_ADMIN_PASS}" = "" ]; do
        read -s -e -p "Please enter the password for ${SAMBA_NT_DOMAINNAME}\Administrator : " SAMBA_NT_ADMIN_PASS
    done
fi

echo ${SAMBA_NT_ADMIN_PASS} | kinit Administrator

REVERSEZONE=$(echo $SET_INPUT_IP_RANGE | awk 'BEGIN { FS = "." } ; { print $3"."$2"."$1}')
IPRANGE3=$(echo $SET_INPUT_IP_RANGE | awk 'BEGIN { FS = "." } ; { print $1"."$2"."$3}')


UPCOUNTER=$(( $UPCOUNTER +1 ))
until [ $DOWNCOUNTER -eq $UPCOUNTER ];
    do
        echo -n "Adding IP ${IPRANGE3}.${DOWNCOUNTER} : "
        samba-tool dns add ${SAMBA_DC1} ${SET_INPUT_ZONE} ${SET_INPUT_PREHOSTNAME}-${DOWNCOUNTER} A ${IPRANGE3}.${DOWNCOUNTER} -k
        sleep 0.5
        if [ "${SET_PTR}" = "yes" ]; then
			echo -n "Trying to create the reverse zone"
			samba-tool zonecreate add ${SAMBA_DC1} ${REVERSEZONE}.in-addr.arpa -k
            echo -n "Adding PTR  ${SET_INPUT_PREHOSTNAME}-${DOWNCOUNTER}.${SET_INPUT_ZONE} : "
            samba-tool dns add ${SAMBA_DC1} ${REVERSEZONE}.in-addr.arpa ${DOWNCOUNTER} PTR ${SET_INPUT_PREHOSTNAME}-${DOWNCOUNTER}.${SET_INPUT_ZONE} -k
            sleep 0.5
        fi
    DOWNCOUNTER=$(( $DOWNCOUNTER +1 ))
    done

unset SAMBA_NT_ADMIN_PASS
kdestroy
