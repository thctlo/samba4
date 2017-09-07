#!/bin/bash

# This script does not modify anything, it shows the output of the SEPRIVILEGE members.
# Version 1.1
# Released : 7 Sept 2017 
# Info: https://technet.microsoft.com/en-us/library/dn579255(v=ws.11).aspx#BKMK_PrintOperators
# 
# Assigning Delegated Print Administrator and Printer Permission Settings in Windows Server 2008 R2 
# https://technet.microsoft.com/en-us/library/ee524015(v=ws.10).aspx 


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

kinit Administrator

for sepriv in $SEPRIVILEGE ; do
    net rpc rights list privileges $sepriv -S $(hostname -f) -k
done
kdestroy
