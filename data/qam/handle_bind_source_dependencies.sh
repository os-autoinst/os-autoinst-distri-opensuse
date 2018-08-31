#!/bin/bash
set -eox pipefail
SOURCE_FILE=/etc/bash.bashrc.local
SUSECONNECT=/tmp/SUSEConnect.txt
VERSION=$(SUSEConnect --status-text|grep SLE[SD]/|awk -F/ '{print$2}')
MAJOR_VERSION=$(echo $VERSION|cut -c1-2)

if echo $VERSION|grep 15 > /dev/null 2>&1; then
    SDK=sle-module-development-tools
elif echo $VERSION|grep 12 > /dev/null 2>&1; then
    SDK=sle-sdk
fi

function finish {
 rm -f /tmp/SUSEConnect.txt
}
trap finish EXIT

SUSEConnect -s >$SUSECONNECT

# remove added products if /tmp/REMOVE_ADDED_PRODUCTS exists otherwise add them
if [ -e /tmp/REMOVE_ADDED_PRODUCTS ]; then
    if [ -e /tmp/REMOVE_PC ]; then
        SUSEConnect -d -p sle-module-public-cloud/$MAJOR_VERSION/x86_64
        rm -f /tmp/REMOVE_PC
    fi
    if [ -e /tmp/REMOVE_SDK ]; then
        SUSEConnect -d -p $SDK/$VERSION/x86_64
        rm -f /tmp/REMOVE_SDK
    fi
    if echo $VERSION|grep 12 > /dev/null 2>&1; then
        zypper rr SUSE_SLE-12_GA
        zypper -n rm gpg-offline
    fi
    rm -f /tmp/REMOVE_ADDED_PRODUCTS
else
    if ! grep sle-module-public-cloud $SUSECONNECT; then
        SUSEConnect -p sle-module-public-cloud/$MAJOR_VERSION/x86_64
        touch /tmp/REMOVE_PC
    fi
    if ! grep $SDK $SUSECONNECT; then
        SUSEConnect -p $SDK/$VERSION/x86_64
        touch /tmp/REMOVE_SDK
    fi
    if echo $VERSION|grep 12 > /dev/null 2>&1; then
        # for not really needed gpg-offline, but simpler than zypper solution in openQA
        zypper ar -f http://download.suse.de/ibs/SUSE:/SLE-12:/GA/standard/SUSE:SLE-12:GA.repo
    fi
    touch /tmp/REMOVE_ADDED_PRODUCTS
fi
