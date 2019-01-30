#!/bin/bash -v

##
## Version      : 1.0.8
## release d.d. : 24-03-2015
## Author       : L. van Belle
## E-mail       : louis@van-belle.nl
## Copyright    : Free as free can be, copy it, change it if needed.
## Sidenote     : if you change things, please inform me
## ChangeLog    : first release d.d. 23-03-2015
## 24-03-2015   : 1.0.2 few small changes, thanks Rowland for the suggestions.
## 22-04-2015   : 1.0.3 moved mailx part within check if an e-mail adres is used.
## 24-04-2015   : 1.0.4 added extra check, so if no is if found, you get an error message and not a python error.
## 21-11-2016   : 1.0.5 extra filter options. ( samba 4.5.x needs adjusting )
## ( removed the . in the hostname resolving for the DCS, this was no error, but its more clear what people want to see )
## 12-02-2018   : 1.0.6 fix the test for presence of "FAILURE" will be true even if the actual result is "successful".
## 13-02-2018   : 1.0.7 fix filter, variable was not used. optimized code, remove ^M.
## 30-01-2019   : 1.0.8 change filter defaults to whenChanged,dc,DC,cn,CN

## Samba database checker. ( samba 4.1-4.8 tested) 
## This script wil check for error in the samba databases with samba-tool
## If needed adjust it to your os needs.

## !! Warning, samba 4.5.0 - 4.5.1 errors about cn CN ou OU differences.
## This is a samba bug : https://bugzilla.samba.org/show_bug.cgi?id=12399
# you may need to adjust the filter options below. (SAMBA_LDAPCMD_FILTER)

## NOTICE !! This script does only work with samba DC's
## A samba DC + Windows DC wont work and is not tested, if you get that to work,
## please share the code ;-)

## Howto use it:
## Put it on any samba4 DC and run it.
## if you put it in a cron job,
## set the mail report adres and put in the password for Administrator
## and set the relayhost.
## Test it, by remove-ing the email adres at EMAIL_REPORT_ADRES
## and you get a console output of the checks.
## Thats it, enjoy..
## All other settings are optional..

## Only tested with user "Administrator".. best is not to change this.
SAMBA_NT_ADMIN_USER="Administrator"
## if empty the script wil ask for the pass..
## for running this with cron this is a must !
SAMBA_NT_ADMIN_PASS=""

## perform 2 checkes by default for the database replication
## keep both set to yes, thats the best.
SAMBA_CHECKDB_WITH_DRS="yes"
SAMBA_CHECKDB_WITH_LDAPCMD="yes"
## Filter non-synced attributes
## Change the filter to avoid mismatching, some items can be ignored.
## Some examples. : whenChanged,usnChanged,usnCreated,msDS-NcType,serverState
## add them with "," seperated.
SAMBA_LDAPCMD_FILTER="whenChanged,dc,DC,cn,CN"

# TODO, this one is not integrated yet! 
## Compare single AD partitions on Domain Controller DC1 and DC2:
## You can compair also only one for more partitions in stead of the full DB.
## The options are : domain configuration schema dnsdomain dnsforest
## Keep empty for full DB compair, or space separated partition options.
#SAMBA_LDAPCMD_PARTITIONS=""


## The email adress to report to.
## If you put an e-mail adres here the script wil also check for mail tools.. etc
## Email are only send when errors are found and no console output !
## if you want console put, dont put any email address here..
EMAIL_REPORT_ADDRESS=""

## Normaly only e-mail are send when errors are found, or set yes for always email
EMAIL_REPORT_ALWAYS="no"

## I use postfix as relay host. ( set to run on localhost only)
## Put here your mail relay host
## hostname or hostname-fqdn or ip or ip:port are ok.
## This is only used when NO sendmail program if found.
POSTFIX_RELAY_HOST=""

## postfix wil be automatily setup for your.
## If you did already setup any mail server on the server or you are able to mail
## from this server with "mail" command, then this script does not install postfix.

## cleanup the log in /tmp
## can be handy if you want to review manualy.
SETREMOVELOG="no"

## So you reached the end for the configure..
## Set this one to yes.. and your good to go.
CONFIGURED="no"


#######################################################################
## DONT CHANGE BELOW Please, if you make changes, please share them.  #
#######################################################################

