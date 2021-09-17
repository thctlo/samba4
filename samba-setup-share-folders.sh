#!/bin/bash

V="0.8-B6"

# This script is use and tested on a Debian Buster Samba MEMBER
# This is tested with and AD Backend.
# https://wiki.samba.org/index.php/Idmap_config_ad
#
# This script will create and setup and configure a basic but secure Samba setup
# ! Not tested on AD-DC's  (yet)
# ! Not tested with RID backends. (yet)
#

#
# BEFORE YOU RUN THIS SCRIPT, THERE ARE A FEW OBLIGATED THINGS TODO FIRST.
# 1) The group "Domain Uses" MUST have a GID assigned.
# 2) There might be more points .. ;-) if i have them, they will be added here.

# Copyright (C) Louis van Belle 2021
# Special thanks to :
# Rowland Penny @samba.org
# Robert E. Wooden @donelsontrophy.com
#
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
# The script will create some default folders and setup rights and a shares.conf files
# which can be used to setup your server shares.
# This setup also assumes your running this on a DOMAIN MEMBER.
# Below is has been tested on a Debian Buster with Samba 4.12.5

# Adviced, if you "DISK" is /dev/sdaX and your mounting it in /somefolder
# You always create a subfolder and you put your data in that.
# Dont use the disk its root. like dont mount /dev/sdaX into /samba
# use mount it for example in /srv and create the folder samba.
# And sure it works, but if you setting up more advanced, it will bite you.
# We try to setup as compatible as we can.

# Adjust the below variables to your needs.
# Read the text in the functions why.  (todo, make this part better.)

## The folder for all your Samba/Windows stuff.
## Default created with root:root 4775 rights. ( see tekst in: function SambaRootFolder)
SAMBA_BASEFOLDER="/srv/samba"
# Override the default rights for the samba base folder. (empty=default 4775)
SAMBA_BASEFOLDER_CHMOD=""

## The share name for "companydata" the folder with all you company data.
SAMBA_SHARE_COMPDATA="companydata"
# Override the default rights for the users folder (empty=default 3750)
SAMBA_SHARE_COMPDATA_CHMOD=""

## The share name for and will contain all the \"windows\" users there homedirs.
SAMBA_SHARE_USERS="users"
# Override the default rights for the users folder (empty=default 2750)
SAMBA_SHARE_USERS_CHMOD=""

## The share name with will contain all \"windows\" users there profiles.
SAMBA_SHARE_USERSPROFILES="profiles"
# Override the default rights for the profile folder (empty=default 1750)
SAMBA_SHARE_USERSPROFILES_CHMOD=""

## The share with will be open for all Domain Users.
## Adminstrators control the Share/Folder rights,
## Domain Users can create/write folders/files here.
SAMBA_SHARE_COMPPUBLIC="public"
# Override the default rights for the profile folder (empty=default 4770)
SAMBA_SHARE_COMPPUBLIC_CHMOD=""

####### Dont adjust below here, should not be needed.  ########
## Program Variables
SAMBA_BASE="${SAMBA_BASEFOLDER}"
SAMBA_BASE_CHMOD="${SAMBA_BASEFOLDER_CHMOD:-4775}"
SAMBA_COMPDATA_CHMOD="${SAMBA_SHARE_COMPDATA_CHMOD:-3750}"
SAMBA_USERS_CHMOD="${SAMBA_SHARE_USERS_CHMOD:-2750}"
SAMBA_USERSPROFILES_CHMOD="${SAMBA_SHARE_USERSPROFILES_CHMOD:-1750}"
SAMBA_COMPPUBLIC_CHMOD="${SAMBA_SHARE_COMPPUBLIC_CHMOD:-4770}"

# clear screen
clear

## Program functions
function SambaRootFolder(){
# Finished.
INFO="     This is the Administrative share for admins or folder managers only.
#
# Group Everyone needs read-execute on /srv/samba or you cant enter the server (\\server.fqdn )
# 4775: 4=creator owner and creator group, where creator group is always and
# end up in \"Domain Users\" (primary group) when your windows users write files on the share.
# Only Administrator or \"Domain Admins\" members are allowed to create folders here.
# The underlaying folder will be the samba shares your \"domain users\" will be using.
# (or add a folder manager group for it.)
# The !root = DOM\Administrator DOM\administrator, makes this work, so dont forget the usermapping file in smb.conf
########################################################"

if [ ! -d "${SAMBA_BASE}" ]
then
    install -oroot -groot -m"${SAMBA_BASE_CHMOD}" -d "${SAMBA_BASE}"
    echo "########################################################"
    echo "     Notice, creating ${SAMBA_BASE} with rights ${SAMBA_BASE_CHMOD}"
    echo "     This share can be accessed as Administrator or as a member of Domain Admins share: \\\\$(hostname -f)\samba\$"
    echo "${INFO}"
    echo

else
    echo "########################################################"
    echo "     Warning: ${SAMBA_BASE} already exist"
    echo "     Try to accesse the share as Adminsitrator or as a member of Domain Admins share: \\\\$(hostname -f)\samba\$"
    echo "     And verify if this share is set as [samba\$] in smb.conf"
    echo
    echo "${INFO}"
    echo
fi
unset INFO
}

