# backup_samba4  

This is a modified version of the original backup_samba4 script.
The original script is found in the samba source. 

You need to configure the following in the script: 


STOREDIR=/home/backups/`hostname -s`

# this creates an extra acl backup of sysvol with getfacl -R (yes/no) 
BACKUP_SYSVOL_ACL="yes"

## original not in samba script but very usefull.
# Full /etc backup (yes/no)
BACKUP_ETC="yes"

# Number of days to keep the backup
DAYS=30

## TODO/ Not working yet, but if you know how, you can add the code. ;-)
# KEEP_DAYS, keeps every date with 01 and 15 in the backup (yes/no) 
# while we obey the "DAYS" if set to no, only DAYS settings do apply 
# if you dont want numberd backup files like : sysvol-2015-12-10-0.tar.bz2 set to: yes 
# but you want timed backup files like : sysvol-2015-12-10_091209.tar.gz set to: time

## TODO/ Not working yet, but if you know how, you can add the code. ;-)
# So options to set are :  yes, no, time 
#KEEP_DAYS="no"
#Does not work yet

## TODO/ Not working yet, but if you know how, you can add the code. ;-)
# The day numbers of the month to keep, only effective if KEEP_DAYS="yes" !
# if you did set keep_days=time you will keep hours of the day. ( like 01:00 and 15:00 ) 
# timed files are in 
KEEP_DAY1="01"
KEEP_DAY2="15"

# what to backup of samba, this should normaly not be needed to change.
DIRS="private sysvol samba"

# the location for the command file, can be any place any file name.
SCRIPT_COMMANDS_FILE="/etc/samba/backup_samba4_commands"

## 
# the commando's this scripts need. 
SCRIPT_COMMANDS="samba tdbbackup logger tar dirname cat grep echo awk sed date find rm getfacl tail cut wc awk sort"

