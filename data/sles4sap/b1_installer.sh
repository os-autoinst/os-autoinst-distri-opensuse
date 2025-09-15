#!/bin/bash

# Summary: Wrapper script to copy some modified SAP B1 test scripts in order
# to make them pass agains curl 8.14. This is script is only a workaround for
# openQA testing.
# Maintainer: QE-SAP <qe-sap@suse.de>

install_bin="$1"
b1_cfg="$2"

if [ -z "$install_bin" -o -z "$b1_cfg" ]; then
    echo "missing parameter"
    exit 1
else
    $install_bin -i silent -f /tmp/$b1_cfg &
    b1_pid=$!
    sleep 10
    kill -SIGSTOP $b1_pid
    cd /tmp/B1ServerTools*
    cp -f /tmp/*.sh opt/sap/SAPBusinessOne/Common/support/bin
    kill -SIGCONT $b1_pid
    wait $b1_pid
    exit $?
fi
