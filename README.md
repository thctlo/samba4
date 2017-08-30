# samba4
==============

Here you can find some scripts I daily use with samba 4 (AD-DC) 


All my scripts are made and tested on Debian Jessie and Stretch servers.
Questions about the scripts, mail the samba mailing list, i'll answer them.
If you have improvements, well add them thats why ive added them on github.

A small recap of these scripts.
----------------
backup-script/backup_samba4: A modified version of the original samba_backup script.
samba-check-SePrivileges.sh : shows the configured SePrivileges and its groups set, no modifications are done.
samba-check-set-sysvol.sh: check and set the ACL for sysvol and tells you what to check.
samba-info.sh: simpel tool to show domain info.
samba-setup-checkup.sh: (Work in progress), Goal, check you system for the correct and needed setttings to install samba.
samba-with-nfsv4.sh: the script i used to setup my domain members on my jessie server. Debian stretch is different.
