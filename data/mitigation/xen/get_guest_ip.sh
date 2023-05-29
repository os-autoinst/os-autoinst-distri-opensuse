#!/bin/sh


function _get_ip_by_expect {

local guestname=$1

expect -c " 
set timeout 3600

#hide echo
log_user 0
spawn -noecho virsh console ${guestname}

#wait connection
sleep 3
send \"\r\n\r\n\r\n\"

#condition expect
expect {
        \"*login:\" {
                send \"root\r\"
		exp_continue
        }
        \"*assword\" {
                send \"nots3cr3t\r\"
		exp_continue
        }
        \"*:~ #\" {
                send -- \"sed -i '/GRUB_TIMEOUT=-1/s/=-1/=5/g' /etc/default/grub && grub2-mkconfig -o /boot/grub2/grub.cfg && sync \r\"
                send -- \"ip route get 1\r\"
        }

	    \"error: The domain is not running\" {
	    	puts \"The domain $guestname is not running\"
	    	exit 8
	    }
        timeout {
                puts \"The guest $guestname is broken during installation\"
                exit 9
        }
}

#submatch for output
expect -re {dev.*?([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})[^0-9]}

if {![info exists expect_out(1,string)]} {
        puts \"Match did not happen :(\"
        exit 1
}

# assign submatch to variable
set output \$expect_out(1,string)
#clear terminal, no work for current situation
unset expect_out(buffer)
send \"\\035\\r\"
expect eof

puts \"\$output\"
"
}

function get_guest_ip_addr() {
	local guestname=$1
	local gip
	local ret
	gip=$(_get_ip_by_expect $guestname)
	ret=$?
	#echo $gip
	if [ $ret != 0 ];then
		if [ $ret -eq 8 ];then
			echo "Error: Domian $guestname is not running,"  $w
			exit -1
		fi
		if [ $ret -eq 9 ];then
			echo "Error: The guest $guestname is broken during installation,"  $w
			exit -1
		fi
		echo "Error occur."
	fi

	echo $gip

}

get_guest_ip_addr $1
