#!/bin/bash -e

# Version=0.2

# This program is tested on debian Stretch.
# This program is tested on Devuan Jessie.
#
# ! ONLY FOR SAMBA AD DC
# Where samba-tool sysvolreset is broke, this sets the correct rights.
# The base for these rigths is Win2008R2 it's sysvol.

# By Louis van Belle and Rowland Penny.
# or
# By Rowland Penny and Louis van Belle
#  ;-)


# Some Defaults which should never change.
# These are AD SIDs, so I have removed the 'SAMBA'
DC_SERVER_OPERATORS="S-1-5-32-549"
DC_ADMINISTRATORS="S-1-5-32-544"
DC_SYSTEM="S-1-5-18"
DC_AUTHENTICATED_USERS="S-1-5-11"

# apply the change right now, or review it yourself first.
APPLY_CHANGES_DIRECT="no"

Check_Error () {
if [ "$?" -ge 1 ]; then
    echo "error detected"
    echo "exiting now"
    exit 1
fi
}

CMD_WBINFO="$(which wbinfo)"
if [ -z "${CMD_WBINFO}" ]; then
    echo "Cannot find wbinfo."
    echo "Is the winbind package installed ?"
    echo "Cannot continue...Exiting."
    exit 1
fi

# Get path to sysvol from the running config. (debian/samba default: /var/lib/samba/sysvol
DC_SYSVOL_PATH="$(echo "\n" | samba-tool testparm -v | grep sysvol | grep path | grep -v scripts | tail -1 | awk '{ print $NF }')"
if [ ! -d "${DC_SYSVOL_PATH}" ]; then
    echo "Error, sysvol directory detected in your running config does not exist."
    echo "Exiting now, this is impossible, or this is not a AD DC server"
    exit 1
fi

# get info for BUILTIN\Server Operators
Get_DC_SERVER_OPERATORS () {
    DC_SERVER_OPERATORS_SID2UID="$(${CMD_WBINFO} --sid-to-uid=$DC_SERVER_OPERATORS)"
    # result UID (example: 3000001 )

    DC_SERVER_OPERATORS_UID2SID="$(${CMD_WBINFO} --uid-to-sid=$DC_SERVER_OPERATORS_SID2UID)"
    # result SID (uid2sid) (example: S-1-5-32-549 )

    DC_SERVER_OPERATORS_GID2SID="$(${CMD_WBINFO} --gid-to-sid=$DC_SERVER_OPERATORS_SID2UID)"
    # result SID AGAIN (check)  (gid2sid) (example: S-1-5-32-549 )

    DC_SERVER_OPERATORS_SID2NAME="$(${CMD_WBINFO} --sid-to-name=$DC_SERVER_OPERATORS |rev|cut -c3-100|rev)"
    # result NAME (example: BUILTIN\Server Operators )

    DC_SERVER_OPERATORS_NAME2SID=$(${CMD_WBINFO} --name-to-sid="$DC_SERVER_OPERATORS_SID2NAME"| rev|cut -c15-100|rev)
    # result SID (check) (name2sid)
    if [ "$DC_SERVER_OPERATORS_UID2SID" != "$DC_SERVER_OPERATORS_GID2SID" ]; then
        echo "Error, UID2SID and GID2SID are not matching, exiting now."
        exit 1
    fi
    if [ "${DC_SERVER_OPERATORS_NAME2SID}" != "${DC_SERVER_OPERATORS}" ]; then
        echo "Error, NAME2SID and DC_SERVER_OPERATORS are not matching, exiting now."
        echo "The circle check failed, exiting now. "
        exit 1
    fi
    SET_GPO_SERVER_OPER_UID="$DC_SERVER_OPERATORS_SID2UID"
    #SET_GPO_SERVER_OPER_GID="$DC_SERVER_OPERATORS_SID2NAME"
}

