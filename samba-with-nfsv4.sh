#!/bin/bash
##
## Version      : 1.0.3
## release d.d. : 05-11-2015
## Author       : L. van Belle
## E-mail       : louis@van-belle.nl
## Copyright    : Free as free can be, copy it, change it if needed.
## Sidenote     : if you change please inform me
## ChangeLog    : 15-6-2015: small bug fix for running this on debian jessie
## ChangeLog 1.0.2 : 7-8-2015: changed /etc/exports file remove gss/krb5, see https://wiki.debian.org/NFS/Kerberos
## ChangeLog 1.0.3 : changed idmap.conf to map the servername to user root.
##                 : With this modification, kerberos ssh with dedicated mounted home dirs works.
##				   : added nfs mount fix for Debian Jessie.
## !! ROOT, without kerberos ticket !! CAN NOT ACCESS USER DIRS !!

## This script wil setup the Samba user dirs over NFS with kerberos auth.
## Howto use it.
## run it with parameter "server" or "client"
## like sudo ./scriptname server or sudo ./scriptname client
## DONT run this script server and client on the same server !

## set the nfs export paths..
## you cannot set /home here, not tested in this script.
## the users must be a separated folder
## this path wil be used for client and server setup
SAMBA_USERS_HOMEDIR="/home/users"

## NFS V4 needed settings
## Put here there server name where the exports are. ( the NFS server )
## This is the server where you did setup the "server" setting.
## put the FQDN Name here, like server.internal.domain.tld
## THIS MUST BE THE NAME USED IN DNS for kerberos auth to work.
NFSD_V4_SERVERNAME="hostname.internal.domain.tld"

## The nfs exports folder
## these 2 result in /exports/users in the script
NFSD_V4_EXPORTS_PATH="/exports"

## it should not be needed to change this one.
## this matches with the SAMBA_USERS_HOMEDIR variable
NFSD_V4_EXPORTS_USERS_PATH="/users"

## Your network where clients are connecting from.
## for now only 1 network is supported.
## if left empty we wil use your network extracted from ip adres, range /24
## example : 192.168.1.0/24"
NFSD_V4_NETWORK=""

## Use a dedicated mount for the users or automount.
## Options : dedicated or automount
## a dedicated mount is setup in fstab
## for mulpliple users use dedicated, only for ssh logins use auto.
NFS_CLIENT_MOUNT_USERS="dedicated"

# Enable ssh kerberos enable logins
SSHD_KERBEROS_ENABLED="yes"

## change this one to yes to start the script.
CONFIGURED="no"

################### FUNCTIONS #############################

SET_SCRIPT_RUN_DATE_TIME=`date +%Y-%m-%d-%H_%m`

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

function message() {
  printf "%40s\n" "${WHITE}${BOLD}$@${NORMAL}"
}
function good() {
  printf "%40s\n" "${GREEN}$@${NORMAL}"
}
function error() {
  printf "%40s\n" "${RED}$@${NORMAL}"
}
function warning() {
  printf "%40s\n" "${YELLOW}$@${NORMAL}"
}
function warning_underline() {
  printf "%40s\n" "${YELLOW}${UNDERLINE}$@${NORMAL}"
}
function _apt_update_upgrade() {
    message "Please wait, running update and upgrade"
    apt-get update > /dev/null
    apt-get upgrade -y 2&> /dev/null
    echo " "
}
function _apt_install() {
    apt-get install -y $1 > /dev/null
}

function _apt_install_norecommends() {
    apt-get install -y --no-install-recommends $1 > /dev/null
}
function _apt_available() {
    if [ `apt-cache search $1 | grep -o "$1" | uniq | wc -l` = "1" ]; then
        good "Package is available : $1"
        PACKAGE_INSTALL="1"
    else
        error "Package $1 is NOT available for install"
        error "We can not continue without this package..."
        error "Exitting now.."
        exit 0
    fi
}
function _package_install {
    _apt_available $1
    if [ "${PACKAGE_INSTALL}" = "1" ]; then
        if [ "$(dpkg-query -l $1 | tail -n1 | cut -c1-2)" = "ii" ]; then
             warning "package is already_installed: $1"
        else
            message "installing package : $1, please wait.."
            _apt_install $1
            sleep 0.5
        fi
    fi
}

