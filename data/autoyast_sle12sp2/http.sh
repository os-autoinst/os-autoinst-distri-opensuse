#!/bin/bash

set -e -x

HTTPTEST=/var/log/test-http.txt
HTTPSTEST=/var/log/test-https.txt
HTTPRES=0

echo test > /srv/www/htdocs/test.txt
echo "[DEBUG] http test:"
curl -s -S http://localhost/test.txt 2>&1 | tee $HTTPTEST
echo "[DEBUG] https -k test:"
curl -s -S -k https://localhost/test.txt 2>&1 | tee $HTTPSTEST

diff -u /srv/www/htdocs/test.txt $HTTPTEST && diff -u $HTTPTEST $HTTPSTEST && HTTPRES=1 || echo "[ERROR] HTTP/HTTPS test failed"

# Firewall setup verification script

# since we are testing ourselves, we can't use simple nmap/nc as that skip netfilter on localhost even when target is our public facing ip
# so grep iptables output.

# autoyast profiles allow http, https and 8080 tcp ports and 9090 udp port. Rest should be standard SLE firewall, incomming policy is drop.
IPTABLESLOG=/var/log/iptables.out
IPTABLESRES=0

iptables -L -n -v 2>&1 > $IPTABLESLOG

# check policies
grep -q -E "Chain (INPUT|FORWARD) \(policy DROP" $IPTABLESLOG || exit 1

# list open ports
grep -E "ACCEPT[[:space:]]*(tcp|udp)[[:space:]\*0\./-]*(tcp|udp)" $IPTABLESLOG > opened || exit 2

perl - opened <<EOP && IPTABLESRES=1
  my \$res = 0;
  my \$err = 0;
  while(<>) {
    /ACCEPT[[:space:]]*(tcp|udp)[[:space:]\*0\.\/-]*(tcp|udp) dpt:([0-9]{2,4})/;
    \$proto = \$1;
    \$port = \$3;
    print "[INFO] port \$port/\$proto opened.\n";
    #If tcp, expect 80/443/8080, for udp only 9090
    if (\$proto eq 'tcp' && \$port =~ /80|443|8080/ || \$proto eq 'udp' && \$port eq 9090) {
        \$res += \$port;
        next;
    }

    print "[ERROR] Unexpected \$proto port \$port opened.\n";
    \$err=1;
  }
  if (\$res != 17693 || \$err) {
    print "[ERROR] Some ports were not opened but expected or opened but not expected.\n";
    print "        Expect only tcp:80,443,8080 and udp:9090.\n";
    exit 1;
  }
  exit 0;
EOP

test $HTTPRES -eq 1 -a $IPTABLESRES -eq 1 && echo "AUTOYAST OK"
