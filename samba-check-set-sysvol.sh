#!/bin/bash -e

# Version=0.01

# This program is tested on debian Stretch.
#
# ! ONLY FOR SAMBA AD DC
# Where samba-tool sysvolreset is broke, this sets the correct rights.
# The base for these rigths is Win2008R2 it's sysvol.

# By Louis van Belle and Rowland Penny.
# or
# By Rowland Penny and Louis van Belle
# Questions, mail the samba mailinglist.


# samba-tool ntacl sysvolreset/sysvolcheck errors out. 
# you can setup/reset it with this script. 

# Some Defaults which should never change.
SAMBA_DC_SERVER_OPERATORS="S-1-5-32-549"
SAMBA_DC_ADMINISTRATORS="S-1-5-32-544"
SAMBA_DC_SYSTEM="S-1-5-18"
SAMBA_DC_AUTHENTICATED_USERS="S-1-5-11"


Check_Error () {
if [ "$?" -ge 1 ]; then
    echo "error detected"
    echo "exiting now"
    exit 1
fi
}

CMD_LDBSEARCH=$(which ldbsearch)
if [ -z "${CMD_LDBSEARCH}" ]; then
    echo "Cannot find ldbsearch."
    echo "Is the ldb-tools package installed ?"
    echo "Cannot continue...Exiting."
    exit 1
fi

CMD_WBINFO="$(which wbinfo)"
if [ -z "${CMD_WBINFO}" ]; then
    echo "Cannot find wbinfo."
    echo "Is the winbind package installed ?"
    echo "Cannot continue...Exiting."
    exit 1
fi

## Get the SAMBA PRIVATE dir. ( debian: /var/lib/samba/private )
SAMBAPRIVDIR=$(samba -b | grep 'PRIVATE_DIR' | awk '{print $NF}')
if [ ! -d "$SAMBAPRIVDIR" ]; then
    echo "Error detected, samba -b detected Value : PRIVATE_DIR: $SAMBAPRIVDIR"
    echo "But the directory does not exists, exiting now. "
    exit 1
elif [ ! -f "$SAMBAPRIVDIR/idmap.ldb" ]; then
    echo "Error detected, $SAMBAPRIVDIR/idmap.ldb does not exist."
    exit 1
else
    LDBDB="$SAMBAPRIVDIR/idmap.ldb"
fi

# Get path to sysvol from the running config. (debian/samba default: /var/lib/samba/sysvol
SAMBA_DC_PATH_SYSVOL="$(echo "\n" | samba-tool testparm -v | grep sysvol | grep path | grep -v scripts | tail -1 | awk '{ print $NF }')"
if [ ! -d "${SAMBA_DC_PATH_SYSVOL}" ]; then
    echo "Error, directory does not exist, but this is detected in your running config."
    echo "Exiting now, this is impossible, or this is not a AD DC server"
    exit 1
fi

SAMBA_DC_WORKGROUPNAME="$(echo "\n" | samba-tool testparm -v | grep workgroup | tail -1 | awk '{ print $NF }')"
SAMBA_DC_DOMAIN_SID="$(${CMD_WBINFO} -D $SAMBA_DC_WORKGROUPNAME | grep SID | awk '{ print $NF }')"



# get info for BUILTIN\Server Operators
Get_SAMBA_DC_SERVER_OPERATORS () {

SAMBA_DC_SERVER_OPERATORS_SID2UID="$(${CMD_WBINFO} --sid-to-uid=$SAMBA_DC_SERVER_OPERATORS)"
# result UID (example: 3000001 )

SAMBA_DC_SERVER_OPERATORS_UID2SID="$(${CMD_WBINFO} --uid-to-sid=$SAMBA_DC_SERVER_OPERATORS_SID2UID)"
# result SID (uid2sid) (example: S-1-5-32-549 )

SAMBA_DC_SERVER_OPERATORS_GID2SID="$(${CMD_WBINFO} --gid-to-sid=$SAMBA_DC_SERVER_OPERATORS_SID2UID)"
# result SID AGAIN (check)  (gid2sid) (example: S-1-5-32-549 )

SAMBA_DC_SERVER_OPERATORS_SID2NAME="$(${CMD_WBINFO} --sid-to-name=$SAMBA_DC_SERVER_OPERATORS |rev|cut -c3-100|rev)"
# result NAME (example: BUILTIN\Server Operators )

SAMBA_DC_SERVER_OPERATORS_NAME2SID=$(${CMD_WBINFO} --name-to-sid="$SAMBA_DC_SERVER_OPERATORS_SID2NAME"| rev|cut -c15-100|rev)
# result SID (check) (name2sid)
if [ "$SAMBA_DC_SERVER_OPERATORS_UID2SID" != "$SAMBA_DC_SERVER_OPERATORS_GID2SID" ]; then
    echo "Error, UID2SID and GID2SID are not matching, exiting now."
    exit 1
fi
if [ "${SAMBA_DC_SERVER_OPERATORS_NAME2SID}" != "${SAMBA_DC_SERVER_OPERATORS}" ]; then
    echo "Error, NAME2SID and SAMBA_DC_SERVER_OPERATORS are not matching, exiting now."
    echo "The circle check failed, exiting now. "
    exit 1
fi
SET_GPO_SERVER_OPER_UID="$SAMBA_DC_SERVER_OPERATORS_SID2UID"
SET_GPO_SERVER_OPER_GID="$SAMBA_DC_SERVER_OPERATORS_SID2NAME"
}