function SambaShare_companydata(){
# Finished.
INFO="     This is the Administrative share for the companydata.
#
# Company Data, This one uses \"Domain Users\" (primary group) and is used to allow all \"Domain Users\"
# to modify the data, we assume you are creating department groups and folders.
# accessing these folders needs (example) to me a member of \"groupX\" and created files are owned by group \"Domain Users\"
# This way folders are protected and everybody can read/write in it, depending if you member of GroupX or not.
#
# Example in samba/Windows Explorer \\server.fqdn\companydata.
# The members of Domain Admins, can create the subfolder and set the needed rights on these subfolders.
# \\\\server.fqdn\companydata\dep1, security group dep1.
# \\\\server.fqdn\companydata\dep2, security group dep2.
# rights, 3750 is base, 3Creater Group. 7user(root) 5group(root) 0(world/everyone)
# The \"!root = NTDOM\Administrator NTDOM\administrator\", makes this work, so dont forget the usermapping file in smb.conf
# Administrator or a member of Domain Admins/Foldermanagers, will be needed to create the subfolder.
# Folder managers needs to be setup by yourself, the script does not do it for you.
#
# Setup the departments folders, all groups needs a GID, assign these BEFORE you assign the rights.!!!
# And assign \"Domain Users \" a GID, this is strongly adviced/obligated in my optinion.
# wbinfo --name-to-sid groupname_here
# Add the output (SID) of the above command here in this, replace PUT_THE_SID_HERE
#
# run : samba-tool ntacl set \"O:S-1-22-1-0G:S-1-22-2-0D:AI(A;OICI;0x001301bf;;;PUT_THE_SID_HERE)(A;ID;0x001200a9;;;S-1-22-2-0)(A;OICIIOID;0x001200a9;;;CG)(A;OICIID;0x001f01ff;;;LA)(A;OICIID;0x001f01ff;;;DA)\" \"${SAMBA_BASE}/${SAMBA_SHARE_COMPDATA}/department1\"
#
# verify the rights (as user NTDOM\Administrator) on the security tab in Windows Explorer and test.
# An example can be : samba-tool ntacl set \"O:S-1-22-1-0G:S-1-22-2-0D:AI(A;OICI;0x001301bf;;;\$(wbinfo --name-to-sid department1_HERE |awk '{ print \$1 }'))(A;ID;0x001200a9;;;S-1-22-2-0)(A;OICIIOID;0x001200a9;;;CG)(A;OICIID;0x001f01ff;;;LA)(A;OICIID;0x001f01ff;;;DA)\" \"/srv/samba/${SAMBA_SHARE_COMPDATA}/department1/\"
########################################################"
if [ ! -d "${SAMBA_BASE}/${SAMBA_SHARE_COMPDATA}" ]
then
    ## With folder OWNER Administrator : O:LAG:S-1-22-2-0D:PAI(A;OICIIO;0x001200a9;;;CG)(A;OICI;0x001f01ff;;;LA)(A;OICI;0x001f01ff;;;DA)(A;;0x001200a9;;;DU)
    ## With folder OWNER root        : O:S-1-22-1-0G:S-1-22-2-0D:PAI(A;OICIIO;0x001200a9;;;CG)(A;OICI;0x001f01ff;;;LA)(A;OICI;0x001f01ff;;;DA)(A;;0x001200a9;;;DU)
    ## Default is set to : Administrator
    COMPDATA_SDDL="O:LAG:S-1-22-2-0D:PAI(A;OICIIO;0x001200a9;;;CG)(A;OICI;0x001f01ff;;;LA)(A;OICI;0x001f01ff;;;DA)(A;;0x001200a9;;;DU)"
    #COMPDATA_SDDL="O:S-1-22-1-0G:S-1-22-2-0D:PAI(A;OICIIO;0x001200a9;;;CG)(A;OICI;0x001f01ff;;;LA)(A;OICI;0x001f01ff;;;DA)(A;;0x001200a9;;;DU)"

    install -oroot -groot -m"${SAMBA_COMPDATA_CHMOD}" -d "${SAMBA_BASE}/${SAMBA_SHARE_COMPDATA}"
    samba-tool ntacl set "${COMPDATA_SDDL}" "${SAMBA_BASE}/${SAMBA_SHARE_COMPDATA}"

    echo "########################################################"
    echo "     Notice, creating ${SAMBA_BASE}/${SAMBA_SHARE_COMPDATA} with rights ${SAMBA_COMPDATA_CHMOD}"
    echo "     This share can be accessed as Administrator or as a member of Domain Users share: \\\\$(hostname -f)\\${SAMBA_SHARE_COMPDATA}"
    echo
    echo "${INFO}"
    echo
else
    echo "########################################################"
    echo "     Warning: ${SAMBA_BASE}/${SAMBA_SHARE_COMPDATA} already exist."
    echo "     Try to accesse the share as Adminsitrator or as a member of Domain Admins share: \\\\$(hostname -f)\\${SAMBA_SHARE_COMPDATA}"
    echo "     And verify if this share is set as [${SAMBA_SHARE_COMPDATA}] in smb.conf"
    echo
    echo "${INFO}"
    echo
fi
unset INFO
unset COMPDATA_SDDL
}