function _package_install_no_recommends {
    _apt_available $1
    if [ "${PACKAGE_INSTALL}" = "1" ]; then
        if [ "$(dpkg-query -l $1 | tail -n1 | cut -c1-2)" = "ii" ]; then
             warning "package is already_installed: $1"
        else
            message "installing package : $1, please wait.."
            _apt_install_norecommends $1
            sleep 0.5
        fi
    fi
}

function _check_run_as_sudo_root() {
    if ! [[ $EUID -eq 0 ]]; then
        error "This script should be run using sudo or by root."
        exit 1
    fi
}
function _configured_script() {
    if [ "${CONFIGURED}" = "no" ]; then
        error "####################################################"
        error "You need to configure this script first to run it. "
        error " "
        error "exiting script now... "
        exit 0
    fi
}
function _check_folder_exists() {
    if [ ! -d $1 ] ; then
        message "Creating folder: $1"
        mkdir -p $1
    fi
}
function _backup_file() {
    if [ ! -f $1.backup ] ; then
        message "Creating Backup of file: $1"
        cp $1 $1.backup
    fi
}
function _backup_file_date() {
    if [ ! -f $1.${SET_SCRIPT_RUN_DATE_TIME}.backup ] ; then
        message "Creating Backup of file: $1 (date include in filename)"
        cp $1 $1.${SET_SCRIPT_RUN_DATE_TIME}.backup
    fi
}
function _backup_folder() {
    if [ ! -d $1.backup ] ; then
        message "Creating Backup of folder: $1"
        cp -R $1 $1.backup
    fi
}
function _backup_folder_date() {
    if [ ! -d $1.${SET_SCRIPT_RUN_DATE_TIME}.backup ] ; then
        message "Creating Backup of folder: $1 (date include in foldername)"
        cp -R $1 $1.${SET_SCRIPT_RUN_DATE_TIME}.backup
    fi
}

########################## CODE #########################

_configured_script
_check_run_as_sudo_root

#############################################################
######## LEAVE THESE HERE AND DONT CHANGE THESE 4 !!!!!!
## hostname in single word, but you dont need to change this
SETHOSTNAME=`hostname -s`
## domainname.tld, but if you installed correct, you dont need to change this
SETDNSDOMAIN=`hostname -d`
## hostname.domainname.tld, but if you installed correct, you dont need to change this
SETFQDN=`hostname -f`
## server ip, if /etc/hosts is setup correct.
SETSERVERIP=`hostname -i`
SETSERVERIPNET=`hostname -i| cut -d"." -f1,2,3`
##############################################################

#### Specific NFS setup setting
SETHOSTNAME_CAPS=`echo ${SETHOSTNAME^^}`
## Samba general setting
SAMBA_KERBEROS_REALM=`echo ${SETDNSDOMAIN^^}`

##################################################################

NFS_SETUP="$1"

if [ -z "${NFS_SETUP}" ]; then
    error "You need to run the script with server or client parameter"
    error "Example ./setup-samba-home-nfs-server.sh server"
    error "Exitting now.. "
    exit 0
fi

if [ "${NFS_SETUP}" = "server" ] || [ "${NFS_SETUP}" = "client" ]; then
    if [ "${NFS_SETUP}" = "server" ]; then
        good "Setting up NFS Server support"

        _package_install nfs-kernel-server
        service nfs-kernel-server stop
        service nfs-common stop
        _check_folder_exists "${NFSD_V4_EXPORTS_PATH}/${NFSD_V4_EXPORTS_USERS_PATH}"

        _backup_file_date /etc/krb5.keytab

        _backup_file /etc/fstab
        if [ `cat /etc/fstab | grep 'NFSv4: Setup'| wc -l` = "0" ]; then
            message "NFSv4: Setup fstab for NFS v4 with kerberos support"
            echo "${SAMBA_USERS_HOMEDIR}     "${NFSD_V4_EXPORTS_PATH}${NFSD_V4_EXPORTS_USERS_PATH}"      none    bind         0       0" >> /etc/fstab
            mount -a
        else
            warning "fstab was already setup for NFSv4, checking if mounted.."
            if `df | grep "${NFSD_V4_EXPORTS_PATH}${NFSD_V4_EXPORTS_USERS_PATH}" | wc -l` = "0" ]; then
                mount -a
            else
                warning "${NFSD_V4_EXPORTS_PATH}${NFSD_V4_EXPORTS_USERS_PATH} was already mounted"
            fi
        fi

        _backup_file /etc/exports
        message "Setup of /etc/exports"
        if [ ${NFSD_V4_NETWORK} = "" ]; then
            NFSD_V4_NETWORK="${SETSERVERIPNET}.0/24"
        fi

        if [ `cat /etc/exports | grep "${NFSD_V4_EXPORTS_PATH}${NFSD_V4_EXPORTS_USERS_PATH}" | wc -l` = "0" ]; then
            cat << EOF > /etc/exports
