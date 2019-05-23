#!/bin/bash

# d.d. 23 may 2019
# 0.20   Added better bind detection, missed the packages.
# 		 
#
# Created and maintained by Rowland Penny and Louis van Belle.
# questions, ask them in the samba list. 

# This script helps with debugging problems when you report them on the samba list.
# This really helps a lot in finding/helping with problems.
# Dont attacht this in an e-mail the samba list wil strip of,
# add the content in the mail.

# the script needs to run as root.
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo. Exiting now..."
    exit 1
fi

# Initialize the Adminsitrator
kinit Administrator

if [ "$?" -ge 1 ]; then
     echo "Wrong password, exiting now. "
     exit 1
fi
################ Functions


Check_file_exists () {
if [ -e "${1}" ]; then
    local FILE="$(cat "${1}")"
    cat <<EOF >> "$LOGFILE"
       Checking file: ${1}

${FILE}

-----------

EOF
else
    cat <<EOF >> "$LOGFILE"
    Warning, ${1} does not exist

-----------

EOF
fi
}

############# Code

LOGFILE="/tmp/samba-debug-info.txt"
CHECK_PACKAGES1="samba|winbind|krb5|smbclient|acl|attr"
ADDC=0
UDM=0

echo "Please wait, collecting debug info."

echo "Collected config  --- $(date +%Y-%m-%d-%H:%M) -----------" > $LOGFILE
echo >> $LOGFILE

HOSTNAME="$(hostname -s)"
DOMAIN="$(hostname -d)"
FQDN="$(hostname -f)"
IP="$(hostname -I)"

cat >> "$LOGFILE" <<EOF
Hostname: ${HOSTNAME}
DNS Domain: ${DOMAIN}
FQDN: ${FQDN}
ipaddress: ${IP}

-----------

EOF

DCOUNT=0
for deamon in samba smbd nmbd winbindd
do
  pgrep -xl $deamon > /dev/null 2>&1
  ret="$?"
  case $ret in
     1) continue
       ;;
     0) [[ $deamon == samba ]] && DCOUNT=$((DCOUNT+1))
        [[ $deamon == smbd ]] && DCOUNT=$((DCOUNT+2))
        [[ $deamon == nmbd ]] && DCOUNT=$((DCOUNT+3))
        [[ $deamon == winbindd ]] && DCOUNT=$((DCOUNT+5))
       ;;
  esac
done

case $DCOUNT in
    0) cat >> "$LOGFILE" <<EOF
Samba is not being run as a DC or a Unix domain member.

-----------
EOF
      ;;
    1) cat >> "$LOGFILE" <<EOF
Samba is being run as a DC, but neither the smbd or winbindd deamons or running.

-----------
EOF
      ;;
    2) cat >> "$LOGFILE" <<EOF
Only the smbd deamon is running.

-----------
EOF
      ;;
    3) cat >> "$LOGFILE" <<EOF
Samba is running as an AD DC but 'winbindd' is NOT running.
Check that the winbind package is installed.
EOF
      ROLE="ADDC"
      ADDC=1
      SMBCONF=$(samba -b | grep 'CONFIGFILE' | awk '{print $NF}')
      ;;
    5) ROLE=$(testparm -s --parameter-name='security' 2>/dev/null)
       ROLE="${ROLE^^}"
       if [ "$ROLE" = "ADS" ]; then
           cat >> "$LOGFILE" <<EOF
Samba is running as an Unix domain member but 'winbindd' is NOT running.
Check that the winbind package is installed.
EOF
           UDM=1
           if [ -f /usr/sbin/smbd ]
           then
                SMBCONF=$(smbd -b | grep 'CONFIGFILE' | awk '{print $NF}')
            elif [ -f $(which wbinfo) ]
              then
                if [ -e /etc/samba/smb.conf ]
                then
                    echo "Detected, Samba is running winbind only. Auth-only server, Unix domain member" >> $LOGFILE
                    SMBCONF=/etc/samba/smb.conf
                fi
           fi
       fi
      ;;
    7) ROLE=$(testparm -s --parameter-name='security' 2>/dev/null)
       ROLE="${ROLE^^}"
       if [ "$ROLE" = "ADS" ]; then
           echo "Samba is running as a Unix domain member" >> $LOGFILE
           UDM=1
           SMBCONF=$(smbd -b | grep 'CONFIGFILE' | awk '{print $NF}')
       fi
      ;;
    8) cat >> "$LOGFILE" <<EOF