## hostname in single word, but you dont need to change this
SETHOSTNAME="$(hostname -s)"
## domainname.tld, but if you installed correct, you dont need to change this
SETDNSDOMAIN="$(hostname -d)"
## hostname.domainname.tld, but if you installed correct, you dont need to change this
SETFQDN="$(hostname -f)"


SETTPUT="$(which tput)"
if [ -z "${SETTPUT}" ]; then
    echo "program tput not found, installing it now.. please wait"
    apt-get update > /dev/null
    apt-get install -y --no-install-recommends ncurses-bin > /dev/null
fi

RED="$(${SETTPUT} setaf 1)"
NORMAL="$(${SETTPUT} sgr0)"
GREEN="$(${SETTPUT} setaf 2)"
YELLOW="$(${SETTPUT} setaf 3)"
UNDERLINE="$(${SETTPUT} smul)"
WHITE="$(${SETTPUT} setaf 7)"
BOLD="$(${SETTPUT} bold)"

message() {
  printf "%40s\n" "${WHITE}${BOLD}$*${NORMAL}"
}
good() {
  printf "%40s\n" "${GREEN}$*${NORMAL}"
}
error() {
  printf "%40s\n" "${RED}$*${NORMAL}"
}
warning() {
  printf "%40s\n" "${YELLOW}$*${NORMAL}"
}
warning_underline() {
  printf "%40s\n" "${YELLOW}${UNDERLINE}$*${NORMAL}"
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

if [ $SAMBA_CHECKDB_WITH_DRS = "no" ] && [ ${SAMBA_CHECKDB_WITH_LDAPCMD} = "no" ] ; then
    error "When you set both SAMBA_CHECKBD... to NO.. then there is no point of running this script"
    error "Please set at least 1 of these checks to yes"
    error "exiting script now... "
    exit 0
fi

SET_SAMBATOOL="$(which samba-tool)"
if [ -z "$SET_SAMBATOOL" ]; then
    error "No samba-tool tool found, this script wil exit now.. this.. I cant fix."
    exit 0
fi

SET_TR="$(which tr)"
if [ -z "$SET_TR" ]; then
    warning "No tr tool found, running apt-get update and install coreutils, please wait.."
    apt-get update > /dev/null
    apt-get install -y --no-install-recommends coreutils > /dev/null
    sleep 0.5
    SET_TR="$(which tr)"
fi

## get DC info
DCS="$(host -t SRV _kerberos._udp."${SETDNSDOMAIN}" | awk '{print $NF}'| sed 's/.$//')"
if [ -z "${DCS}" ]; then
    error "No Samba DCS found, host -t SRV _kerberos.udp.${SETDNSDOMAIN} returned nothing"
    error "exitting now..."
    exit 0
fi

#SAMBA_DC_FSMO=(${SET_SAMBATOOL} fsmo show | cut -d',' -f2 | head -n1 | cut -c4-100 | ${SET_TR} '[:upper:]' '[:lower:]')
SAMBA_DC_FSMO=$(echo $(${SET_SAMBATOOL} fsmo show | cut -d"," -f2 | head -n1 | cut -c4-100) | ${SET_TR} '[:upper:]' '[:lower:]')
SAMBA_DC1="${SAMBA_DC_FSMO}.${SETDNSDOMAIN}"
if [ -z "${SAMBA_DC1}" ]; then
    error "No Samba DC Found with FSMO Roles, you might have dns problems"
    error "exitting now..."
    exit 0
fi

#SAMBA_DCS="$(echo ${DCS} | grep -v ${SAMBA_DC_FSMO})"
SAMBA_DCS=$(echo "$DCS" | grep -v "${SAMBA_DC_FSMO}")
if [ -z "${SAMBA_DCS}" ]; then
    error "No Samba DC's Found with, you might have dns problems"
    error "exitting now..."
    echo $SAMBA_DCS
    exit 0
fi

SAMBA_NT_DOMAINNAME="$($SET_SAMBATOOL domain info "${SAMBA_DC1}" | grep Netbios | cut -d":" -f2 | cut -c2-100)"
if [ -z "${SAMBA_NT_DOMAINNAME}" ]; then
    error "No Samba NT DOMAIN Name found"
    error "exitting now..."
    exit 0
fi

if [ -z "${SAMBA_NT_ADMIN_PASS}" ]; then
    while [ "${SAMBA_NT_ADMIN_PASS}" = "" ]; do
        message "No password for user ${SAMBA_NT_DOMAINNAME}\\${SAMBA_NT_ADMIN_USER} was set in this script!"
        warning_underline "Please enter the password for ${SAMBA_NT_DOMAINNAME}\\${SAMBA_NT_ADMIN_USER} : "
        read -r -s -e "SAMBA_NT_ADMIN_PASS"
    done
fi

echo "${SAMBA_NT_ADMIN_PASS}" | kinit "${SAMBA_NT_ADMIN_USER}" > /dev/null


SET_DEBCONF_SETSELECT="$(which debconf-set-selections)"
if [ -z "${SET_DEBCONF_SETSELECT}" ]; then
    warning "No debconf-set-selections tool found, running apt-get update and install debconf , please wait.."
    apt-get update > /dev/null
    apt-get install -y --no-install-recommends debconf  > /dev/null
    sleep 0.5
    SET_DEBCONF_SETSELECT="$(which debconf-set-selections)"
fi

if [ ! -z "${EMAIL_REPORT_ADDRESS}" ]; then
    SET_SENDMAIL="$(which sendmail)"
    if [ -z "${SET_SENDMAIL}" ]; then
        warning "No mailserver found, running apt-get update and installing postfix as smarthost, please wait.."
        ## these are the debian defaults for a "smarthost setup"
        echo "postfix postfix/main_mailer_type        select  Satellite system" | ${SET_DEBCONF_SETSELECT}
        echo "postfix postfix/mailname        string ${SETFQDN}" | ${SET_DEBCONF_SETSELECT}
        echo "postfix postfix/relayhost       string  ${POSTFIX_RELAY_HOST}" | ${SET_DEBCONF_SETSELECT}
        apt-get update > /dev/null
        apt-get install -y --no-install-recommends postfix  > /dev/null
        sleep 0.5
        SET_SENDMAIL="$(which sendmail)"
        postconf -e "mydestination = ${SETFQDN}, localhost, localhost.localdomain"
        postconf -e "inet_interfaces = 127.0.0.1"
        postconf -e "inet_protocols = ipv4"
        sleep 0.2
        service postfix restart
    fi
    SET_MAILTOOL="$(which mail)"
    if [ -z "$SET_MAILTOOL" ]; then
        warning "No mail tool found, running apt-get update and install heirloom-mailx, please wait.."
        apt-get update > /dev/null
        apt-get install -y --no-install-recommends heirloom-mailx > /dev/null
        sleep 0.5
        SET_MAILTOOL="$(which mail)"
        ${SET_MAILTOOL} -s "Test mail from script : check db"  "${EMAIL_REPORT_ADDRESS}" < /etc/hosts
    fi
fi


## always remove the log before running the script again.
if [ "${SETREMOVELOG}" = "yes" ] || [ "${SETREMOVELOG}" = "no" ] ; then
    if [ -f /tmp/samba_ldapcmp_checkdb ]; then
        rm /tmp/samba_ldapcmp_checkdb
    fi
    if [ -f /tmp/samba_drs_showrepl ]; then
        rm /tmp/samba_drs_showrepl
    fi
fi

## used for samba-tool drs showrepl
## expected success is depending on total of DC's.
expected_success=0
## expected failure is always 0
expected_failure=0
for x in ${SAMBA_DCS}; do
     expected_success=$(( expected_success +=10 ))
done

if [ ! -z "${EMAIL_REPORT_ADDRESS}" ]; then
    if [ "${SAMBA_CHECKDB_WITH_LDAPCMD}" = "yes" ]; then
        for x in ${SAMBA_DCS}; do
            $SET_SAMBATOOL ldapcmp --filter="$(LDAPCMD_FILTER)" ldap://"${SAMBA_DC1}" ldap://"${x}" -d0  > /tmp/samba_ldapcmp_checkdb 2>&1
            if grep -q FAILURE /tmp/samba_ldapcmp_checkdb; then
                ${SET_MAILTOOL} -s "FAILURE ldapcmp between $SETDCFSMO and $x" "${EMAIL_REPORT_ADDRESS}" < /tmp/samba_ldapcmp_checkdb
            fi
        done
    fi
    if [ "${SAMBA_CHECKDB_WITH_DRS}" = "yes" ]; then
        ${SET_SAMBATOOL} drs showrepl -d0  > /tmp/samba_drs_showrepl 2>&1
        failure=$(grep -c "failed" /tmp/samba_drs_showrepl)
        success=$(grep -c "successful" /tmp/samba_drs_showrepl)
        for x in ${SAMBA_DCS} ; do
            if [ "${failure}" -ne "${expected_failure}" ]; then
                ${SET_MAILTOOL} -s "FAILURE: unexpected showrepl result between $SETDCFSMO and $x" $EMAIL_REPORT_ADDRESS < /tmp/samba_drs_showrepl
            fi
            if [ "${success}" -ne "${expected_success}" ]; then
                ${SET_MAILTOOL} -s "FAILURE: unexpected showrepl result between $SETDCFSMO and $x" $EMAIL_REPORT_ADDRESS < /tmp/samba_drs_showrepl
            fi
        done
    fi
else
    message "Running with with console output"
    if [ "${SAMBA_CHECKDB_WITH_LDAPCMD}" = "yes" ]; then
        echo "Checking the DC_With_FSMO (${SAMBA_DC_FSMO}) with SAMBA DC: ${SAMBA_DCS}"
        for x in ${SAMBA_DCS}; do
            message "Running : ${SET_SAMBATOOL} ldapcmp --filter=\"${SAMBA_LDAPCMD_FILTER}\" ldap://$SAMBA_DC1 ldap://$x "
            message "Please wait.. this can take a while.."
            #${SET_SAMBATOOL} ldapcmp --filter="${SAMBA_LDAPCMD_FILTER}" ldap://"${SAMBA_DC1}" ldap://"${x}"  -d0 > /tmp/samba_ldapcmp_checkdb
	    ${SET_SAMBATOOL} ldapcmp --filter="${SAMBA_LDAPCMD_FILTER}" ldap://"$SAMBA_DC1" ldap://"${x}"  -d0 > /tmp/samba_ldapcmp_checkdb 2>&1
            if grep -q FAILURE /tmp/samba_ldapcmp_checkdb; then
                warning "$(cat /tmp/samba_ldapcmp_checkdb)"
            else
                good "$(cat /tmp/samba_ldapcmp_checkdb)"
            fi
        done
    fi
    echo ".. Next check.. "
    if [ "${SAMBA_CHECKDB_WITH_DRS}" = "yes" ]; then
        message "Running : samba-tool drs showrepl"
    #    ${SET_SAMBATOOL} drs showrepl -d0 2>&1 > /tmp/samba_drs_showrepl
	${SET_SAMBATOOL} drs showrepl -d0 > /tmp/samba_drs_showrepl 2>&1
        failure="$(grep -c "failed" /tmp/samba_drs_showrepl)"
        success="$(grep -c "successful" /tmp/samba_drs_showrepl)"
        for x in ${SAMBA_DCS} ; do
            if [ "${failure}" -ne "${expected_failure}" ]; then
                error "failures don't match"
            fi
            if [ "${success}" -ne "${expected_success}" ]; then
                error "successes don't match"
            fi
            if [ "${failure}" -eq "${expected_failure}" ] && [ "${success}" -eq "${expected_success}" ]; then
                good "No errors found"
            fi
        done
    fi
fi

if [ "${EMAIL_REPORT_ALWAYS}" = "yes" ] && [ -n "${EMAIL_REPORT_ADDRESS}" ]; then
    #cat /tmp/samba_drs_showrepl | ${SET_MAILTOOL} -s "SAMBA CHECK DB : showrepl results" $EMAIL_REPORT_ADDRESS
    ${SET_MAILTOOL} -s "SAMBA CHECK DB : showrepl results" $EMAIL_REPORT_ADDRESS < /tmp/samba_drs_showrepl
    #cat /tmp/samba_ldapcmp_checkdb | ${SET_MAILTOOL} -s "SAMBA CHECK DB : ldapcmp results" $EMAIL_REPORT_ADDRESS
    ${SET_MAILTOOL} -s "SAMBA CHECK DB : ldapcmp results" $EMAIL_REPORT_ADDRESS < /tmp/samba_ldapcmp_checkdb
fi

if [ "${SETREMOVELOG}" = "yes" ]; then
    if [ -f /tmp/samba_ldapcmp_checkdb ]; then
        rm /tmp/samba_ldapcmp_checkdb
    fi
    if [ -f /tmp/samba_drs_showrepl ]; then
        rm /tmp/samba_drs_showrepl
    fi
fi
