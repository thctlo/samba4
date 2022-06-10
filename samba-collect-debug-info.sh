#!/bin/bash

# samba-collect-debug-info.sh
#
# 31 Aug 2019 Rowland Penny
# re-wrote several sections and added time and nsswitch.conf checks
# 0.3
# 
# d.d. 16 Aug 2019
# 0.21   Added kerberos REALM detection before kinit when starting the script.
#
# Created and maintained by Rowland Penny and Louis van Belle.
# questions, ask them in the samba list.

# This script helps with debugging problems when you report them on the samba list.
# This really helps a lot in finding/helping with problems.
# Don't attach this to an e-mail, the samba list removes attachments,
# add the content in the mail.

# This is the only changeable variable.
# If you want to put the output somewhere else, change this,
# but the path must exist.
LOGFILE="/tmp/samba-debug-info.txt"

###############################################################################
#                       DO NOT CHANGE ANYTHING BELOW!                         #
###############################################################################

################ Functions

fileserver_auth() {
    fileserver=0
    PASSWD=$(cat /etc/nsswitch.conf | grep '[p]asswd' | grep -c '[w]inbind')
    if [ "$PASSWD" -eq 1 ]; then
        fileserver=$((fileserver+2))
    fi
    GROUP=$(cat /etc/nsswitch.conf | grep '^[g]roup' | grep -c '[w]inbind')
    if [ "$GROUP" -eq 1 ]; then
        fileserver=$((fileserver+3))
    fi
    SHADOW=$(cat /etc/nsswitch.conf | grep '^[s]hadow' | grep -c '[w]inbind')
    if [ "$SHADOW" -eq 1 ]; then
        fileserver=$((fileserver+4))
    fi

    echo "$fileserver"
}

Check_file_exists () {
if [ -e "${1}" ]; then
    local FILE="$(cat "${1}")"
    cat >> "$LOGFILE" <<EOF
Checking file: ${1}

${FILE}

-----------

EOF
else
    cat >> "$LOGFILE" <<EOF
Warning, ${1} does not exist

-----------

EOF
fi
}

############# Code ##############

# the script needs to run as root.
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo. Exiting now..."
    exit 1
fi

CHECK_PACKAGES="samba|winbind|krb5|smbclient|acl|attr"
ADDC=0
UDM=0

# exit if no /etc/krb5.conf
if [ ! -f /etc/krb5.conf ]; then
    cat <<EOF
ERROR, /etc/krb5.conf is missing, is krb5-user installed?
Please check : dpkg -s krb5-user |grep -i status
If it's missing/not installed, run 'apt install krb5-user'
The Samba defaults work fine and are all you need:

[libdefaults]
    default_realm = ${REALM}
    dns_lookup_kdc = true
    dns_lookup_realm = false

Any other settings are OS defaults and are not required.

-----------

EOF
    exit 1
fi

printf "\nPlease wait, collecting debug info.\n\n"

printf "Config collected --- $(date +%Y-%m-%d-%H:%M) -----------\n" > $LOGFILE

HOSTNAME="$(hostname -s)"
DOMAIN="$(hostname -d)"
REALM="${DOMAIN^^}"
FQDN="$(hostname -f)"
IP="$(hostname -I)"

# Base info.
cat >> "$LOGFILE" <<EOF

Hostname:   ${HOSTNAME}
DNS Domain: ${DOMAIN}
Realm:      ${REALM}
FQDN:       ${FQDN}
ipaddress:  ${IP}

-----------

EOF

# FIXME add check for other distros, Centos etc
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
if [ "${?}" -eq 0 ]; then
    if [ "${ADDC}" -eq 1 ]; then
        printf "\n'systemd-resolve' is running on a Samba AD DC.\nThis is not allowed.\nYou should remove it.\n\n-----------\n" >> $LOGFILE
    else
        cat >> "$LOGFILE" <<EOF
systemd stub resolver detected, running command : systemd-resolve --status

-----------

EOF
        STUBERES=1
    fi

    if [ "${STUBERES}" = 1 ]; then
        systemd-resolve --status >> "$LOGFILE"
        cat >> "$LOGFILE" <<EOF

-----------

EOF
    fi
