#!/bin/bash
set -e -x

systemctl start named
nslookup cr01.openqa.local 127.0.0.1
nslookup 172.16.0.10 127.0.0.1
nslookup 127.0.0.1 127.0.0.1
nslookup localhost 127.0.0.1 
echo "AUTOYAST OK"
