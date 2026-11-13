#! /bin/bash

source /tmp/vsftpd_test_env

server_ip="$1"

suite="/tmp/vsftpd/client"

RC=0

# default is rw
if [ $2  = "ro" ];then
	action=ro
else
	action=rw
fi

echo "File $0"
echo "Server IP: $server_ip"
echo -e "Permission mode: $action\n"

for i in ${suite}/data/*; do
	if [ $action = "rw" ]; then
		echo "Uploading our test file ${i} to the server"
		curl $TLS_OPT -s -k --ssl -T "${i}" ftp://tester:Test_pass1@${server_ip}
		[ $? -eq 0 ] || RC=1
	elif [ $action = "ro" ]; then
		FILENAME="${i##*/}_fail"
		echo "Uploading our test file ${i} to the server should fail(ro only)"
		curl $TLS_OPT -s -k --ssl -T "${i}" ftp://tester:Test_pass1@${server_ip}/$FILENAME
		[ $? -ne 0 ] || RC=1
	fi

    echo "Downloading our test file ${i##*/} from the server"
    cd /tmp
    curl $TLS_OPT -v -k --ssl -O ftp://tester:Test_pass1@${server_ip}/${i##*/}
    [ $? -eq 0 ] || RC=2

    echo "Comparing of downloaded file ${i##*/} with original"
    diff -u /tmp/${i##*/} ${i}
    [ $? -eq 0 ] || RC=3

done

echo -e "RC: $RC\n"
exit $RC
