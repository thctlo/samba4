#!/bin/bash

V="0.2-B1"

# This script is use and tested on a Debian Buster Samba MEMBER
# This is tested with an AD Backend setup.
# https://wiki.samba.org/index.php/Idmap_config_ad
#
# This script will create and setup and configure a basic but secure Samba setup
# ! Not tested on AD-DC's  (yet)
# ! Not tested with RID backends. (yet)
#

# Copyright (C) Louis van Belle 2020

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Into
# This script is/can be used, as an addon, to the samba-setup-share-folders.sh
# This is a simple script to re-apply the rights for the user homedir recusively.
#
# When you move/migrating or setup clean or whatever, you can use this to fix
# some rights. After you copied as Administrator, the user is missing its rights
# on/in there subfolders/files in the homedirs.
# The user needs a UID and "Domain Users" needs a gid, preffered before you run it.

# It tries to use the USER_SDDL from the samba-setup-share-folders.sh script.
# If its not detected, then it will use the same defaults after all.
# It tried to detect the path for the homedirs automaticly.
# if it finds a folder and a mathing user with SID, it will apply the rights.
# any newly created folder by the user in the userhome dir will and up with the
# rights : (POSIX)  username:"domain users"
# Example, a folder created by the user in his homedir.

# getfacl TESTING/
## file: TESTING/
## owner: username
## group: domain\040users
## flags: -s-
#user::rwx
#user:username:rwx
#group::r-x
#group:domain\040users:r-x
#group:domain\040admins:rwx
#mask::rwx
#other::---
#default:user::rwx
#default:user:username:rwx
#default:group::r-x
#default:group:domain\040users:r-x
#default:group:domain\040admins:rwx
#default:mask::rwx
#default:other::---


# Code starts here, it should not be needed to asjust things here.
# Pickup the current location.
START_FOLDER="$(pwd)"
SCRIPT_NAME=$(basename $0)

# You can define the path to the users shared foldere here.
SAMBA_SHARE_USERS=""

# Get the path to where the user folders are from the config files.
if [ -z "$SAMBA_SHARE_USERS" ]
then
    if [ -z "${1}" ]
    then
        SAMBA_SHARE_USERS="$(grep path /etc/samba/*.conf |grep users |grep "path = /" |awk '{ print $NF }' |tail -n1)"
        # did we find the needed settings.
        if [ -z "$SAMBA_SHARE_USERS" ]
        then
            echo "error, unable to detect the users share folder, exiting now."
            echo "This might happing if the users share isn't called users."
            echo "rerun the script: $SCRIPT_NAME /path/to/samba/users"
            exit 1
        fi
    else
        SAMBA_SHARE_USERS="${1}"
    fi
fi

if [ ! -d "${SAMBA_SHARE_USERS}/" ]
then
    echo "error, unable to detect the users share folder in variable : SAMBA_SHARE_USERS"
    echo "rerun the script: $SCRIPT_NAME /path/to/samba/users"
    exit 1
else
    echo "Detected userhomedir basefolder as : ${SAMBA_SHARE_USERS}"
fi

# cd into dir or exit
cd ${SAMBA_SHARE_USERS} || exit 1

for user in $(ls)
do
    # Get the SID of the user.
    NAME2SID="$(wbinfo --name-to-sid $user |awk '{ print $1 }')"
    if [ ! -z "${NAME2SID}" ]
    then
        echo "User: ${user}, SID: ${NAME2SID}"
        if [ -d "${user}" ]
        then
            echo "folder : ${user} detected correctly, apply-ing new rights"
            # Set the correct right on the folder.
            samba-tool ntacl set "O:S-1-22-1-0G:S-1-22-2-0D:AI(A;OICI;0x001301bf;;;${NAME2SID})(A;ID;0x001200a9;;;S-1-22-2-0)(A;OICIIOID;0x001200a9;;;CG)(A;OICIID;0x001f01ff;;;LA)(A;OICIID;0x001f01ff;;;DA)" "${SAMBA_SHARE_USERS}/${user}"

            # but we cant set recursive with samba-tool. (as far i found)            setfacl --recursive --modify user:${user}:rwX,default:user:${user}:rwX "${SAMBA_SHARE_USERS}/${user}"

        else
            echo "Eror, user folder ${SAMBA_SHARE_USERS}/${user} was not detected, skipping!"
        fi
    else
        echo "Usefolder: ${user} exist but unable to find user SID, skipping."
    fi
done

cd ${START_FOLDER} || exit 1

