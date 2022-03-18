#!/bin/bash

MAINT_TEST_REPO=$1

# Setting up CA Certs
zypper install -y curl

curl -k https://ca.suse.de/certificates/ca/SUSE_Trust_Root.crt -o /etc/pki/trust/anchors/SUSE_Trust_Root.crt
update-ca-certificates -v

# Add repos
counter=1
for r in ${MAINT_TEST_REPO//,/ }
do
   echo $r
   zypper --no-gpg-checks ar -f -G -n "TEST_$counter" $r "TEST_$counter"
   ((counter=counter+1))
done