# get info for BUILTIN\Administrator
Get_SAMBA_DC_ADMINISTRATORS () {
SAMBA_DC_ADMINISTRATORS_SID2UID="$(${CMD_WBINFO} --sid-to-uid=$SAMBA_DC_ADMINISTRATORS)"
SAMBA_DC_ADMINISTRATORS_UID2SID="$(${CMD_WBINFO} --uid-to-sid=$SAMBA_DC_ADMINISTRATORS_SID2UID)"
SAMBA_DC_ADMINISTRATORS_GID2SID="$(${CMD_WBINFO} --gid-to-sid=$SAMBA_DC_ADMINISTRATORS_SID2UID)"
SAMBA_DC_ADMINISTRATORS_SID2NAME="$(${CMD_WBINFO} --sid-to-name=$SAMBA_DC_ADMINISTRATORS |rev|cut -c3-100|rev)"
SAMBA_DC_ADMINISTRATORS_NAME2SID=$(${CMD_WBINFO} --name-to-sid="$SAMBA_DC_ADMINISTRATORS_SID2NAME"| rev|cut -c15-100|rev)
if [ "$SAMBA_DC_ADMINISTRATORS_UID2SID" != "$SAMBA_DC_ADMINISTRATORS_GID2SID" ]; then
    echo "Error, UID2SID and GID2SID are not matching, exiting now."
    exit 1
fi
if [ "${SAMBA_DC_ADMINISTRATORS_NAME2SID}" != "${SAMBA_DC_ADMINISTRATORS}" ]; then
    echo "Error, NAME2SID and SAMBA_DC_ADMINISTRATORS are not matching, exiting now."
    echo "The circle check failed, exiting now. "
    exit 1
fi
SET_GPO_ADMINISTRATORS_UID="$SAMBA_DC_ADMINISTRATORS_SID2UID"
SET_GPO_ADMINISTRATORS_GID="$SAMBA_DC_ADMINISTRATORS_SID2NAME"
}

# get info for NT Authority\SYSTEM
Get_SAMBA_DC_SYSTEM () {
SAMBA_DC_SYSTEM_SID2UID="$(${CMD_WBINFO} --sid-to-uid=$SAMBA_DC_SYSTEM)"
SAMBA_DC_SYSTEM_UID2SID="$(${CMD_WBINFO} --uid-to-sid=$SAMBA_DC_SYSTEM_SID2UID)"
SAMBA_DC_SYSTEM_GID2SID="$(${CMD_WBINFO} --gid-to-sid=$SAMBA_DC_SYSTEM_SID2UID)"
SAMBA_DC_SYSTEM_SID2NAME="$(${CMD_WBINFO} --sid-to-name=$SAMBA_DC_SYSTEM |rev|cut -c3-100|rev)"
# name2sid does not work for SYSTEM
if [ "$SAMBA_DC_SYSTEM_UID2SID" != "$SAMBA_DC_SYSTEM_GID2SID" ]; then
    echo "Error, UID2SID and GID2SID are not matching, exiting now."
    exit 1
fi
if [ "${SAMBA_DC_SYSTEM_GID2SID}" != "${SAMBA_DC_SYSTEM}" ]||[ "${SAMBA_DC_SYSTEM_UID2SID}" != "${SAMBA_DC_SYSTEM}" ] ; then
    echo "Error, GID2SID/UID2SID and SAMBA_DC_SYSTEM are not matching, exiting now."
    echo "The circle check failed, exiting now. "
#    exit 1
fi
SET_GPO_SYSTEM_UID="$SAMBA_DC_SYSTEM_SID2UID"
SET_GPO_SYSTEM_GID="$SAMBA_DC_SYSTEM_SID2NAME"
}

