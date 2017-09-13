#!/bin/bash

set -e

# This script helps with debugging problems when you report them on the samba list.
# This really helps a lot in finding/helping with problems.

LOGFILE="/tmp/samba-debug-info.txt"
CHECK_PACKAGES="samba|winbind|krb5|smb|acl|xattr"

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
echo "Please wait, collecting debug info."

if [ ! -e /etc/debian_version ]; then 
    echo "Sorry, this script was tested on Debian only"
    exit 1 
fi

echo "Collected config  --- $(date +%Y-%m-%d-%H:%m) -----------" > $LOGFILE
echo " " >> $LOGFILE
Check_file_exists /etc/os-release
echo " " >> $LOGFILE
Check_file_exists /etc/debian_version
{

# running ipnumbers
echo " "
echo "running command : ip a"
ip a | grep -v forever
echo "-----------"
#
} >> $LOGFILE

Check_file_exists /etc/hosts
Check_file_exists /etc/krb5.conf
Check_file_exists /etc/nsswitch.conf
Check_file_exists /etc/samba/smb.conf

USERMAP="$(grep "username map" /etc/samba/smb.conf | awk '{print $NF }')"
# auto..
SERVER_ROLE="$(echo "\n" | samba-tool testparm -v | grep "server role"| cut -d"=" -f2)"

if [ ! -z "${USERMAP}" ]; then
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
    echo "Content of $USERMAP"
    echo "No username map was detected."
    echo " "
    echo "-----------"
    } >> $LOGFILE
fi

# check for bind9_dlz
if [ "$(grep -c "\-dns" /etc/samba/smb.conf)" -eq "1" ]; then

    echo "Detected bind DLZ enabled.." >> $LOGFILE
    if [ -d /etc/bind ]; then
        Check_file_exist "/etc/bind/named.conf"
        Check_file_exist "/etc/bind/named.conf.options"
        Check_file_exist "/etc/bind/named.conf.local"
        Check_file_exist "/etc/bind/named.conf.default-zones"
        echo "-----------" >> $LOGFILE
    else
        {
        echo " "
        echo "Warning, detected bind enabled in smb.conf, but no /etc/bind found"
        echo "-----------"
        } >> $LOGFILE
    fi

    # named-checkconf -z, shows output of bind9_flatfiles
    # Todo: Add check if no bind9_flatefiles zones are samba-ad zones.

fi
{
echo " "
echo "Installed packages, running: dpkg -l | egrep \"$CHECK_PACKAGES\""
dpkg -l | egrep "$CHECK_PACKAGES"
        echo "-----------"
} >> $LOGFILE

echo "The file with the debug info about your systems can be found here: $LOGFILE"
echo "Please include this in the email to the samba list"
