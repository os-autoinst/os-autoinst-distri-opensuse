#!/bin/bash

set -e -x

SERVICES=`firewall-offline-cmd --zone=external --list-services`
test "$SERVICES" == 'http https' || echo 'Services are not configured properly, expected http https'

echo "AUTOYAST OK"
