#!/bin/bash

set -e -x

USER=user:password
ANONYMOUS=anonymous:anystring

# FTP active mode is on, passive mode is off, curl needs -P option

# download tests
echo test1 > /srv/ftp/test1.txt
curl -P - ftp://localhost/test1.txt --user "$ANONYMOUS" > test1-result.txt
diff -Nu /srv/ftp/test1.txt test1-result.txt

echo test2 > /home/user/test2.txt
chown user:users /home/user/test2.txt
curl -P - ftp://localhost/test2.txt --user "$USER" > test2-result.txt
diff -Nu /home/user/test2.txt test2-result.txt

#upload tests
echo test3 > test3.txt
curl -P - -T test3.txt ftp://localhost/upload/ --user "$ANONYMOUS"
diff -Nu /srv/ftp/upload/test3.txt test3.txt

echo test4 > test4.txt
curl -P - -T test4.txt ftp://localhost/upload/ --user "$USER"
diff -Nu /home/user/upload/test4.txt test4.txt

echo "AUTOYAST OK"
