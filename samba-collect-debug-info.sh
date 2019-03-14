#!/bin/bash

# skippeded 0.2-0.5 mutiple changes.
#
# 0.8, added idmapd.conf, fix samba-tool dns output + other small improvements.
# 
# Few improvements by Rowland Penny.
# small corrections by Louis van Belle.

# This script helps with debugging problems when you report them on the samba list.
# This really helps a lot in finding/helping with problems.
# Dont attacht this in an e-mail the samba list wil strip of, 
# add the content in the mail. 

# the script needs to run as root.
if [ "$EUID" -ne 0 ]
  then echo "Please run as root or with sudo. Exiting now..."
  exit 1
fi


################ Functions


Check_file_exists () {
if [ -e "${1}" ]; then
    {
    echo "Checking file: ${1} "
    cat "${1}"
    echo
    echo "-----------"
    } >> "$LOGFILE"
else
    {
    echo "Warning, ${1} does not exist"
    echo
    echo "-----------"
    }  >> "$LOGFILE"
fi
}

############# Code

LOGFILE="/tmp/samba-debug-info.txt"
CHECK_PACKAGES1="samba|winbind|krb5|smb|acl|attr"
CHECK_PACKAGES2="krb5|acl|attr"
ADDC=0
UDM=0

echo "Please wait, collecting debug info."

echo "Collected config  --- $(date +%Y-%m-%d-%H:%M) -----------" > $LOGFILE
echo >> $LOGFILE

HOSTNAME="$(hostname -s)" 
DOMAIN="$(hostname -d)"
FQDN="$(hostname -f)"
IP="$(hostname -I)"

{
echo "Hostname: ${HOSTNAME}"
echo "DNS Domain: ${DOMAIN}"
echo "FQDN: ${FQDN}"
echo "ipaddress: ${IP}"
echo
echo "-----------"
} >> $LOGFILE

RUNNING=$(pgrep -xl 'samba|smbd|nmbd|winbindd')
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

    if [ "$SM" = "yes" ] && [ "$WB" = "no" ]; then
	{
        echo "Samba is running as an AD DC"
        echo "'winbindd' is NOT running."
        echo "Check that the winbind package is installed."
	}  >> $LOGFILE
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
echo >> $LOGFILE
Check_file_exists /etc/debian_version
# if this is Debian, no need to check for Devuan.
if [ "$?" != "0" ]; then
    # It isn't Debian, is it Devuan ?
    Check_file_exists /etc/devuan_version
    # TODO: add ubuntu checks
    if [ "$?" != "0" ]; then
        echo "This computer is not running either Devuan or Debian"
        echo "This computer is not running either Devuan or Debian" >> $LOGFILE
        echo "Cannot Continue...Exiting."
        echo "Cannot Continue...Exiting." >> $LOGFILE
        exit 1
    fi
fi


{
# running ipnumbers
echo "running command : ip a"
ip a | grep -v forever
echo "-----------"
} >> $LOGFILE

Check_file_exists /etc/hosts
Check_file_exists /etc/resolv.conf
Check_file_exists /etc/krb5.conf
Check_file_exists /etc/nsswitch.conf
Check_file_exists /etc/idmapd.conf
Check_file_exists "${SMBCONF}"


USERMAP="$(grep "username map" "${SMBCONF}" | awk '{print $NF }')"
# auto..
if [ -n "${DC}" ]; then
    SERVER_ROLE="$(samba-tool testparm -v --suppress-prompt | grep "server role"| cut -d"=" -f2)"
else
    SERVER_ROLE="$(testparm -v -s | grep "server role"| cut -d"=" -f2)"
fi


if [ -n "${USERMAP}" ]; then
    if [ "$UDM" = "1" ]; then
        {
         echo "Content of $USERMAP"
         cat "$USERMAP"
         echo
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
    echo "No username map detected."
    echo
    echo "-----------"
    } >> $LOGFILE
fi

if [ "$ADDC" = "1" ]; then
    found=0
    # check for bind9_dlz
    if [ "$(grep -c "\-dns" "${SMBCONF}")" -eq "1" ] || [ "$(grep "server services" "${SMBCONF}" | grep -wc 'dns')" -eq "0" ]; then
        echo "Detected bind DLZ enabled.." >> $LOGFILE
        if [ -d /etc/bind ]; then

            Check_file_exists "/etc/bind/named.conf"
            Check_file_exists "/etc/bind/named.conf.options"
            Check_file_exists "/etc/bind/named.conf.local"
            Check_file_exists "/etc/bind/named.conf.default-zones"
            echo "Samba DNS zone list: " >> $LOGFILE
            samba-tool dns zonelist ${FQDN} -k yes -P >> $LOGFILE
            echo  >> $LOGFILE
            echo "Samba DNS zone list Automated check : " >> $LOGFILE
            zonelist="$(samba-tool dns zonelist ${FQDN} -k yes -P)"
            zones="$(echo "${zonelist}" | grep '[p]szZoneName' | awk '{print $NF}' | tr '\n' ' ')"
            while read -r -d ' ' zone
            do
              zonetest=$(grep -r "${zone}" /etc/bind)
              if [ -n "${zonetest}" ]; then
                  found=$((found + 1))
              fi
            done <<< "${zones}"
            if [ "${found}" -gt 0 ]; then
                {
                echo
                echo "ERRROR: AD DC zones found in the Bind flat-files"
                echo "This is not allowed, you must remove them."
                echo
                echo "-----------"
                } >> $LOGFILE
            fi
        else
            {
            echo
            echo "Warning, detected bind enabled in smb.conf, but no /etc/bind directory found"
            echo " "
            echo "-----------"
            } >> $LOGFILE
        fi
    fi
fi


# Where is the 'smbd' binary ?
SBINDIR="$(smbd -b | grep 'SBINDIR'  | awk '{ print $NF }')"
if [ "${SBINDIR}" = "/usr/sbin" ]; then
   {
    echo
    echo "Installed packages, running: dpkg -l | egrep \"$CHECK_PACKAGES1\""
    dpkg -l | egrep "$CHECK_PACKAGES1"
    echo "-----------"
   } >> $LOGFILE
else
   {
    echo "Self compiled Samba installed."
    echo "Installed packages, running: dpkg -l | egrep \"$CHECK_PACKAGES2\""
    dpkg -l | egrep "$CHECK_PACKAGES2"
    echo "-----------"
   } >> $LOGFILE
fi

echo "The debug info about your system can be found in this file: $LOGFILE"
echo "Please check this and if required, sanitise it."
echo "Then copy & paste it into an  email to the samba list"
echo "Do not attach it to the email, the Samba mailing list strips attachments."

exit 0
