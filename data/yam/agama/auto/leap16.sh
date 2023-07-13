set -ex

/usr/bin/agama config set software.product=Leap16
/usr/bin/agama config set user.userName=bernhard user.password=nots3cr3t
/usr/bin/agama config set root.password=nots3cr3t
/usr/bin/sleep 30
/usr/bin/agama install
