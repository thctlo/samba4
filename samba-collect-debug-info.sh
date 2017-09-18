#!/bin/bash

# Version 0.1
# 

set -e

# This script helps with debugging problems when you report them on the samba list.
# This really helps a lot in finding/helping with problems.

################ Functions

Check_file_exists () {
if [ -e "${1}" ]; then
    {
    echo "Checking file: ${1} "
    cat "${1}"
    echo " "
    echo "-----------"
    } >> $LOGFILE
else
    {
    echo "Warning, ${1} does not exist"
    echo "-----------"
    }  >> $LOGFILE
fi
}

############# Code

LOGFILE="/tmp/samba-debug-info.txt"
CHECK_PACKAGES="samba|winbind|krb5|smb|acl|xattr"
ADDC=0
UDM=0

echo "Please wait, collecting debug info."

echo "Collected config  --- $(date +%Y-%m-%d-%H:%m) -----------" > $LOGFILE
echo " " >> $LOGFILE

RUNNING=$(ps xc | grep -E 'samba|smbd|nmbd|winbind')
DC="no"
NM="no"
SM="no"
WB="no"
[[ "${RUNNING}" == *"samba"* ]] && DC="yes"
[[ "${RUNNING}" == *"nmbd"* ]] && NM="yes"
[[ "${RUNNING}" == *"smbd"* ]] && SM="yes"
[[ "${RUNNING}" == *"winbind"* ]] && WB="yes"

if [ "$DC" = "yes" ]; then
    if [ "$NM" = "yes" ]; then
        echo "You are running Samba as DC, but nmbd is also running" >> $LOGFILE
        echo "This is not allowed, please stop 'nmbd' from running" >> $LOGFILE
    fi

    if [ "$SM" = "yes" ] && [ "$WB" = "yes" ]; then
        echo "Samba is running as an AD DC" >> $LOGFILE
        ROLE="ADDC"
        ADDC=1
        SMBCONF=$(samba -b | grep 'CONFIGFILE' | awk '{print $NF}')
    fi
else
    if [ "$SM" = "yes" ] && [ "$NM" = "yes" ] && [ "$WB" = "yes" ]; then
        ROLE=$(testparm -s --parameter-name='security' 2>/dev/null)
        ROLE="${ROLE^^}"
        if [ "$ROLE" = "ADS" ]; then
            echo "Samba is running as a Unix domain member" >> $LOGFILE
            UDM=1
            SMBCONF=$(smbd -b | grep 'CONFIGFILE' | awk '{print $NF}')
        fi
    fi
fi

if [ "$ADDC" = "0" ] && [ "$UDM" = "0" ]; then
    echo "Samba is not being run as a DC or a Unix domain member." >> $LOGFILE
fi

Check_file_exists /etc/os-release
echo " " >> $LOGFILE
# This is a bit of a chicken & egg situation
# How to check if running on Debian or Devuan
# without knowing if you are running on Debian or Devuan ????
Check_file_exists /etc/debian_version
Check_file_exists /etc/devuan_version
{

# running ipnumbers
echo " "
echo "running command : ip a" >> $LOGFILE
ip a | grep -v forever >> $LOGFILE
echo "-----------" >> $LOGFILE
} >> $LOGFILE

Check_file_exists /etc/hosts
Check_file_exists /etc/krb5.conf
Check_file_exists /etc/nsswitch.conf
Check_file_exists "${SMBCONF}"

USERMAP="$(grep "username map" ${SMBCONF} | awk '{print $NF }')"
# auto..
if [ -n "$DC" ]; then
    SERVER_ROLE="$(samba-tool testparm -v --suppress-prompt | grep "server role"| cut -d"=" -f2)"
else
    SERVER_ROLE="$(testparm -v -s | grep "server role"| cut -d"=" -f2)"
fi

if [ -n "${USERMAP}" ]; then
    if [ "$UDM" = "1" ]; then
        {
         echo "Content of $USERMAP"
         cat "$USERMAP"
         echo " "
         if [ "${SERVER_ROLE}" = "auto" ]; then
             echo "Server Role is set to : $SERVER_ROLE"
         fi
         echo "-----------"
         } >> $LOGFILE
    else
         {
         if [ "$ADDC" = "1" ]; then
             echo "You have a user.map set in your smb.conf"
             echo "Samba is running as a DC"
         fi
         echo "-----------"
         } >> $LOGFILE
    fi
else
    {
    echo "No username map was detected."
    echo " "
    echo "-----------"
    } >> $LOGFILE
fi

if [ "$ADDC" = "1" ]; then
    # check for bind9_dlz
    if [ "$(grep -c "\-dns" "${SMBCONF}")" -eq "1" ] || [ "$(grep "server services" "${SMBCONF}" | grep -wc 'dns')" -eq "0" ]; then
        echo "Detected bind DLZ enabled.." >> $LOGFILE
        if [ -d /etc/bind ]; then
            Check_file_exists "/etc/bind/named.conf"
            Check_file_exists "/etc/bind/named.conf.options"
            Check_file_exists "/etc/bind/named.conf.local"
            Check_file_exists "/etc/bind/named.conf.default-zones"
            echo "-----------" >> $LOGFILE
        else
            {
            echo " "
            echo "Warning, detected bind enabled in smb.conf, but no /etc/bind directory found"
            echo "-----------"
            } >> $LOGFILE
        fi

        # named-checkconf -z, shows output of bind9_flatfiles
        # Todo: Add check if no bind9_flatefiles zones are samba-ad zones.

        # This isn't going to be easy
        # named-checkconf -z produces this:
        # zone localhost/IN: loaded serial 2
        # zone 127.in-addr.arpa/IN: loaded serial 1
        # zone 0.in-addr.arpa/IN: loaded serial 1
        # zone 255.in-addr.arpa/IN: loaded serial 1

        # I have these in dlz-zones:
        # 0.168.192.in-addr.arpa
        # samdom.example.com
        # _msdcs.samdom.example.com

        # 'samba-tool dns zonelist' will show the dlz-zones
        # but will need a username & password
        # and will the zones show if they are in flatfiles ???

    fi
fi

{
echo " "
echo "Installed packages, running: dpkg -l | egrep \"$CHECK_PACKAGES\""
dpkg -l | egrep "$CHECK_PACKAGES"
        echo "-----------"
} >> $LOGFILE

echo "The debug info about your system can be found in this file: $LOGFILE"
echo "Please check this and if required, sanitise it."
echo "Then copy & paste it into an  email to the samba list"