# get info for BUILTIN\Administrator
Get_DC_ADMINISTRATORS () {
    DC_ADMINISTRATORS_SID2UID="$(${CMD_WBINFO} --sid-to-uid=$DC_ADMINISTRATORS)"
    DC_ADMINISTRATORS_UID2SID="$(${CMD_WBINFO} --uid-to-sid=$DC_ADMINISTRATORS_SID2UID)"
    DC_ADMINISTRATORS_GID2SID="$(${CMD_WBINFO} --gid-to-sid=$DC_ADMINISTRATORS_SID2UID)"
    DC_ADMINISTRATORS_SID2NAME="$(${CMD_WBINFO} --sid-to-name=$DC_ADMINISTRATORS |rev|cut -c3-100|rev)"
    DC_ADMINISTRATORS_NAME2SID=$(${CMD_WBINFO} --name-to-sid="$DC_ADMINISTRATORS_SID2NAME"| rev|cut -c15-100|rev)
    if [ "$DC_ADMINISTRATORS_UID2SID" != "$DC_ADMINISTRATORS_GID2SID" ]; then
        echo "Error, UID2SID and GID2SID are not matching, exiting now."
        exit 1
    fi
    if [ "${DC_ADMINISTRATORS_NAME2SID}" != "${DC_ADMINISTRATORS}" ]; then
        echo "Error, NAME2SID and DC_ADMINISTRATORS are not matching, exiting now."
        echo "The circle check failed, exiting now. "
        exit 1
    fi
    SET_GPO_ADMINISTRATORS_UID="$DC_ADMINISTRATORS_SID2UID"
    #SET_GPO_ADMINISTRATORS_GID="$DC_ADMINISTRATORS_SID2NAME"
}

# get info for NT Authority\SYSTEM
Get_DC_SYSTEM () {
    DC_SYSTEM_SID2UID="$(${CMD_WBINFO} --sid-to-uid=$DC_SYSTEM)"
    DC_SYSTEM_UID2SID="$(${CMD_WBINFO} --uid-to-sid=$DC_SYSTEM_SID2UID)"
    DC_SYSTEM_GID2SID="$(${CMD_WBINFO} --gid-to-sid=$DC_SYSTEM_SID2UID)"
    #DC_SYSTEM_SID2NAME="$(${CMD_WBINFO} --sid-to-name=$DC_SYSTEM |rev|cut -c3-100|rev)"
    # name2sid does not work for SYSTEM
    if [ "$DC_SYSTEM_UID2SID" != "$DC_SYSTEM_GID2SID" ]; then
        echo "Error, UID2SID and GID2SID are not matching, exiting now."
        exit 1
    fi
    # I have rewritten the following 'if', you dont need to test both
    # they have been tested against each other above.
    #if [ "${DC_SYSTEM_GID2SID}" != "${DC_SYSTEM}" ]||[ "${DC_SYSTEM_UID2SID}" != "${DC_SYSTEM}" ] ; then
    if [ "${DC_SYSTEM_GID2SID}" != "${DC_SYSTEM}" ]; then
        echo "Error, GID2SID/UID2SID and DC_SYSTEM are not matching, exiting now."
        echo "The circle check failed, exiting now. "
        exit 1
    fi
    SET_GPO_SYSTEM_UID="$DC_SYSTEM_SID2UID"
    #SET_GPO_SYSTEM_GID="$DC_SYSTEM_SID2NAME"
}

