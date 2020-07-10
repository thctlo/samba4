#!/bin/bash

# Verified with Debian Buster's shellcheck 0.5.0-3

# Version: function-samba-winbind=0.02

# This script is for checking and setting up winbind for Samba.
# It can be use on Domain Members and AD Domain Controllers.
#
# Copyright (C) Louis van Belle 2020
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

if [ "$(dpkg-query -l libpam-winbind)" ]
then
    # True
    echo "libpam-winbind already installed"
else
    # False
    echo "installing libpam-winbind"
    apt-get install -y libpam-winbind
fi
if [ "$(dpkg-query -l libnss-winbind)" ]
then
    # True
    echo "libnss-winbind already installed"
else
    # False
    echo "installing libnss-winbind"
    apt-get install -y libnss-winbind
fi

if [ "$(grep -ic winbind /etc/nsswitch.conf)" -eq 2 ]
then
    echo "nsswitch.conf was already adjusted"
elif [ "$(grep -c winbind /etc/nsswitch.conf)" -eq 1 ]
then
    FOUND_VALUE="$(grep winbind /etc/nsswitch.conf |cut -d: -f1)"
    echo "Warning Detected only 1 adjusted line with winbind in it, line: ${FOUND_VALUE}"
    if [ "${FOUND_VALUE}" = "passwd" ]
    then
        sed -i 's/group:          files systemd/& winbind/g' /etc/nsswitch.conf
    elif  [ "${FOUND_VALUE}" = "group" ]
    then
        sed -i 's/passwd:         files systemd/& winbind/g' /etc/nsswitch.conf
    fi
elif [ "$(grep -c winbind /etc/nsswitch.conf)" -eq 0 ]
then
    echo "Adjusting nsswitch.conf"
    sed -i 's/passwd:         files systemd/& winbind/g' /etc/nsswitch.conf
    sed -i 's/group:          files systemd/& winbind/g' /etc/nsswitch.conf
else
    echo "Error, we dont know what when wrong here. more then 3 winbind lines maybe?"
    echo "Captical check on winbind/detected: $(grep -i winbind /etc/nsswitch.conf )"
    echo "Please check /etc/nsswitch.conf"
fi