function SambaShare_users(){
# Finished.
INFO="     User folder setup.
# The rights are already setup for you. Review these from within a Windows Client.
# You can now set in ADUC \\\\server.fqdn\users\%username% for the homedir drive mapping
# The new created folder from ADUC, wil get username:root add default rights.
# Only the user and Adminstrator(s) are allowed in an user there home folder.
#
# If you make the HomeDir Private for the user only. ( so not by root accessable ).
# And if you use kerberos auth with NFS(v4), you might need to add this to
#     #/etc/krb5.conf in [libdefaults]
#     # Source: https://bugs.launchpad.net/ubuntu/+source/heimdal/+bug/1484262
#     # ignore the attempt to read $HOME/.k5login by or running services (as root)
#     # The Automounter needs it, dont forget adding the nfs/spn to the keytab file.
#     ignore_k5login = true
#
# More info : https://wiki.samba.org/index.php/User_Home_Folders
########################################################"

if [ ! -d "${SAMBA_BASE}/${SAMBA_SHARE_USERS}" ]
then
    ## With folder OWNER Administrator : O:LAG:S-1-22-2-0D:PAI(A;;0x001200a9;;;BU)(A;OICIIO;0x001f01ff;;;CO)(A;OICI;0x001f01ff;;;SY)(A;OICI;0x001f01ff;;;BA)
    ## With folder OWNER root          : O:S-1-22-1-0G:S-1-22-2-0D:PAI(A;;0x001200a9;;;BU)(A;OICIIO;0x001f01ff;;;CO)(A;OICI;0x001f01ff;;;SY)(A;OICI;0x001f01ff;;;BA)
    ## Default is set to : Administrator
    USER_SDDL="O:LAG:S-1-22-2-0D:PAI(A;;0x001200a9;;;BU)(A;OICIIO;0x001f01ff;;;CO)(A;OICI;0x001f01ff;;;SY)(A;OICI;0x001f01ff;;;BA)"
    #USER_SDDL="O:S-1-22-1-0G:S-1-22-2-0D:PAI(A;;0x001200a9;;;BU)(A;OICIIO;0x001f01ff;;;CO)(A;OICI;0x001f01ff;;;SY)(A;OICI;0x001f01ff;;;BA)"

    install -oroot -groot -m"${SAMBA_USERS_CHMOD}" -d "${SAMBA_BASE}/${SAMBA_SHARE_USERS}"
    samba-tool ntacl set "${USER_SDDL}" "${SAMBA_BASE}/${SAMBA_SHARE_USERS}"

    echo "########################################################"
    echo "     Notice, creating ${SAMBA_BASE}/${SAMBA_SHARE_USERS} with rights ${SAMBA_USERS_CHMOD}"
    echo "     Set in ADUC USERHOME DRIVELETTER:  \\\\$(hostname -f)\\${SAMBA_SHARE_USERS}\%username%"
    echo
    echo "${INFO}"
    echo
else
    echo "########################################################"
    echo "     Warning: ${SAMBA_BASE}/${SAMBA_SHARE_USERS} already exist."
    echo "     Try to accesse the share as Adminsitrator or as a member of Domain Admins share: \\\\$(hostname -f)\\${SAMBA_SHARE_USERS}"
    echo "     And verify if this share is set as [${SAMBA_SHARE_USERS}] in smb.conf"
    echo
    echo "${INFO}"
    echo
fi
unset INFO
unset USER_SDDL
}

