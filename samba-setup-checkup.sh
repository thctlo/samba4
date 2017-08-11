#!/bin/bash

# This script is use to get system info so we can use this to make an ultimate checkup script.
Version=0.001


#
# If new things are added, create 3 functions.
# function get_, get info
# function check_, run the checkup againt the info (get_) and (show_) output.
# function show_, show info

# try to keep the functions clear.
# get_host_  : involves only host related info, like hostnames and ipnumbers and resolving.
# get_samba_ : involves only samba related info,
# get_etc_   : involves only configuration files
# Note!
# for example : get_etc_samba_smbconf should not be get_samba_etc_smbconf
# get_samba_ should only show output of a running samba and test.
# like get_samba_fsmo


# ToDo 1: Get all system info and show system info.


# set some colors to outline Ok Warn en errors more.
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

function good {
#  printf "%40s\n" "${GREEN}$@${NORMAL}"
  printf "${GREEN}$@${NORMAL}\n"
}

function error {
  printf "${RED}$@${NORMAL}\n"
}

function warning {
  printf "${YELLOW}$@${NORMAL}\n"
}

function warning_underline {
  printf "%40s\n" "${YELLOW}${UNDERLINE}$@${NORMAL}"
}

function check_run_as_sudo_root {
  if ! [[ $EUID -eq 0 ]]; then
    error "This script should be run using sudo or by root."
    exit 1
  fi
}

function check_error {
    if [ $? -eq 0 ]; then
        good "Ok"
    elif [ $? -ge 1 ]; then
        error "Error"
    fi
}

function check_etc_hosts {
    # count lines with the servers hostname
    CHECK_ETC_HOSTS1=$(cat /etc/hosts | grep $HOST_NAME_SHORT | wc -l )
    # count lines with the servers hostname and detected ipnumber
    CHECK_ETC_HOSTS2=$(cat /etc/hosts | grep $HOST_NAME_SHORT | grep $HOST_IP| wc -l )
    # check if FQDN is in position 2 in the detected line.
    CHECK_ETC_HOSTS3=$(cat /etc/hosts | grep $HOST_NAME_SHORT | grep $HOST_IP| cut -d" " -f2)
    # check if host does not contain 127.0.1.1 due to dhcp IPnumber at OS install.
    CHECK_ETC_HOSTS_LOCALHOST1=$(cat /etc/hosts | grep $HOST_NAME_SHORT | grep 127.0.1.1 | wc -l )
    if [ $CHECK_ETC_HOSTS_LOCALHOST1 -eq 1 ]; then
        warning "Detected ip withing localhost range, asuming server install with DHCP enabled."
        warning "You /etc/hosts contains : $HOST_NAME_SHORT and/or $HOST_NAME_FQDN with ip 127.0.1.1"
        warning "expected was : $HOST_IP $HOST_NAME_FQDN $HOST_NAME_SHORT"
        # the next check show what we expect to have.
    fi
    if [ $CHECK_ETC_HOSTS1 -eq $CHECK_ETC_HOSTS2 ]; then
        if [ $CHECK_ETC_HOSTS3 != $HOST_NAME_FQDN ]; then
            error "Possible error detected in /etc/hosts, mismatch FQDN and detected IP $HOST_IP for the host."
            warning "expected was : $HOST_IP $HOST_NAME_FQDN $HOST_NAME_SHORT"
        fi
    fi
}