Samba is running as an AD DC

-----------
EOF
       ROLE="ADDC"
       ADDC=1
       SMBCONF=$(samba -b | grep 'CONFIGFILE' | awk '{print $NF}')
      ;;
   10) ROLE=$(testparm -s --parameter-name='security' 2>/dev/null)
       ROLE="${ROLE^^}"
       if [ "$ROLE" = "ADS" ]; then
           cat >> "$LOGFILE" <<EOF
Samba is running as a Unix domain member

-----------
EOF
           UDM=1
           SMBCONF=$(smbd -b | grep 'CONFIGFILE' | awk '{print $NF}')
       fi
      ;;
   11) cat >> "$LOGFILE" <<EOF
You are running Samba as DC, but nmbd is also running
This is not allowed, please stop 'nmbd' from running
EOF
      ;;
esac

Check_file_exists /etc/os-release
echo >> $LOGFILE
# Check for OS, Devuan, Debian, Ubuntu or other
OS=$(uname -s)
ARCH=$(uname -m)
if [ "${OS}" = "Linux" ] ; then
    if [ -f /etc/devuan_version ]; then
        OSVER="Devuan $(cat /etc/devuan_version)"
    elif [ -f /etc/lsb-release ]; then
          . /etc/lsb-release
          OSVER="$DISTRIB_DESCRIPTION"
    elif [ -f /etc/debian_version ]; then
          OSVER="Debian $(cat /etc/debian_version)"
    else
        OSVER="an unknown distribution"
    fi
else
    OSVER="an unknown distribution"
fi

cat >> "$LOGFILE" <<EOF
This computer is running $OSVER $ARCH

-----------
EOF

# checking IP numbers
IP_DATA=$(ip a | grep -v forever)
cat >> "$LOGFILE" <<EOF
running command : ip a
$IP_DATA

-----------
EOF

Check_file_exists /etc/hosts
Check_file_exists /etc/resolv.conf
grep "127.0.0.53" /etc/resolv.conf
if [ "$?" -eq 0 ]; then

    cat >> "$LOGFILE" <<EOF
systemd stub resolver detected, running command : systemd-resolve --status
-----------
EOF
    STUBERES=1
fi
if [ "${STUBERES}" = 1 ]
then
systemd-resolve --status >> "$LOGFILE"
cat >> "$LOGFILE" <<EOF

-------resolv.conf end----

EOF
fi

Check_file_exists /etc/krb5.conf
Check_file_exists /etc/nsswitch.conf

Check_file_exists "${SMBCONF}"

USERMAP="$(grep "username map" "${SMBCONF}" | awk '{print $NF }')"
# auto..
if [ "${ADDC}" -eq 1 ]; then
    SERVER_ROLE="$(samba-tool testparm -v --suppress-prompt | grep "server role"| cut -d"=" -f2)"
else
    SERVER_ROLE="$(testparm -v -s | grep "server role"| cut -d"=" -f2)"
fi


if [ -e "${USERMAP}" ]; then
    if [ "$UDM" = "1" ]; then
        MAPCONTENTS=$(cat "$USERMAP")
        cat >> "$LOGFILE" << EOF
Running as Unix domain member and user.map detected.

Contents of $USERMAP

$MAPCONTENTS

Server Role is set to : $SERVER_ROLE

-----------
EOF
    elif [ "$ADDC" = "1" ]; then
          cat >> "$LOGFILE" <<EOF
You have a user.map set in your smb.conf
This is not allowed because Samba is running as a DC

-----------
EOF
    fi
else
    if [ "$UDM" = "1" ]; then
        cat >> "$LOGFILE" <<EOF