# 'fsid=0' designates this path as the nfs4 root
# 'crossmnt' is necessary to properly expose the paths
# 'no_subtree_check' is specified to get rid of warning messages
#    about the default value changing. This is the default value
${NFSD_V4_EXPORTS_PATH}         ${NFSD_V4_NETWORK}(rw,sync,fsid=0,no_subtree_check,crossmnt,sec=krb5)
${NFSD_V4_EXPORTS_PATH}${NFSD_V4_EXPORTS_USERS_PATH}   ${NFSD_V4_NETWORK}(rw,sync,no_subtree_check,sec=krb5)
EOF
        else
            warning "The file : /etc/exports was already setup"
        fi

        _backup_file /etc/idmapd.conf
        if [ `cat /etc/idmapd.conf | grep "Method = nsswitch" | wc -l` = "0" ]; then
        message "Setup of /etc/idmapd.conf"
        cat << EOF >> /etc/idmapd.conf

[Translation]

Method = nsswitch

EOF
        else
            warning "The file : /etc/idmapd.conf was already setup"
        fi

        _backup_file /etc/default/nfs-kernel-server
        message "Setup of /etc/default/nfs-kernel-server"
        if [ `cat /etc/default/nfs-kernel-server | grep "NEED_SVCGSSD=yes" | wc -l` = "0" ]; then
            sed -i 's/NEED_SVCGSSD=""/NEED_SVCGSSD="yes"/g' /etc/default/nfs-kernel-server
        else
            warning "The file : /etc/default/nfs-kernel-server was already setup"
        fi

        _backup_file /etc/default/nfs-common
        message "Setup of /etc/default/nfs-common"
        if [ `cat /etc/default/nfs-kernel-server | grep "NEED_GSSD" | wc -l` = "0" ]; then
            sed -i 's/NEED_IDMAPD=/NEED_IDMAPD=yes/g' /etc/default/nfs-common
            sed -i 's/NEED_GSSD=/NEED_GSSD=yes/g' /etc/default/nfs-common
            sed -i 's/NEED_STATD=/NEED_STATD=no/g' /etc/default/nfs-common
        else
            warning "The file : /etc/default/nfs-common was already setup"
        fi
        message "Exporting exports"
        exportfs -r
        sleep 0.5

        message " "
        good "The basic setup of the NFS server is done"
        message " "
        warning "Now you need to add the nfs SPN to this servers name."
        warning "Run the following commands on one of your DC's"
        warning "samba-tool spn add nfs/${SETFQDN} ${SETHOSTNAME_CAPS}\$"
        warning "samba-tool spn add nfs/${SETFQDN}@${SAMBA_KERBEROS_REALM} ${SETHOSTNAME_CAPS}\$"
        warning "samba-tool domain exportkeytab --principal=nfs/${SETFQDN} keytab.${SETHOSTNAME_CAPS}-nfs"
        message " "
        warning "When above is done, you need to copy the keytab file keytab.${SETHOSTNAME_CAPS}-nfs to the server ${SETHOSTNAME_CAPS}"
        warning "Now you need to merge te original keytab file and keytab.${SETHOSTNAME_CAPS}-nfs on server ${SETHOSTNAME_CAPS}"
        message " "
        message "Stop the samba services:"
        message "for x in \`ls /etc/init.d/sernet-*\` ; do \$x stop ; done"
        message " "
        message "Merging the keytab files"
        message "Now type the following on server ${SETHOSTNAME_CAPS}: "
        message "ktutil (hit enter)"
        message "rkt /etc/krb5.keytab (hit enter)"
        message "rkt /PATH_TO_THE_NEW_KEYTABFILE/keytab.${SETHOSTNAME_CAPS}-nfs"
        message "list  ( hit enter and check the output, is nfs listed?) "
        message "wkt /etc/krb5.keytab"
        message "quit"
        message "chmod 600 /etc/krb5.keytab"
        message "chown root:root /etc/krb5.keytab"
        message "Now the keytab file is setup for NFS server support."
        message "Now you can startup the nfs server on  ${SETHOSTNAME_CAPS}"
        message "run : service nfs-kernel-server start"
        message "run : service nfs-common restart"
        message "And test with : mount -t nfs4 ${SETFQDN}:${NFSD_V4_EXPORTS_USERS_PATH} /mnt -o sec=krb5 "
        message "if it works, umount with : umount /mnt"
        message "and start samba services again"
        message "for x in \`ls /etc/init.d/sernet-*\` ; do \$x start ; done"
        message " "
        warning " !! Both server and client need nfs spn's "
    fi

