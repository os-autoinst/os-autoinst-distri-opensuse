#!/bin/bash

set -euox pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Not running as root!"
    exit 1
fi

. /etc/os-release

# are we running SLE? => register the system
if [ "$(echo ${ID} | sed '/opensuse/d')" != "" ]; then
    # NAME is either SLES or SLED -> downcase it
    keyfile="/vagrant/key_${NAME,,}"

    # wait for zypper to release the lock before we run SUSEConnect (that needs
    # zypper too), it is locked if it returns 7
    i=0
    while [ $i -lt 10 ]; do
        set +e
        zypper --non-interactive ref
        ZYPPER_RETVAL=$?
        set -e
        if [ ${ZYPPER_RETVAL} -ne 7 ]; then
            break;
        else
            sleep 20;
            i=$((i+1));
        fi
    done

    # on SLED SUSEConnect tries to add the Nvidia repo with its own GPG key
    # => this causes a failure (as the key is unknown)
    # we therefore disable the Nvidia repo here, as it doesn't work with SLED 12
    # anyway and isn't really useful for a vagrant box
    set +e # (need to 'set +e' as the SUSEConnect can fail)
    SUSEConnect --regcode $(cat "${keyfile}")
    set -e

    if [ "${NAME}" = "SLED" ]; then
        nvidia_repo_id=$(zypper repos|grep -i nvidia|awk -F"|" '{ print $1 }')
        if [ "${nvidia_repo_id}" != "" ]; then
            zypper --non-interactive modifyrepo -d ${nvidia_repo_id}
        fi
    fi
    zypper --non-interactive --gpg-auto-import-keys refresh
else
    zypper --non-interactive refresh
fi
