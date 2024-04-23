#!/bin/bash
set -eox pipefail
. /etc/os-release
SUSECONNECT=/tmp/SUSEConnect.txt
MAJOR_VERSION=$(echo $VERSION_ID|cut -c1-2)
ARCH=$(uname -m)

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
        # starting with 15.1 public cloud module started to use VERSION_ID instead of just MAJOR_VERSION
        if [[ $VERSION_ID = 15.[123456] ]]; then
            SUSEConnect -d -p sle-module-public-cloud/$VERSION_ID/$ARCH
        else
            SUSEConnect -d -p sle-module-public-cloud/$MAJOR_VERSION/$ARCH
        fi
        rm -f /tmp/REMOVE_PC
    fi
    if [ -e /tmp/REMOVE_SDK ]; then
        SUSEConnect -d -p $SDK/$VERSION_ID/$ARCH
        rm -f /tmp/REMOVE_SDK
    fi
    if is_sle12; then
        zypper rr SUSE_SLE-12_GA
        # only 12.3 has this obsolete dependency
        if [ $VERSION_ID = '12.3' ]; then
            zypper -n rm gpg-offline
        fi
    fi
    rm -f /tmp/REMOVE_ADDED_PRODUCTS
else
    if ! grep sle-module-public-cloud $SUSECONNECT; then
        # starting with 15.1 public cloud module started to use VERSION_ID instead of just MAJOR_VERSION
        if [[ $VERSION_ID = 15.[123456] ]]; then
            SUSEConnect -p sle-module-public-cloud/$VERSION_ID/$ARCH
        else
            SUSEConnect -p sle-module-public-cloud/$MAJOR_VERSION/$ARCH
        fi
        touch /tmp/REMOVE_PC
    fi
    if ! grep $SDK $SUSECONNECT; then
        SUSEConnect -p $SDK/$VERSION_ID/$ARCH --auto-agree-with-licenses
        touch /tmp/REMOVE_SDK
    fi
    if is_sle12; then
        # for not really needed gpg-offline, but simpler than zypper solution in openQA
        zypper ar -f http://download.suse.de/ibs/SUSE:/SLE-12:/GA/standard/SUSE:SLE-12:GA.repo
    fi
    touch /tmp/REMOVE_ADDED_PRODUCTS
fi