# get info for NT Authority\Authenticated Users
Get_DC_AUTHENTICATED_USERS () {
    DC_AUTHENTICATED_USERS_SID2UID="$(${CMD_WBINFO} --sid-to-uid=$DC_AUTHENTICATED_USERS)"
    DC_AUTHENTICATED_USERS_UID2SID="$(${CMD_WBINFO} --uid-to-sid=$DC_AUTHENTICATED_USERS_SID2UID)"
    DC_AUTHENTICATED_USERS_GID2SID="$(${CMD_WBINFO} --gid-to-sid=$DC_AUTHENTICATED_USERS_SID2UID)"
    #DC_AUTHENTICATED_USERS_SID2NAME="$(${CMD_WBINFO} --sid-to-name=$DC_AUTHENTICATED_USERS |rev|cut -c3-100|rev)"
    # name2sid does not work for Authenticated Users
    if [ "$DC_AUTHENTICATED_USERS_UID2SID" != "$DC_AUTHENTICATED_USERS_GID2SID" ]; then
        echo "Error, UID2SID and GID2SID are not matching, exiting now."
        exit 1
    fi
    # rewritten as per above function
    #if [ "${DC_AUTHENTICATED_USERS_GID2SID}" != "${DC_AUTHENTICATED_USERS}" ]||[ "${DC_AUTHENTICATED_USERS_UID2SID}" != "${DC_AUTHENTICATED_USERS}" ] ; then
    if [ "${DC_AUTHENTICATED_USERS_GID2SID}" != "${DC_AUTHENTICATED_USERS}" ]; then
        echo "Error, GID2SID/UID2SID and DC_AUTHENTICATED_USERS are not matching, exiting now."
        echo "The circle check failed, exiting now. "
        exit 1
    fi
    SET_GPO_AUTHEN_USERS_UID="$DC_AUTHENTICATED_USERS_SID2UID"
    #SET_GPO_AUTHEN_USERS_GID="$DC_AUTHENTICATED_USERS_SID2NAME"
}

# TODO (check/set) implement starting rights for sysvol (if not default )
# first, set the sysvol rights.
# ( root:root )
# On A 2012R2 DC the owner & group are: O:BA G:SY
# BA = BUILTIN\Administrators
# SY = SYSTEM
# ( Creator owner )
#chmod 1770 ${DC_SYSVOL_PATH}
# ( creator group )
#chmod 2770 ${DC_SYSVOL_PATH}
# ( creator owner and group )
#chmod 3770 ${DC_SYSVOL_PATH}

#TODO(option,check/set), change share, include ignore system acl



Create_DC_SYVOL_ACL_FILE () {
    Get_DC_SERVER_OPERATORS
    Get_DC_ADMINISTRATORS
    Get_DC_SYSTEM
    Get_DC_AUTHENTICATED_USERS

    RIGHTSFILE="default-rights-sysvol.acl"
    cat << EOF > "${RIGHTSFILE}"
# file: ${DC_SYSVOL_PATH}
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
}

Apply_DC_SYVOL_ACL_FILE () {
    setfacl -R -b --modify-file "${RIGHTSFILE}" "${DC_SYSVOL_PATH}"
    if [ "$?" -eq 0 ]; then
        rm -rf "${RIGHTSFILE}"
        echo " "
    else
        echo "An error occurred!"
        echo "See ${RIGHTSFILE}"
        echo "Exiting..."
        exit 1
    fi

    # and make sure your domain Admin and local adminsitrator always have access.
    setfacl -R -m default:user:root:rwx "${DC_SYSVOL_PATH}"
    setfacl -R -m default:group:"${SET_GPO_ADMINISTRATORS_UID}":rwx "${DC_SYSVOL_PATH}"
}

Show_Info () {
    cat <<EOF
The sysvol ACLS info.....

Please check your share rights for sysvol from within windows.
If these are incorrect, correct them and run this script again.
Set your sysvol SHARE permissions as followed.
EVERYONE: READ
Authenticated Users: FULL CONTROL
(BUILTIN or NTDOM)\Administrators: FULL CONTROL
(BUILTIN or NTDOM)\SYSTEM, FULL CONTROL
User/Group system is added compaired to a win2008R2 sysvol, you need this for some GPO settings.

Set your sysvol FOLDER permissions as followed.
Authenticated Users: Read & Exec, Show folder content, Read
(BUILTIN or NTDOM)\Administrators: FULL CONTROL
(BUILTIN or NTDOM)\SYSTEM, FULL CONTROL
EOF
}

# Program.
Create_DC_SYVOL_ACL_FILE
if [ "${APPLY_CHANGES_DIRECT}" = "yes" ]; then 
    Apply_DC_SYVOL_ACL_FILE
else
    echo "Review the file : default-rights-sysvol.acl, these contains the defaults for sysvol."
fi

Show_Info