fi

# Test for _kerberos._tcp records.
nslookup -type=SRV _kerberos._tcp."${DOMAIN}" > /dev/null 2>&1
if [ "$?" -ne 0 ]; then
    printf "WARNING: 'kinit Administrator' will fail, you need to fix this.\nUnable to verify DNS kerberos._tcp SRV records\n\n-----------\n\n" >> $LOGFILE
else
    printf "Kerberos SRV _kerberos._tcp.${DOMAIN} record(s) verified ok, sample output:\n%s\n\n-----------\n\n" "$(nslookup -type=SRV _kerberos._tcp.${DOMAIN})" >> $LOGFILE

    for x in $(nslookup -type=NS "${DOMAIN}"|grep nameserver |awk -F"=" '{ print $NF }'  >/dev/null)
    do
      nslookup -type=SRV _kerberos._tcp."${DOMAIN}" "${x}" > /dev/null
      status="$?"
      if [ "$status" -ne 0 ]; then
          printf "Error detecting the nameserver '$x' _kerberos._tcp.${DOMAIN} records\n\n-----------\n\n" >> $LOGFILE
      else
          printf "DNS NS records for the nameservers: ${x} in domain ${DOMAIN} verified ok\n%s\n\n-----------\n\n" "$(nslookup -type=NS "${DOMAIN}"|grep nameserver |awk -F"=" '{ print $NF }')" >> $LOGFILE
      fi
    done
fi

# Initialize the Administrator
kinit Administrator 2> /dev/null
if [ "$?" -ne 0 ]; then
    printf "'kinit Administrator' password checked failed.\nWrong password or kerberos REALM problems.\n\n-----------\n\n" >> "$LOGFILE"
else
    printf "'kinit Administrator' checked successfully.\n\n-----------\n\n" >> "$LOGFILE"
    # Remove Administrators kerberos ticket.
    kdestroy
fi

SMBCONF='smb.conf'
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

-----------

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

-----------

EOF
           UDM=1
           if [ -f /usr/sbin/smbd ]; then
                SMBCONF=$(smbd -b | grep 'CONFIGFILE' | awk '{print $NF}')
           elif [ -f "$(command -v wbinfo)" ]; then
                 if [ -e /etc/samba/smb.conf ]; then
                     printf "Detected, Samba is running winbind only. Auth-only server, Unix domain member\n-----------\n" >> $LOGFILE
                     SMBCONF=/etc/samba/smb.conf
                 fi
           fi
       fi
      ;;
    7) ROLE="$(testparm -s --parameter-name='security' 2>/dev/null)"
       ROLE="${ROLE^^}"
       if [ "$ROLE" = "ADS" ]; then
           printf "Samba is running as a Unix domain member\n\n-----------\n" >> $LOGFILE
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
   10) ROLE="$(testparm -s --parameter-name='security' 2>/dev/null)"
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

-----------

EOF
      ;;
esac

Check_file_exists /etc/krb5.conf
Check_file_exists /etc/nsswitch.conf

if [ "$SMBCONF" != 'smb.conf' ]; then
    Check_file_exists "${SMBCONF}"
    USERMAP="$(grep "username map" "${SMBCONF}" | awk '{print $NF }')"
else
    echo "Warning: No smb.conf found"
fi

if [ "${ADDC}" -eq 1 ]; then
    SERVER_ROLE="$(samba-tool testparm --suppress-prompt --parameter-name="server role" 2> /dev/null)"
else
    SERVER_ROLE="$(testparm -s --parameter-name="server role" 2> /dev/null)"
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
        CHECK_PACKAGES="${CHECK_PACKAGES}|nfs"
   fi
fi

if [ "${ADDC}" -eq 1 ]; then
    if [ -f /etc/nsswitch.conf ]; then
        fileserver=$(fileserver_auth)
        case $fileserver in
            0) cat >> "$LOGFILE" <<EOF
This DC is not being used as a fileserver

EOF
               ;;
            2) cat >> "$LOGFILE" <<EOF
This DC is being used as a fileserver,
but only the 'passwd' line is set in /etc/nsswitch.conf

EOF
               ;;
            3) cat >> "$LOGFILE" <<EOF
