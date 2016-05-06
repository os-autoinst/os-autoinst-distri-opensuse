#!/bin/bash

set -e -x

# firewall disabled
systemctl status SuSEfirewall2 | grep inactive

#partitioning
mount |grep /abuild


grep "ENABLE_SYSRQ=.*yes.*" /etc/sysconfig/sysctl

echo "AUTOYAST OK"