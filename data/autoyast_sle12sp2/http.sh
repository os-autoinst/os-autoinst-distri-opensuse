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
  my @ports = qw(tcp:80 tcp:443 tcp:8080 udp:5353 udp:9090);
  my %res = map { \$_ => 1 } @ports;
  my \$err = 0;
  while(<>) {
    /ACCEPT[[:space:]]*(tcp|udp)[[:space:]\*0\.\/-]*(tcp|udp) dpt:([0-9]{2,4})/;
    \$proto = \$1;
    \$port = \$3;
    print "[INFO] port \$port/\$proto opened.\n";
    #Check if opened port is expected
    if (exists(\$res{"\$proto:\$port"})) {
        #remove expected ports from hash
        delete \$res{"\$proto:\$port"};
        next;
    }

    print "[ERROR] Unexpected \$proto port \$port opened.\n";
    \$err=1;
  }
  #Check if some ports were not opened but expected to be
  if (%res) {
    print "[ERROR] Some of ports were not opened: " . keys %res . ".\n";
    \$err=1;
  }
  exit \$err;
EOP

test $HTTPRES -eq 1 -a $IPTABLESRES -eq 1 && echo "AUTOYAST OK"
