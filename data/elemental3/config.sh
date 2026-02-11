#!/bin/bash

set -xe

# Variable(s)
declare etc_rancher="/etc/rancher"
declare k8s_distri="%K8S%"

# Setting root passwd
sed -i '/^root:/s|^root:\*:\(.*\)|root:%TEST_PASSWORD%:\1|' /etc/shadow

# Allow root ssh access (for testing purposes only!)
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/root_access.conf
systemctl enable sshd

# Add ssh pubkey
mkdir -p /root/.ssh && chmod 0700 /root/.ssh
cat > /root/.ssh/authorized_keys <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCfUK3osL0inEfTKGEXPus7nlOcnNBrVdyMWXe1UVvHV/8LXbdHKTSS9BxJC2wnjBETa/d+z2Ghfcyl6R4aN9AXyiU5DmHXg3V1sMfouibH7ilpJ4EXgQTyWc2ConVtg1/4f331RRAG5Jotd0N0YVCzFJtlnn/EQ1SUKrT+d3pZUPuaMQYUsF6mL3sFXM0NkOZfi1amrPuSZaEUP04wWT5p2ummrDTOfXP3+tEi874v5GpBdxRhIxutQcOjFgvEearf0aF8iOV8xCg4zbbLSi+f2gyg7mEF8VPYlU9kroB20zP46OP6GCwBTUq2mds/dZzjsY3VVWJmjbq3AHQmtX2tiC/9QJ1n0ihhGMxdKhKEW8kEf1nufACCfbtkr8Ai9YnyWhOVFdTcHHzFZob5nGT3eIk6iVJJE1QMnCoB95SU0KTNa+PV0JMp/Ycxdbrs9nq1FF312L1Q5lctN3knaU/Hh0SyQaPa5iPxEeBMMI8VooW/C180Zwpiwhov8kXcMT0+vxbUSQHgW88LwB8bu7GpMKhPhlA9VX87YMpX4w8Jwe/xzDETsdg8CVdWwnvZZz+iWPwLulcT/vjM5oUxn6WtaKF9BKAfnCMCWqosnpKuqmMhoyFgrQH8UUsyBpS4Q7z3pbOZobBriCQ5FTNLnEbdsWJZr3qGmZVT/9mYOHoqzw== UnifiedCore
EOF
chmod 644 /root/.ssh/authorized_keys

# Add ssh config
cat > /root/.ssh/config <<EOF
UserKnownHostsFile /dev/null
CheckHostIP no
StrictHostKeyChecking no
EOF
chmod 600 /root/.ssh/config

# Add kubectl access/command
cat > /root/.profile <<EOF
export KUBECONFIG=${etc_rancher}/${k8s_distri}/${k8s_distri}.yaml
export PATH=\${PATH}:/var/lib/rancher/${k8s_distri}/bin
EOF

# Set a default hostname
echo "${k8s_distri}-node" > /etc/hostname

# Create /etc/rancher directory
mkdir -p ${etc_rancher}/${k8s_distri}

# Configure RKE2
cat > ${etc_rancher}/${k8s_distri}/config.yaml <<EOF
write-kubeconfig-mode: "0644"
node-name: %NODE_NAME%
node-external-ip: %NODE_IP%
selinux: true
EOF

# Create a pseudo-sudo command (for testing purposes only!)
mkdir -p /root/bin
cat > /root/bin/sudo <<EOF
exec \$@
EOF
chmod 0700 /root/bin/sudo
