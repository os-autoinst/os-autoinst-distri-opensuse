#!/bin/bash
set -eox pipefail
. /etc/os-release
SUSECONNECT=/tmp/SUSEConnect.txt
MAJOR_VERSION=$(echo $VERSION_ID|cut -c1-2)

function is_sle12 {
    [[ $VERSION_ID =~ 12 ]]
}

function finish {
 rm -f /tmp/SUSEConnect.txt
}
trap finish EXIT

if [[ $VERSION_ID =~ 15 ]]; then
    SDK=sle-module-development-tools
elif is_sle12; then
    SDK=sle-sdk
fi

SUSEConnect -s >$SUSECONNECT

# remove added products if /tmp/REMOVE_ADDED_PRODUCTS exists otherwise add them
if [ -e /tmp/REMOVE_ADDED_PRODUCTS ]; then
    if [ -e /tmp/REMOVE_PC ]; then
        SUSEConnect -d -p sle-module-public-cloud/$MAJOR_VERSION/x86_64
        rm -f /tmp/REMOVE_PC
    fi
    if [ -e /tmp/REMOVE_SDK ]; then
        SUSEConnect -d -p $SDK/$VERSION_ID/x86_64
        rm -f /tmp/REMOVE_SDK
    fi
    if is_sle12; then
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
        SUSEConnect -p $SDK/$VERSION_ID/x86_64
        touch /tmp/REMOVE_SDK
    fi
    if is_sle12; then
        # for not really needed gpg-offline, but simpler than zypper solution in openQA
        zypper ar -f http://download.suse.de/ibs/SUSE:/SLE-12:/GA/standard/SUSE:SLE-12:GA.repo
    fi
    touch /tmp/REMOVE_ADDED_PRODUCTS
fi
