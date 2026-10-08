#!/bin/bash
set -e -x

locfile='test.txt'
srvfile='test_up.txt'
srvpath='/srv/tftpboot'
srvpathname=$srvpath/$srvfile

echo test >$locfile

#tftpd does not allow creation of new files by default
touch $srvpathname
chmod a+w $srvpathname

time tftp localhost -c put $locfile $srvfile
time tftp localhost -c get          $srvfile

diff -u $locfile $srvfile && echo "AUTOYAST OK"

