#!/bin/bash

# This script does not modify anything, it shows the output of the SEPRIVILEGE members.
# Version 1.1
# Released : 7 Sept 2017
# Updated : 20 May 2022, Thanks for Testing Rowland Penny.  ;-)
# Info: https://technet.microsoft.com/en-us/library/dn579255(v=ws.11).aspx#BKMK_PrintOperators
#
# Assigning Delegated Print Administrator and Printer Permission Settings in Windows Server 2008 R2
# https://technet.microsoft.com/en-us/library/ee524015(v=ws.10).aspx


# check samba verions since some paramater changes.
FULL_VERSION="$(smbd -V|cut -d" " -f2 | sed 's/-Debian//g')"
MAIN_VERSION="$(echo "$FULL_VERSION" | cut -d"." -f1)"
MINOR_VERSION="$(echo "$FULL_VERSION" | cut -d"." -f2)"
SUB_VERSION="$(echo "$FULL_VERSION" | cut -d"." -f3)"


# Last check known SePrivilege
SEPRIVILEGE="SeMachineAccountPrivilege \
SeTakeOwnershipPrivilege SeBackupPrivilege SeRestorePrivilege \
SeRemoteShutdownPrivilege SePrintOperatorPrivilege SeAddUsersPrivilege \
SeDiskOperatorPrivilege SeSecurityPrivilege SeSystemtimePrivilege \
SeShutdownPrivilege SeDebugPrivilege SeSystemEnvironmentPrivilege \
SeSystemProfilePrivilege SeProfileSingleProcessPrivilege \
SeIncreaseBasePriorityPrivilege SeLoadDriverPrivilege \
SeCreatePagefilePrivilege SeIncreaseQuotaPrivilege SeChangeNotifyPrivilege \
SeUndockPrivilege SeManageVolumePrivilege SeImpersonatePrivilege SeCreateGlobalPrivilege \
SeEnableDelegationPrivilege"

echo "Version check for Samba : $MAIN_VERSION.$MINOR_VERSION.$SUB_VERSION"
kinit Administrator
if [ "${MINOR_VERSION}" -lt 15 ]
then
    for sepriv in $SEPRIVILEGE
    do
        net rpc rights list privileges "$sepriv" -S "$(hostname -f)" --kerberos
    done
elif [ "${MINOR_VERSION}" -ge 15 ]
then
    for sepriv in $SEPRIVILEGE
    do
        net rpc rights list privileges "$sepriv" -S "$(hostname -f)" --use-kerberos=required -N
    done
fi
kdestroy
