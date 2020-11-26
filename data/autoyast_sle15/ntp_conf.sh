#!/bin/bash

set -e -x

grep "pool ntp.suse.de iburst" /etc/chrony.conf
grep "driftfile /var/lib/chrony/drift" /etc/chrony.conf
echo "AUTOYAST OK"