function get_host_info {
    # Get all info of the server.
    # short hostname (single word)
    HOST_NAME_SHORT="$(hostname -s)"
    # the domainname of the host (something.example.com)
    HOST_NAME_DOMAIN="$(hostname -d)"
    # Fully Qualified hostname
    HOST_NAME_FQDN="$(hostname -f)"

    # the server ipnumbers, check for multiple interfaces.
    HOST_IP1="$(hostname -i)"
    HOST_IP2="$(hostname -I)"
    HOST_GATEWAY=$(ip route | grep default | cut -d" " -f3)

    if [ $HOST_IP1 = $HOST_IP2 ]; then
        HOST_IP="${HOST_IP1}"
        HOST_PRIMARY_INTERFACE="$(ip route | grep ${HOST_IP} | cut -d" " -f3)"
        HOST_IP2="Only one interface detected"
    else
        echo "TODO, not finished"
        echo "Detected multiple ipnumbers"
        # multiple ipnumbers detected, get primary interfaces
        HOST_PRIMARY_INTERFACE="$(ip route | grep ${HOST_IP} | cut -d" " -f3)"
        # set ipadres of primary interface.
        HOST_IP=
        # check if primary ip adres is in range 10. 172.16. 192.168.
    fi

    # Resolv.conf info.
    HOST_RESOLV_DOMAIN="$(cat /etc/resolv.conf | grep domain)"
    HOST_RESOLV_SEARCH="$(cat /etc/resolv.conf | grep search)"

    # count nameservers
    HOST_RESOLV_NAMESERV_COUNTER=$(cat /etc/resolv.conf | grep nameserver| wc -l)
    if [ $HOST_RESOLV_NAMESERV_COUNTER -eq 1 ]; then
        HOST_RESOLV_NAMESERV1="$(cat /etc/resolv.conf | grep nameserver| head -n1 | cut -d" " -f2)"
        HOST_
    fi
    if [ $HOST_RESOLV_NAMESERV_COUNTER -eq 2 ]; then
        HOST_RESOLV_NAMESERV1="$(cat /etc/resolv.conf | grep nameserver| head -n1 | cut -d" " -f2)"
        HOST_RESOLV_NAMESERV2="$(cat /etc/resolv.conf | grep nameserver| tail -n1 | cut -d" " -f2)"
    fi

    if [ $HOST_RESOLV_NAMESERV_COUNTER -eq 3 ]; then
        HOST_RESOLV_NAMESERV3="$(cat /etc/resolv.conf | grep nameserver| tail -n1 | cut -d" " -f2)"
    else
        HOST_RESOLV_NAMESERV3=""
    fi
}

function show_host_info {
    echo "HOST_NAME_SHORT: ${HOST_NAME_SHORT}"
    # the domainname of the host (something.example.com)
    echo "HOST_NAME_DOMAIN: ${HOST_NAME_DOMAIN}"
    # Fully Qualified hostname
    echo "HOST_NAME_FQDN: ${HOST_NAME_FQDN}"

    # the server ipnumbers, check for multiple interfaces.
    echo "HOST_IP1: ${HOST_IP1}"
    echo "HOST_IP2: ${HOST_IP2}"
    echo "HOST_GATEWAY: ${HOST_GATEWAY}"
    echo "HOST_PRIMARY_INTERFACE: ${HOST_PRIMARY_INTERFACE}"

    # Resolv.conf info.
    echo "HOST_RESOLV_DOMAIN: ${HOST_RESOLV_DOMAIN}"
    echo "HOST_RESOLV_SEARCH: ${HOST_RESOLV_SEARCH}"

    # nameservers
    #echo "HOST_RESOLV_NAMESERV_COUNTER: ${HOST_RESOLV_NAMESERV_COUNTER}"
    echo "HOST_RESOLV_NAMESERV1: ${HOST_RESOLV_NAMESERV1}"
    echo "HOST_RESOLV_NAMESERV2: ${HOST_RESOLV_NAMESERV2}"
    echo "HOST_RESOLV_NAMESERV3: ${HOST_RESOLV_NAMESERV3}"

}

function check_host_info {
    get_host_info
    # check if hostname setup is correct.
    local HOSTNAME_SHORT_WITH_DOMAIN="$HOST_NAME_SHORT.${HOST_NAME_DOMAIN}"
    echo -n "Check hostnames : "
    if [ $HOSTNAME_SHORT_WITH_DOMAIN = $HOST_NAME_FQDN ]; then
        good "Ok"
    else
        warning "Mismatch in hostname definitions"
        echo "please check : "
        show_host_info
    fi
    unset HOSTNAME_SHORT_WITH_DOMAIN

    check_etc_hosts

    echo "Checking detected host ipnumbers from resolv.conf and default gateway"
    check_host_ip
}

