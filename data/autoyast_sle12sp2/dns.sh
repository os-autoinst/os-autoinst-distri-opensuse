#!/bin/bash
set -e -x

systemctl start named
nslookup cr01.openqa.local 127.0.0.1
nslookup 172.16.0.10 127.0.0.1
nslookup localhost 127.0.0.1
# Ignore result as known issue bsc#1046605
result=$(nslookup 127.0.0.1 127.0.0.1 || true)
if [[ $result == *"** server can't find 1.0.0.127.in-addr.arpa: SERVFAIL"* ]]; then
   echo "Expected error, see bsc#1046605: $result";
else
  return 1;
fi

echo "AUTOYAST OK"
