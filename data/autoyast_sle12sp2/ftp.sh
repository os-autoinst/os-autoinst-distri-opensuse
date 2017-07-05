#!/bin/sh -ex
#create test file for upload
echo test > test.txt
#create dirs and set permissions required for anonymous upload
mkdir -p /tmp/ftp/incoming
chmod a-w /tmp/ftp
chmod a+rw /tmp/ftp/incoming

curl -T test.txt ftp://localhost/incoming/ --user anonymous:anystring
curl ftp://localhost/incoming/test.txt > test2.txt

diff -u test.txt test2.txt && echo "AUTOYAST OK"
