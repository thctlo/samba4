#!/bin/bash

# This script does not modify anything, it shows the output of the SEPRIVILEGE members.
# Version 1.0
# Released : 30 aug 2017
# Info: https://technet.microsoft.com/en-us/library/dn221963(v=ws.11).aspx 


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
