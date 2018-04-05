#!/bin/sh -e
CONFIG='/etc/samba/smb.conf'
for i in global html_public; do
	sed -n '/\['$i'\]/,/\[/{/^\[.*$/!p}' $CONFIG | while read -r line; do
	printf "%-23s = %s\n" "${line%?=*}" "${line#*=?}" >> /tmp/smb.txt
	done
done