############################################ NFS CLIENT SETUP #######################################################
    if [ "${NFS_SETUP}" = "client" ]; then
        good "Setting up NFS Client support"
        # FOR THE OTHER SERVERS /Client servers.

        _package_install nfs-common
        _package_install rpcbind
        service nfs-common stop
        _check_folder_exists "${SAMBA_USERS_HOMEDIR}"

        _backup_file /etc/idmapd.conf
        if [ `cat /etc/idmapd.conf | grep 'Method = nsswitch' | wc -l` = "0" ]; then
        message "Setup of /etc/idmapd.conf"
        cat << EOF > /etc/idmapd.conf
[General]

Verbosity = 0
Pipefs-Directory = /run/rpc_pipefs

# set your own domain here, if id differs from FQDN minus hostname
# Domain = localdomain
Domain = ${SETDNSDOMAIN}
Local-Realm = ${SAMBA_KERBEROS_REALM}

[Mapping]

Nobody-User = nobody
Nobody-Group = nogroup

[Translation]
Method = static,nsswitch
GSS-Methods = static,nsswitch

[Static]
${SETHOSTNAME_CAPS}\$@${SAMBA_KERBEROS_REALM} = root
host/${SETFQDN}@${SAMBA_KERBEROS_REALM} = root
nfs/${SETFQDN}@${SAMBA_KERBEROS_REALM} = root
nfs/${SETFQDN}@ = root