Running as Unix domain member and no user.map detected.
This is possible with an auth-only setup, checking also for NFS parts
-----------
EOF
# check if nfs is used and idmapd.conf exits.
Check_file_exists /etc/idmapd.conf
CHECK_PACKAGES1="samba|winbind|krb5|smbclient|acl|attr|nfs"
   fi
fi

if [ "$ADDC" = "1" ]; then
    found=0
    # check for bind9_dlz
    if [ $(grep -c 'server services' /etc/samba/smb.conf) -eq 0 ]; then
        DNS_SERVER='internal'
    else
        # could be using Bind9
        SERVICES=$(grep "server services" "${SMBCONF}")
        SERVER='dns'
        dnscount=${SERVICES//"$SERVER"}
        if [ $(echo "$SERVICES" | grep -c "\-dns") -eq 1 ]; then
            DNS_SERVER='bind9'
        elif [ $(((${#SERVICES} - ${#dnscount}) / ${#SERVER})) -eq 1 ]; then
              DNS_SERVER='bind9'
        elif [ $(((${#SERVICES} - ${#dnscount}) / ${#SERVER})) -eq 2 ]; then
              DNS_SERVER='internal'
        fi
    fi


    if [ "$DNS_SERVER" = 'bind9' ]; then
        echo "Detected bind DLZ enabled.." >> $LOGFILE
        if [ -d /etc/bind ]; then
            CHECK_PACKAGES1="${CHECK_PACKAGES1}|bind9"
            
            Check_file_exists "/etc/bind/named.conf"
            Check_file_exists "/etc/bind/named.conf.options"
            Check_file_exists "/etc/bind/named.conf.local"
            Check_file_exists "/etc/bind/named.conf.default-zones"
            echo -n "Samba DNS zone list: " >> $LOGFILE
            samba-tool dns zonelist ${FQDN} -k yes -P >> $LOGFILE
            echo  >> $LOGFILE
            echo "Samba DNS zone list Automated check : " >> $LOGFILE
            zonelist="$(samba-tool dns zonelist ${FQDN} -k yes -P)"
            zones="$(echo "${zonelist}" | grep '[p]szZoneName' | awk '{print $NF}' | tr '\n' ' ')"
            while read -r -d ' ' zone
            do
              zonetest=$(grep -r "${zone}" /etc/bind|grep -v dpkg-dist)
              if [ -n "${zonetest}" ]; then
                  found=$((found + 1))
              fi

              if [ "${found}" -gt 0 ]; then
                  cat >> "$LOGFILE" <<EOF

ERROR: AD DC zones found in the Bind flat-files
       This is not allowed, you must remove them.
       Conflicting zone name : ${zone}
       File in question is : ${zonetest}
-----------
EOF
              else
                  cat >> "$LOGFILE" <<EOF
zone : ${zone} ok, no Bind flat-files found
-----------
EOF
              fi
            done <<< "${zones}"
        else
            cat >> "$LOGFILE" <<EOF

Warning, detected bind is enabled in smb.conf, but no /etc/bind directory found

-----------
EOF
        fi
    else
        cat >> "$LOGFILE" <<EOF
BIND_DLZ not detected in smb.conf

-----------
EOF
    fi
fi


# Todo
# checking for extra includes.
#if [ -e "/etc/bind/named.conf.local" ]
#then
#    for ExtraIncludes in $(grep "include \"\/" /etc/bind/named.conf.local)
#    do
#    ..
#fi

# Where is the 'smbd' binary ?
#if [ -f /usr/sbin/smbd ]
#then
#SBINDIR="$(smbd -b | grep 'SBINDIR'  | awk '{ print $NF }')"
# TODO..add more checks..

running=$(dpkg -l | egrep "$CHECK_PACKAGES1")
cat >> "$LOGFILE" <<EOF

Installed packages:
$running

-----------
EOF

echo "The debug info about your system can be found in this file: $LOGFILE"
echo "Please check this and if required, sanitise it."
echo "Then copy & paste it into an  email to the samba list"
echo "Do not attach it to the email, the Samba mailing list strips attachments."

# Remove Administrators kerberos ticket.
kdestroy

exit 0
