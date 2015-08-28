#!/bin/bash
set -e -x

locfile='test.txt'
srvfile='test_up.txt'

echo test >$locfile
time tftp #SERVER_URL# -c put $locfile $srvfile
time tftp #SERVER_URL# -c get $srvfile

diff -u $locfile $srvfile && echo "AUTOYAST OK"