This DC is being used as a fileserver,
but only the 'group' line is set in /etc/nsswitch.conf

EOF
               ;;
            4) cat >> "$LOGFILE" <<EOF
This DC is not being used as a fileserver,
but the 'shadow' line is set in /etc/nsswitch.conf

EOF
               ;;
            5) cat >> "$LOGFILE" <<EOF
This DC is being used as a fileserver

EOF
               ;;
            6) cat >> "$LOGFILE" <<EOF
This DC is being used as a fileserver
but the 'group' line is not set in /etc/nsswitch.conf
also the 'shadow' line is set

EOF
               ;;
            7) cat >> "$LOGFILE" <<EOF
This DC is being used as a fileserver
but the 'passwd' line is not set in /etc/nsswitch.conf
also the 'shadow' line is set

EOF
               ;;
            9) cat >> "$LOGFILE" <<EOF
This DC is being used as a fileserver
but the 'shadow' line is set in /etc/nsswitch.conf

EOF
               ;;
        esac
    fi
elif [ "$UDM" = "1" ]; then
      if [ -f /etc/nsswitch.conf ]; then
          fileserver=$(fileserver_auth)
          case $fileserver in
              0) cat >> "$LOGFILE" <<EOF
This Unix domain member has neither the 'passwd' and 'group' lines set in /etc/nsswitch.conf

EOF
                 ;;
              2) cat >> "$LOGFILE" <<EOF
Only the 'passwd' line is set in /etc/nsswitch.conf

EOF
                 ;;
              3) cat >> "$LOGFILE" <<EOF
Only the 'group' line is set in /etc/nsswitch.conf

EOF
                 ;;
              4) cat >> "$LOGFILE" <<EOF
This Unix domain member has neither the 'passwd' and 'group' lines set in /etc/nsswitch.conf,
but the 'shadow' line is set

EOF
                 ;;
              5) cat >> "$LOGFILE" <<EOF
This Unix domain member is using 'winbind' in /etc/nsswitch.conf.

EOF
                 ;;
              6) cat >> "$LOGFILE" <<EOF
This Unix domain member has the 'group' and 'shadow' lines set in /etc/nsswitch.conf,
but not the 'passwd' line

EOF
                 ;;
              7) cat >> "$LOGFILE" <<EOF
This Unix domain member has the 'passwd' and 'shadow' lines set in /etc/nsswitch.conf,
but not the 'group' line

EOF
                 ;;
              9) cat >> "$LOGFILE" <<EOF
This Unix domain member has the 'passwd' and 'group' lines set in /etc/nsswitch.conf,
but the 'shadow' line is also set

EOF
                 ;;
          esac
      fi
      cat >> "$LOGFILE" <<EOF

-----------

EOF
fi