function SambaShare_profiles(){
INFO="     This is the share setup for the Windows Users (and optional computer ) there profiles
# Profile folder setup, there is a setup for the user profiles AND computer profiles.
# for the computer profiles please read also this link.
# https://docs.microsoft.com/en-us/windows-server/storage/folder-redirection/deploy-roaming-user-profiles#step-4-optionally-create-a-gpo-for-roaming-user-profiles
#
# Note, \"Domain Users\" is used in this setup, the link of Microsoft above used a different group because it shows the setup for computer profiles.
# Both work, you can change this later if needed and/or add it, if added, you most probely want to change this setup also a little bit.
# Just follow the Microsoft link
#
# Domain users include also all computer, but in cased you dont want that (think laptops), setup as above link suggested.
# Replace \"Domain Users\" for the assigned security group and dont forget to add the users and the computers.
#
# This samba-tool command will result in whats shown here:
# More info : https://wiki.samba.org/index.php/Roaming_Windows_User_Profiles
########################################################"

if [ ! -d "${SAMBA_BASE}/${SAMBA_SHARE_USERSPROFILES}" ]
then
    ## With folder OWNER Administrator  : O:LAG:S-1-22-2-0D:PAI(A;OICIIO;0x001f01ff;;;CO)(A;OICI;0x001f01ff;;;SY)(A;OICI;0x001f01ff;;;DA)(A;;0x00100025;;;DU)
    ## With folder OWNER root           : O:S-1-22-1-0G:S-1-22-2-0D:PAI(A;OICIIO;0x001f01ff;;;CO)(A;OICI;0x001f01ff;;;SY)(A;OICI;0x001f01ff;;;DA)(A;;0x00100025;;;DU)
    ## Default is set to : Adminisitrator
    PROFILE_SDDL="O:LAG:S-1-22-2-0D:PAI(A;OICIIO;0x001f01ff;;;CO)(A;OICI;0x001f01ff;;;SY)(A;OICI;0x001f01ff;;;DA)(A;;0x00100025;;;DU)"
    #PROFILE_SDDL="O:S-1-22-1-0G:S-1-22-2-0D:PAI(A;OICIIO;0x001f01ff;;;CO)(A;OICI;0x001f01ff;;;SY)(A;OICI;0x001f01ff;;;DA)(A;;0x00100025;;;DU)"

    install -oroot -groot -m"${SAMBA_USERSPROFILES_CHMOD}" -d "${SAMBA_BASE}/${SAMBA_SHARE_USERSPROFILES}"
    samba-tool ntacl set "${PROFILE_SDDL}" "${SAMBA_BASE}/${SAMBA_SHARE_USERSPROFILES}"

    echo "########################################################"
    echo "     Notice, creating ${SAMBA_BASE}/${SAMBA_SHARE_USERSPROFILES} with rights ${SAMBA_USERPROFILES_CHMOD}"
    echo "     Set in ADUC USERPROFILE:  \\\\$(hostname -f)\\${SAMBA_SHARE_USERSPROFILES}\%username%"
    echo
    echo "${INFO}"
    echo
else
    echo "########################################################"
    echo "     Warning: ${SAMBA_BASE}/${SAMBA_SHARE_USERSPROFILES} already exist."
    echo "     Try to accesse the share as Adminsitrator or as a member of Domain Admins share: \\\\$(hostname -f)\\${SAMBA_SHARE_USERSPROFILES}"
    echo "     And verify if this share is set as [${SAMBA_SHARE_USERSPROFILES}] in smb.conf"
    echo
    echo "${INFO}"
    echo
fi
unset INFO
unset PROFILE_SDDL
}

