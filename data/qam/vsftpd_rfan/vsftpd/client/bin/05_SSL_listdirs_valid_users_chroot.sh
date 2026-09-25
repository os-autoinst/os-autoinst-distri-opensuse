#! /bin/bash

source /tmp/vsftpd_test_env

server_ip="$1"

suite="/tmp/vsftpd/client"
VALIDUSERS="testerchroot ftp anonymous"
DIRS="./ files/ files/x/"
# anonym is chrooted by default - not necessary to have files
ANONDIRS="./ x/"

RC=0

echo "File $0"
echo "Server IP: $server_ip"

for i in $VALIDUSERS;do
    [ $i = "ftp" ] || [ $i = "anonymous" ] && DIRS=$ANONDIRS
    for y in $DIRS;do
        echo "FTP Listing directory ${y} for user ${i}"
        if ([ $i = "ftp" ] && [ $y = "files/" ]) || ([ $i = "anonymous" ] && [ $y = "files/" ]);then
            echo
            [ $? -eq 0 ] || RC=1
        else
            curl $TLS_OPT -s -k -l --ssl -o "/tmp/ftpoutput" ftp://${i}:Test_pass1@${server_ip}/${y}
            [ $? -eq 0 ] || RC=1
        fi

        echo "SSH listing directory ${y} for comparison outputs"
        if ([ $i = "ftp" ] && [ $y = "files/" ]) || ([ $i = "anonymous" ] && [ $y = "files/" ]);then
            echo
            [ $? -eq 0 ] || RC=2
        elif [ $i = "ftp" ] || [ $i = "anonymous" ];then
            ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@${server_ip} "ls /srv/ftp/anon/${y}" > /tmp/sshoutput
            [ $? -eq 0 ] || RC=2
        else
            ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@${server_ip} "ls /srv/ftp/users/${i}/${y}" > /tmp/sshoutput
            [ $? -eq 0 ] || RC=2
        fi

        echo "Comparing lists:"
        diff /tmp/ftpoutput /tmp/sshoutput
        [ $? -eq 0  ];echo "Files match" || { RC=2;echo "Files are different"; }
    done
done

echo -e "RC: $RC\n"
exit $RC
