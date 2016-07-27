# backup_samba4
==============
The script is tested on debian Wheezy and Debian Jessie, but should work with any linux os.
This is a modified version of the backup_samba4 script, the original script is found in the samba source.

By default the scripts logs tot syslog. 
running ./backup_samba4 --debug  give console output. 

The first time you start it, run it with --debug, so you can check if all is ok.

How does it work: 
- The script collects the commands use in full path, if one isn't found you get a message and the script ends.
- The script extracts the sysvol etc and private folders in full paths from the running samba.
- The script uses a counter to make multple backups on the same day. 
- The script cleans up backup files older then DAYS.
- This all is done without stopping samba.


You need to add something like this in cron. 
This example shows a 5x backup during work hours on weekdays
and last at 23:00 for the daily (normal) backup procedures.

6 7,10,13,16,19 * * 1,2,3,4,5 root /PATH_TO/backup_samba4 &> /dev/null

0 23 * * * root /PATH_TO/backup_samba4 &> /dev/null

You need to configure the following in the script: 

A Config example
----------------
The location to backup to.
`- STOREDIR=/home/backups/`hostname -s``

This creates an extra acl backup of sysvol with getfacl -R (yes/no).
Best is not to change this.
- BACKUP_SYSVOL_ACL="yes"

Original not in samba script but very usefull.
Full /etc backup (yes/no).
Best is not to change this.
- BACKUP_ETC="yes"

Number of days to keep the backup.
- DAYS=30

TODO/ Not working yet, but if you know how, you can add the code. ;-)
KEEP_DAYS, keeps every date with 01 and 15 in the backup (yes/no) 
while we obey the "DAYS" if set to no, only DAYS settings do apply 
if you dont want numberd backup files like : sysvol-2015-12-10-0.tar.bz2 set to: yes 
but you want timed backup files like : sysvol-2015-12-10_091209.tar.gz set to: time
So options to set are :  yes, no, time 
- KEEP_DAYS="no"


TODO/ Not working yet, but if you know how, you can add the code. ;-)
The day numbers of the month to keep, only effective if KEEP_DAYS="yes" !
if you did set keep_days=time you will keep hours of the day. ( like 01:00 and 15:00 ) 
timed files are in 
- KEEP_DAY1="01"
- KEEP_DAY2="15"

What to backup of samba, this should normaly not be needed to change.
The full paths are extracted from the running samba.
- DIRS="private sysvol samba"

The location for the command file, can be any place any file name.
- SCRIPT_COMMANDS_FILE="/etc/samba/backup_samba4_commands"


The commando's this scripts need, should not be changed.
- SCRIPT_COMMANDS="samba tdbbackup logger tar dirname cat grep echo awk sed date find rm getfacl tail cut wc awk sort"