if [ "$ADDC" = "1" ]; then
    found=0
    DNS_SERVER='internal'
    # check for bind9_dlz
    if [ "${SMBCONF}" != 'smb.conf' ]; then
        # If there isn't a 'server services' in smb.conf then using the internal dns server
        if [ "$(grep -c 'server services' "${SMBCONF}")" -ne 0 ]; then
            # could be using Bind9
            SERVICES=$(grep "server services" "${SMBCONF}")
            SERVER='dns'
            dnscount=${SERVICES//"$SERVER"}
            if [ "$(echo "$SERVICES" | grep -c "\-dns")" -eq 1 ]; then
                DNS_SERVER='bind9'
            elif [ $(((${#SERVICES} - ${#dnscount}) / ${#SERVER})) -eq 1 ]; then
                  DNS_SERVER='bind9'
            fi
        fi

        if [ "$DNS_SERVER" = 'bind9' ]; then
            echo "Detected bind DLZ enabled.." >> $LOGFILE
            if [ -d /etc/bind ]; then
                CHECK_PACKAGES="${CHECK_PACKAGES}|bind9"

                Check_file_exists "/etc/bind/named.conf"
                Check_file_exists "/etc/bind/named.conf.options"
                Check_file_exists "/etc/bind/named.conf.local"
                Check_file_exists "/etc/bind/named.conf.default-zones"

                echo "Samba DNS zone list check : " >> $LOGFILE

                zonelist="$(samba-tool dns zonelist "${FQDN}" -P)"
                zones="$(echo "${zonelist}" | grep '[p]szZoneName' | awk '{print $NF}' | tr '\n' ' ')"
                while read -r -d ' ' zone
                do
                  zonetest=$(grep -r "${zone}" /etc/bind | grep -v dpkg-dist)
                  if [ -n "${zonetest}" ]; then
                      found=$((found+1))
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
                      echo "${zone}" >> "$LOGFILE"
                  fi
                done <<< "${zones}"
                cat >> "$LOGFILE" <<EOF

-----------

EOF

                base_include_files=$(grep -rnw '/etc/bind/' -e "include" | awk -F ':' '{print $1}' | sort -u)
                for named_file in $base_include_files
                do
                  include_files=$(grep -rnw "$named_file" -e "include" | grep -v '//' | awk '{print $NF}' | sed 's/\"//g' | sed 's/;//')
                  for file in $include_files
                  do
                    if [ "$named_file" = /etc/bind/named.conf ]; then
                        if [ "$file" = /etc/bind/named.conf.options ]; then
                            continue
                        elif [ "$file" = /etc/bind/named.conf.local ]; then
                              continue
                        elif [ "$file" = /etc/bind/named.conf.default-zones ]; then
                              continue
                        fi
                        # anything left is possibly an extra
                        printf "unknown 'include' file '%s' in %s" "$file" "$named_file" >> "$LOGFILE"
                    else
                        # this should only be the Samba named.conf
                        # test for 'samba' in $file path
                        if [[ $file == *samba* ]]; then
                            # is the right path ?
                            if [ -f "$file" ]; then
                                continue
                            else
                                printf "incorrect Samba 'named.conf' path '%s' set in %s" "$file" "$named_file" >> "$LOGFILE"
                            fi
                        else
                            printf "unknown 'include' file '%s' in %s" "$file" "$named_file" >> "$LOGFILE"
                        fi 
                    fi
                  done
                done
                cat >> "$LOGFILE" <<EOF

-----------

EOF
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
fi
###########################################################################
# Check time
pdc_emulator=$(host -t SRV _ldap._tcp.pdc._msdcs.${DOMAIN} | awk '{print $NF}' | sed 's/.$//')
if [ "$pdc_emulator" != "${FQDN}" ]; then
    pdc_emulator_time=$(net time system -S "${pdc_emulator}" 2> /dev/null | date +%FT%T)
    printf "\nTime on the DC with PDC Emulator role is: %s\n\n" "$pdc_emulator_time" >> "$LOGFILE"
    pdc_emulator_secs=$(echo "$pdc_emulator_time" | date +%s)

    local_time=$(net time system -S "${FQDN}" 2> /dev/null | date +%FT%T)
    printf "\nTime on this computer is:                 %s\n\n" "$local_time" >> "$LOGFILE"
    local_time_secs=$(echo "$local_time" | date +%s)

    time_diff="$((pdc_emulator_secs - local_time_secs))"
    if [ "$time_diff" -gt 300 ] || [ "$time_diff" -lt -300 ]; then
        printf "Error, the time difference between servers is too great.\n\n-----------\n" >> "$LOGFILE"
    else
        printf "\nTime verified ok, within the allowed 300sec margin.\nTime offset is currently : %s seconds\n\n-----------\n" "${time_diff}" >> "$LOGFILE"
    fi
else
    pdc_emulator_time=$(echo $(net time system -S "${pdc_emulator}") 2> /dev/null | date +%FT%T)
    printf "\nThis is the DC with the PDC Emulator role and time is: %s\n\n-----------\n" "$pdc_emulator_time" >> "$LOGFILE"
fi

# TODO..add more checks..

running=$(dpkg -l | grep -E "${CHECK_PACKAGES}")
cat >> "$LOGFILE" <<EOF

Installed packages:
$running

-----------

EOF

cat <<EOF


The debug info about your system can be found in this file:
$LOGFILE

Please check this and if required, sanitise it.
Then copy & paste it into an  email to the samba list
Do not attach it to the email, the Samba mailing list strips attachments.

EOF

exit 0

