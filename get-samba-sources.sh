#!/bin/bash

# A simple script that pulls the sources of my or your OS original repo.
# The highest versions are alway pulled. 
# feel free to share this, abuse it, but be nice, name me in your versions..  

echo -n "For which OS are we building? (debian/ubuntu/raspbian/all)(default:debian) : "
read OsBuildVer
OsBuildVer="${OsBuildVer:-debian}"

echo -n "For which OS Distro are we building? (buster/stretch/jessie/bionic)(default:buster): "
read OsDistBuildVer
OsDistBuildVer="${OsDistBuildVer:-buster}"

echo -n "For which package are we building? example samba squid (default samba) : "
read BLD_PKGIN
BLD_PKG="${BLD_PKGIN:-samba}"

echo -n "For which version of that package $BLD_PGK are we building? example 411 410 49 48 (default 411): "
read BLD_VER
PackageBuildingFor="${BLD_PKG}${BLD_VER:-411}"

# add the remote van-belle repo also to the host to allow you to get the correct sources if needed.
echo "deb http://apt.van-belle.nl/debian ${OsDistBuildVer}-${PackageBuildingFor} main contrib non-free" | sudo tee /etc/apt/sources.list.d/van-belle.list
echo "deb-src http://apt.van-belle.nl/debian ${OsDistBuildVer}-${PackageBuildingFor} main contrib non-free" | sudo tee -a /etc/apt/sources.list.d/van-belle.list
echo "running apt update, please wait"
sudo apt-get -qq update
echo "----------------------------"
echo
echo -n "Do we need more sources, for example this is for a new samba version in a new os/distro? (defaults to no)(yes/no): "
read NewBuilds
NewBuilds="${NewBuilds:-no}"
if [ "${NewBuilds}" = "yes" ]
then
    echo -n "Which extra repo do you want to add (debian/ubuntu/raspbian/all)(default:debian) : "
    read OsBuildVerExtra
    OsBuildVerExtra="${OsBuildVerExtra:-debian}"

    echo -n "Which extra Distro ? (buster/stretch/jessie/bionic)(default:buster): "
    read OsDistBuildVerExtra
    OsDistBuildVerExtra="${OsDistBuildVerExtra:-buster}"

    echo -n "Which samba version you need the old sources from ? example 411 410 49 48 experimental: "
    read BLD_VEREX
    if [ "${BLD_VEREX}" = experimental ]
    then
        PackageBuildingForExtra="${BLD_VEREX}"
    else
        PackageBuildingForExtra="${BLD_PKG}${BLD_VER}"
    fi
    echo "Please wait adding extra repo and running apt update"
    echo "deb http://apt.van-belle.nl/debian ${OsDistBuildVerExtra}-${PackageBuildingForExtra} main contrib non-free" | sudo tee -a /etc/apt/sources.list.d/van-belle.list
    echo "deb-src http://apt.van-belle.nl/debian ${OsDistBuildVerExtra}-${PackageBuildingForExtra} main contrib non-free" | sudo tee -a /etc/apt/sources.list.d/van-belle.list
    sudo apt-get -qq update
fi

if [ ! -d 01-talloc ]
then
    mkdir 01-talloc 02-tevent 03-tdb 04-cmocka 05-ldb 06-nss-wrapper 07-resolv-wrapper 08-uid-wrapper 09-socket-wrapper 10-pam-wrapper 11-samba
fi
cd 01-talloc/
apt-get source talloc
cd ..
cd 02-tevent/
apt-get source tevent
cd ..
cd 03-tdb/
apt-get source tdb
cd ..
cd 04-cmocka/
apt-get source cmocka
cd ..
cd 05-ldb/
apt-get source ldb
cd ..
cd 06-nss-wrapper/
apt-get source nss-wrapper
cd ..
cd 07-resolv-wrapper/
apt-get source resolv-wrapper
cd ..
cd 08-uid-wrapper/
apt-get source uid-wrapper
cd ..
cd 09-socket-wrapper/
apt-get source socket-wrapper
cd ..
cd 10-pam-wrapper/
apt-get source pam-wrapper
cd ..
cd 11-samba/
apt-get source samba

echo "Sources are ready to rebuild, start with 01.. "
echo "Verify the minimal, you might be able to skip some rebuilds, please wait, getting info."
echo
echo

cd $(ls -ltr|grep "drwx" |awk '{ print $NF }')
grep ^VERSION lib/{talloc,tdb,tevent,ldb}/wscript
cat   buildtools/wafsamba/samba_third_party.py | grep minversion | awk -F"(" '{ print $2 }'
echo
echo
cd ..