function SambaShare_public(){
INFO="    Public folder setup.
#
# By default \"Domain users\" are allowed to read/write create files and folders.
# By default \"Domain Admins\" Full control.
# Pretty simple setup ;-)
# More info : https://wiki.samba.org/index.php/Setting_up_a_Share_Using_Windows_ACLs
########################################################"

if [ ! -d "${SAMBA_BASE}/${SAMBA_SHARE_COMPPUBLIC}" ]
then
    ## With folder OWNER Administrator  : O:LAG:S-1-22-2-0D:PAI(A;OICI;0x001301bf;;;DU)(A;;0x001200a9;;;WD)(A;OICIIO;0x001200a9;;;CG)(A;OICI;0x001f01ff;;;DA)
    ## With folder OWNER root           : O:S-1-22-1-0G:S-1-22-2-0D:PAI(A;OICI;0x001301bf;;;DU)(A;;0x001200a9;;;WD)(A;OICIIO;0x001200a9;;;CG)(A;OICI;0x001f01ff;;;DA)
    ## Default is set to : Adminisitrator
    COMPPUBLIC_SDDL="O:LAG:S-1-22-2-0D:PAI(A;OICI;0x001301bf;;;DU)(A;;0x001200a9;;;WD)(A;OICIIO;0x001200a9;;;CG)(A;OICI;0x001f01ff;;;DA)"
    #COMPPUBLIC_SDDL="O:S-1-22-1-0G:S-1-22-2-0D:PAI(A;OICI;0x001301bf;;;DU)(A;;0x001200a9;;;WD)(A;OICIIO;0x001200a9;;;CG)(A;OICI;0x001f01ff;;;DA)"

    install -oroot -groot -m"${SAMBA_COMPPUBLIC_CHMOD}" -d "${SAMBA_BASE}/${SAMBA_SHARE_COMPPUBLIC}"
    samba-tool ntacl set "O:S-1-22-1-0G:S-1-22-2-0D:PAI(A;OICI;0x001301bf;;;DU)(A;;0x001200a9;;;WD)(A;OICIIO;0x001200a9;;;CG)(A;OICI;0x001f01ff;;;DA)" "${SAMBA_BASE}/${SAMBA_SHARE_COMPPUBLIC}"
    echo "########################################################"
    echo
    echo "${INFO}"
    echo
else
    echo "########################################################"
    echo "     Warning: ${SAMBA_BASE}/${SAMBA_SHARE_COMPPUBLIC} already exist."
    echo "     Try to accesse the share as Adminsitrator or as a member of Domain Admins share: \\\\$(hostname -f)\\${SAMBA_SHARE_USERSPROFILES}"
    echo "     And verify if this share is set as [${SAMBA_SHARE_USERSPROFILES}] in smb.conf"
    echo
    echo "${INFO}"
    echo
fi
unset INFO
unset COMPPUBLIC_SDDL
}

function SambaSharesAll(){
# File you can include in smb.conf
echo "[samba\$]
    # Hidden share for Adminstrator and \"Domain Admins\" members/Folder managers
    # By default \"Domain Admins\" are allowed to read/write
    path = ${SAMBA_BASE}
    browseable = yes
    read only = no

[${SAMBA_SHARE_COMPDATA}]
    # main share for all company data.
    path = ${SAMBA_BASE}/${SAMBA_SHARE_COMPDATA}
    browseable = yes
    read only = no

[${SAMBA_SHARE_USERSPROFILES}]
    # Windows user profiles, Used for/by windows only share.
    # Add a $ on the end to hide the share-name.
    # By default \"Domain users\" are allowed to read/write
    # https://www.samba.org/samba/docs/current/man-html/vfs_acl_xattr.8.html
    # Optional, yes and windows  defaults are: no/posix
    # acl_xattr:ignore system acls = [yes|no]
    # acl_xattr:default acl style = [posix|windows|everyone]
    path = ${SAMBA_BASE}/${SAMBA_SHARE_USERSPROFILES}
    browseable = yes
    read only = no

[${SAMBA_SHARE_USERS}]
    # Samba/Windows User homedirs.
    # By default the User (And root/Administrator/Domain Admins) are allowed to read/write
    path = ${SAMBA_BASE}/${SAMBA_SHARE_USERS}
    browseable = yes
    read only = no

[${SAMBA_SHARE_COMPPUBLIC}]
    # A public share.
    # By default \"Domain users\" are allowed to read/write
    path = ${SAMBA_BASE}/${SAMBA_SHARE_COMPPUBLIC}
    browseable = yes
    read only = no
" > /etc/samba/smb-shares.conf

echo "Share examples can be found here: /etc/samba/smb-shares.conf"
echo "You can include this by adding : include = /etc/samba/smb-shares.conf to your smb.conf"
echo "And reload/restart samba : systemctl restart/reload smbd winbind"
echo
}

SambaRootFolder
SambaShare_companydata
SambaShare_users
SambaShare_profiles
SambaShare_public
SambaSharesAll
