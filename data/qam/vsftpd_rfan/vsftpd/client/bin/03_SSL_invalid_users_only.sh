#! /bin/bash

source /tmp/vsftpd_test_env

server_ip="$1"

suite="/tmp/vsftpd/client"
INVALIDUSERS="user root nobody ftp anonymous invaliduser"

RC=0

echo "File $0"
echo "Server IP: $server_ip"

for i in $INVALIDUSERS;do
	echo "Uploading our test file to the server should fail(invalid user)"
	curl $TLS_OPT -s -k --ssl -T "$suite/data/test_text.file" ftp://${i}:Test_pass1@${server_ip}
	[ $? -ne 0 ] || RC=1

	echo "Downloading our test file from the server should fail(invalid user)"
    cd /tmp
    curl $TLS_OPT -s -k --ssl -O ftp://${i}:Test_pass1@${server_ip}/$suite/data/test_text.file
    [ $? -ne 0 ] || RC=2

done

echo -e "RC: $RC\n"
exit $RC
