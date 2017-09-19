This folder gets a collection of samba howtos.
----------------------------------------------

These are tested on Debian Stretch, but should work on Jessie to.
The howto collection wil be extended with the following things.
1.      Base server install.  
2.      Samba AD DC.  
3.      Samba Member ( File server )  

( Work in progress )  
4.      Samba Member ( Cups Point and print Print server)  
5.  Samba Member ( Proxy server )  


The files and setup order:

 * *stretch-base-1.0.txt* :  Setup a minimal Debian server, with only ssh as base.  
   I use this one for every server setup.
 * *stretch-base-1.1-checkup.txt* : Check you server before continueing.  
    A must to make sure everyting is set ok, before other programmas are installed.
 * *stretch-base-2.0-samba-minimal-ad.txt* : Install Samba + Bind9_DLZ + ntp, a minimal setup.  
    You should be able to copy past where needed, while your read this file,  
    don't forget to change you REALM DNSDOMAIN and NTDOM.
 * *stretch-base-2.1-samba-minimal-ad-checks.txt* : a few minimal check for the AD DC setup.  
 * *stretch-base-3.1-samba-member-debian-install.txt* : This is basicly a copy of the stretch-base-1.0.txt.  
    Except, this one uses the first installed Samba AD DC server as primary NTP and DNS server.  
 * *stretch-base-3.3-samba-member-fileserver-rights-example.txt* : This start for some rights explained.  
