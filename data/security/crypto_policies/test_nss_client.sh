#!/usr/bin/bash
# call this script with first argument the file where to write the client output
set -eux
OUTFILE=$1
# sort out test client path name, which is different between SLES and Tumbleweed
TSTCLNT=$(rpm -ql mozilla-nss-tools | grep /usr/lib.*tstclnt | head -1)
# create NSS database
rm -rf nssdb && mkdir -p nssdb
certutil -N -d sql:./nssdb --empty-password
# generate an openssl keypair 
# (size 4096 to cover also FUTURE cryptopolicy)
openssl req -new -newkey rsa:4096 -x509 -days 7 -nodes -subj "/CN=localhost" -out localhost.pem -keyout localhost.key
# import this certificate into the NSS database and mark it as trusted
certutil -d ./nssdb -A -a -i localhost.pem -t TCP -n localhost
# spin up a temp TLS server
openssl s_server -accept 4443 -cert localhost.pem -key localhost.key -www &
SERVER_PID=$!
sleep 3
# call the server with nss client
(echo "GET / HTTP/1.0" | $TSTCLNT -d ./nssdb -h localhost -p 4443 2>&1 > $OUTFILE) &
sleep 3
# stop the server and the background client
kill $SERVER_PID
kill $(pidof tstclnt)