# get info for NT Authority\Authenticated Users
Get_SAMBA_DC_AUTHENTICATED_USERS () {
SAMBA_DC_AUTHENTICATED_USERS_SID2UID="$(${CMD_WBINFO} --sid-to-uid=$SAMBA_DC_AUTHENTICATED_USERS)"
SAMBA_DC_AUTHENTICATED_USERS_UID2SID="$(${CMD_WBINFO} --uid-to-sid=$SAMBA_DC_AUTHENTICATED_USERS_SID2UID)"
SAMBA_DC_AUTHENTICATED_USERS_GID2SID="$(${CMD_WBINFO} --gid-to-sid=$SAMBA_DC_AUTHENTICATED_USERS_SID2UID)"
SAMBA_DC_AUTHENTICATED_USERS_SID2NAME="$(${CMD_WBINFO} --sid-to-name=$SAMBA_DC_AUTHENTICATED_USERS |rev|cut -c3-100|rev)"
# name2sid does not work for Authenticated Users
if [ "$SAMBA_DC_AUTHENTICATED_USERS_UID2SID" != "$SAMBA_DC_AUTHENTICATED_USERS_GID2SID" ]; then
    echo "Error, UID2SID and GID2SID are not matching, exiting now."
    exit 1
fi
if [ "${SAMBA_DC_AUTHENTICATED_USERS_GID2SID}" != "${SAMBA_DC_AUTHENTICATED_USERS}" ]||[ "${SAMBA_DC_AUTHENTICATED_USERS_UID2SID}" != "${SAMBA_DC_AUTHENTICATED_USERS}" ] ; then
    echo "Error, GID2SID/UID2SID and SAMBA_DC_AUTHENTICATED_USERS are not matching, exiting now."
    echo "The circle check failed, exiting now. "
#    exit 1
fi
SET_GPO_AUTHEN_USERS_UID="$SAMBA_DC_AUTHENTICATED_USERS_SID2UID"
SET_GPO_AUTHEN_USERS_GID="$SAMBA_DC_AUTHENTICATED_USERS_SID2NAME"
}

# Todo,(check/set) implement starting rights for sysvol (if not default )
# first, set the sysvol rights.
# ( root:root )
# ( Creator owner )
#chmod 1770 ${SAMBA_DC_PATH_SYSVOL}
# ( creator group )
#chmod 2770 ${SAMBA_DC_PATH_SYSVOL}
# ( creator owner and group )
#chmod 3770 ${SAMBA_DC_PATH_SYSVOL}

#TODO(option,check/set), change share, include ignore system acl


Get_SAMBA_DC_SERVER_OPERATORS
Get_SAMBA_DC_ADMINISTRATORS
Get_SAMBA_DC_SYSTEM
Get_SAMBA_DC_AUTHENTICATED_USERS

RIGHTSFILE="default-rights-sysvol.acl"

cat << EOF > "${RIGHTSFILE}"
# file: ${SAMBA_DC_PATH_SYSVOL}
# owner: root
# group: root
user::rwx
user:root:rwx
user:${SET_GPO_ADMINISTRATORS_UID}:rwx
user:${SET_GPO_SERVER_OPER_UID}:r-x
user:${SET_GPO_SYSTEM_UID}:rwx
user:${SET_GPO_AUTHEN_USERS_UID}:r-x
group::rwx
group:${SET_GPO_ADMINISTRATORS_UID}:rwx
group:${SET_GPO_SERVER_OPER_UID}:r-x
group:${SET_GPO_SYSTEM_UID}:rwx
group:${SET_GPO_AUTHEN_USERS_UID}:r-x
mask::rwx
other::---
default:user::rwx
default:user:root:rwx
default:user:${SET_GPO_ADMINISTRATORS_UID}:rwx
default:user:${SET_GPO_SERVER_OPER_UID}:r-x
default:user:${SET_GPO_SYSTEM_UID}:rwx
default:user:${SET_GPO_AUTHEN_USERS_UID}:r-x
default:group::---
default:group:${SET_GPO_ADMINISTRATORS_UID}:rwx
default:group:${SET_GPO_SERVER_OPER_UID}:r-x
default:group:${SET_GPO_SYSTEM_UID}:rwx
default:group:${SET_GPO_AUTHEN_USERS_UID}:r-x
default:mask::rwx
default:other::---
EOF

setfacl -R -b --modify-file "${RIGHTSFILE}" "${SAMBA_DC_PATH_SYSVOL}"
if [ "$?" -eq 0 ]; then
    rm -rf "${RIGHTSFILE}"
    echo " "
else
    echo "An error occurred!"
    echo "See ${RIGHTSFILE}"
    echo "Exiting..."
    exit 1
fi

# and make sure you domain Admin and local adminsitrator always have access.
setfacl -R -m default:user:root:rwx "${SAMBA_DC_PATH_SYSVOL}"
setfacl -R -m default:group:"${SET_GPO_ADMINISTRATORS_UID}":rwx "${SAMBA_DC_PATH_SYSVOL}"

echo "Your sysvol is reset....."
echo " "
echo "Please check you share rights also for sysvol from within windows."
echo "If these are incorrect, correct them and run this script again."
echo "Set your sysvol SHARE permissions as followed. "
echo "EVERYONE: READ"
echo "Authenticated Users: FULL CONTROL"
echo "(BUILTIN or NTDOM)\Administrators: FULL CONTROL"
echo "(BUILTIN or NTDOM)\SYSTEM, FULL CONTROL"
echo "User/Group system is added compaired to a win2008R2 sysvol, you need this for some GPO settings."
echo " "
echo "Set your sysvol FOLDER permissions as followed. "
echo "Authenticated Users: Read & Exec, Show folder content, Read"
echo "(BUILTIN or NTDOM)\Administrators: FULL CONTROL"
echo "(BUILTIN or NTDOM)\SYSTEM, FULL CONTROL"