function check_host_ip {
    # check resolving and check for internet.
    if [ ! -z ${HOST_GATEWAY} ]; then
        echo -n "Ping gateway ip : "
        check_ping ${HOST_GATEWAY}
    fi
    if [ ! -z ${HOST_RESOLV_NAMESERV1} ]; then
        echo -n "ping nameserver1: "
        check_ping ${HOST_RESOLV_NAMESERV1}
    fi
    if [ ! -z ${HOST_RESOLV_NAMESERV2} ]; then
        echo -n "ping nameserver2: "
        check_ping ${HOST_RESOLV_NAMESERV2}
    fi
    if [ ! -z ${HOST_RESOLV_NAMESERV3} ]; then
        echo -n "ping nameserver3: "
        check_ping ${HOST_RESOLV_NAMESERV3}
    fi
    echo -n "Check ping google dns : "
    check_ping 8.8.8.8
}

function check_ping {
    echo -n "$1 : "
    ping -q -c1 $1 >/dev/null
    check_error
}

function get_samba_base_info {
    SAMBA_SERVER_ROLE="$(samba-tool testparm --parameter-name="server role"  2>/dev/null | tail -1)"
    SAMBA_SERVER_SERVICES="$(samba-tool testparm --parameter-name="server services"  2>/dev/null | tail -1)"
    SAMBA_DCERPC_ENDPOINT_SERVERS="$(samba-tool testparm --parameter-name="dcerpc endpoint servers"  2>/dev/null | tail -1)"
}
function show_samba_base_info {
    echo "SAMBA_SERVER_ROLE: ${SAMBA_SERVER_ROLE}"
    echo "SAMBA_SERVER_SERVICES: ${SAMBA_SERVER_SERVICES}"
    echo "SAMBA_DCERPC_ENDPOINT_SERVERS: ${SAMBA_DCERPC_ENDPOINT_SERVERS}"
}
function check_samba_base_info {
    echo "check_samba_base_info TODO"
}

function get_samba_fsmo {
    SAMBA_DC_FSMO=$(samba-tool fsmo show | cut -d"," -f2 | head -n1 | cut -c4-100)
    SAMBA_DC_FSMO_SITE=$(samba-tool fsmo show | cut -d"," -f4 | head -n1 | cut -c4-100)
    SAMBA_DC_NC=$(samba-tool fsmo show | cut -d"," -f7,8,9 | head -n1)

    ## detect multiple DC's if there are more.
    SAMBA_DCS=$(host -t SRV _kerberos._udp.${SETDNSDOMAIN} | awk '{print $NF}'| sed 's/.$//')
    SAMBA_DC1=$(echo "$SAMBA_DCS" | sed -n 1p)
    SAMBA_DC2=$(echo "$SAMBA_DCS" | sed -n 2p)
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

    echo "Samba AD DC info:             =  detected         (command and where to look)"
    echo "This server hostname          = ${SETHOSTNAME}    (hostname -s and /etc/hosts and DNS server)"
    echo "This server FQDN (hostname)   = ${SETFQDN}        (hostname -f and /etc/hosts and DNS server)"
    echo "This server primary dnsdomain = ${SETDNSDOMAIN}   (hostname -d and /etc/resolv.conf and DNS server)"
    echo "This server IP address(ses)   = ${SETSERVERIP}    (hostname -i (-I) and /etc/networking/interfaces and DNS server"
    echo "The DC with FSMO roles        = ${SAMBA_DC_FSMO}  (samba-tool fsmo show)"
    echo "The DC (with FSMO) Site name  = ${SAMBA_DC_FSMO_SITE}     (samba-tool fsmo show)"
    echo "The Default Naming Context    = ${SAMBA_DC_NC}    (samba-tool fsmo show)"
    echo "The Kerberos REALM name used  = ${SAMBA_KERBEROS_NAME}    (kinit and /etc/krb5.conf and resolving)"

    if [ -z "${SAMBA_DC2}" ]; then
        SAMBA_DC1_IP=$(host -t A ${SAMBA_DC1} | awk '{print $NF}')
        echo "The Ipadres of DC ${SAMBA_DC1}        = ${SAMBA_DC1_IP}"
    else
        SAMBA_DC1_IP=$(host -t A ${SAMBA_DC1} | awk '{print $NF}')
        SAMBA_DC2_IP=$(host -t A ${SAMBA_DC2} | awk '{print $NF}')
        echo "The Ipadres of DC ${SAMBA_DC1}        = ${SAMBA_DC1_IP}"
        echo "The Ipadres of DC ${SAMBA_DC2}        = ${SAMBA_DC2_IP}"
    fi
}


# check host info, show when errors are found.
check_host_info