EOF
        else
            warning "The file : /etc/idmapd.conf was already setup"
        fi

        if [ ${NFS_CLIENT_MOUNT_USERS} = "dedicated" ]; then
            if [ `cat /etc/fstab | grep 'NFS V4 Client Users'| wc -l` = "0" ] || [ `cat /etc/auto.master | grep 'NFS V4 Client Users automount'| wc -l` = "0" ]; then
                _backup_file /etc/fstab
                echo "## NFS V4 Client Users mount"  >> /etc/fstab
                echo "${NFSD_V4_SERVERNAME}:${NFSD_V4_EXPORTS_USERS_PATH}      ${SAMBA_USERS_HOMEDIR}    nfs4 sec=krb5  0       0" >> /etc/fstab
            else
                warning "NFS V4 Client setup was already done"
            fi
        fi
        if [ ${NFS_CLIENT_MOUNT_USERS} = "automount" ]; then
            if [ `cat /etc/fstab | grep 'NFS V4 Client Users'| wc -l` = "0" ] || [ `cat /etc/auto.master | grep 'NFS V4 Client Users automount'| wc -l` = "0" ]; then
                _package_install autofs
                service autofs stop
                #_backup_file /etc/auto.master
                _check_folder_exists /etc/auto.master.d
                echo "## NFS V4 Client Users automount"  >> /etc/auto.master.d/user-home.autofs
                echo "*         ${NFSD_V4_SERVERNAME}:${NFSD_V4_EXPORTS_USERS_PATH}\/\&" >> /etc/auto.master.d/user-home.autofs
                echo "user-home automount file can be found here : /etc/auto.master.d/user-home.autofs"
            else
                warning "NFS V4 Client setup was already done, see /etc/auto.master.d/user-home.autofs"
            fi
        fi
        message " "
        good "The setup of the NFS Client is done"
        message " "
        warning "Now you need to add the nfs SPN to this client server name."
        warning "Run the following commands on one of your DC's"
        warning "samba-tool spn add nfs/${SETFQDN} ${SETHOSTNAME_CAPS}\$"
        warning "samba-tool spn add nfs/${SETFQDN}@${SAMBA_KERBEROS_REALM} ${SETHOSTNAME_CAPS}\$"
        warning "samba-tool domain exportkeytab --principal=nfs/${SETFQDN} keytab.${SETHOSTNAME_CAPS}-nfs"
        message " "
        warning "When above is done, you need to copy the keytab file keytab.${SETHOSTNAME_CAPS}-nfs to the nfs client ${SETHOSTNAME_CAPS}"
        warning "Now you need to merge te original keytab file and keytab.${SETHOSTNAME_CAPS}-nfs on client ${SETHOSTNAME_CAPS}"
        message " "
        message "Stop the samba services:"
        message "SERNET SAMBA: for x in \`ls /etc/init.d/sernet-*\` ; do \$x stop ; done"
        message "DEBIAN SAMBA: for x in \`ls /etc/init.d/samba\` ; do \$x stop ; done"
        message " "
        message "Merging the keytab files"
        message "Now type the following on server ${SETHOSTNAME_CAPS}: "
        message "ktutil (hit enter)"
        message "rkt /etc/krb5.keytab (hit enter)"
        message "rkt /PATH_TO_THE_NEW_KEYTABFILE/keytab.${SETHOSTNAME_CAPS}-nfs"
        message "list  ( hit enter and check the output, is nfs listed?) "
        message "wkt /etc/krb5.keytab"
        message "quit"
        message "chmod 600 /etc/krb5.keytab"
        message "chown root:root /etc/krb5.keytab"
        message "Now the keytab file is setup for NFS server support."
        message "Now you can startup the nfs client on  ${SETHOSTNAME_CAPS}"
        message "run : service nfs-common start"
        message "And test with : mount -t nfs4 ${NFSD_V4_SERVERNAME}:${NFSD_V4_EXPORTS_USERS_PATH} ${SAMBA_USERS_HOMEDIR} -o sec=krb5 "
        message "and start samba services again"
        message "SERNET SAMBA: for x in \`ls /etc/init.d/sernet-*\` ; do \$x start ; done"
        message "DEBIAN SAMBA: for x in \`ls /etc/init.d/samba\` ; do \$x start ; done"
        message " "
        warning " !! Both server and client need nfs spn's "
    fi

    if [ ${SSHD_KERBEROS_ENABLED} = "yes" ]; then
        message "Enable kerborised ssh logins"
        _package_install_no_recommends ssh-krb5 libpam-krb5
        pam-auth-update --package --force
        sed -i '/#GSSAPICleanupCredentials yes/aGSSAPIStoreCredentialsOnRekey yes  # If your version supports this/' /etc/ssh/sshd_config
        sed -i '/#GSSAPICleanupCredentials yes/aGSSAPIKeyExchange yes              # If your version supports this/' /etc/ssh/sshd_config
        sed -i 's/#GSSAPICleanupCredentials yes/GSSAPICleanupCredentials yes/g' /etc/ssh/sshd_config
        sed -i 's/#GSSAPIAuthentication no/GSSAPIAuthentication yes/g' /etc/ssh/sshd_config
        service ssh restart
    fi

    if [ ! -e /etc/systemd/system/nfs-common.service.d/remote-fs-pre.conf ] ; then
        echo "Fixing NFS mount on boot with systemd"
	mkdir -p /etc/systemd/system/nfs-common.service.d
	cat << EOF > /etc/systemd/system/nfs-common.service.d/remote-fs-pre.conf
[Unit]
Before=remote-fs-pre.target
Wants=remote-fs-pre.target

EOF
        fi

else
    error "No server of client variable input"
    error "Exiting now. "
fi
