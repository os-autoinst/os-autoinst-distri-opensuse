#! /bin/bash

server_ip="$1"

suite="/tmp/vsftpd/client"
VALIDUSERS="tester"
DIRS="./ files/ files/x/"

RC=0

echo "File $0"
echo "Server IP: $server_ip"

for i in $VALIDUSERS;do
    for y in $DIRS;do
        echo "FTP Listing directory ${y} for user ${i}"
            curl -1 -s -k -l -o "/tmp/ftpoutput" ftp://${i}:Test_pass1@${server_ip}/${y}
            [ $? -ne 0 ] || RC=1
    done
done

echo -e "RC: $RC\n"
exit $RC
