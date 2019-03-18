# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Avocado setup and network bridge configuration
#          Test system has to be registered baremetal
# Maintainer: Jozef Pupava <jpupava@suse.cz>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils qw(systemctl zypper_call);
use version_utils qw(is_sle is_opensuse);

sub teardown {
    my $teardown = <<'EOF';
#!/bin/bash
if [[ $(grep 1 /sys/class/net/br0/carrier) ]]; then
    ACTIVE_NET=$(grep -l 1 /sys/class/net/eth*/carrier|head -n1|awk -F/ '{print$5}')
    mv /etc/sysconfig/network/old_ifcfg-$ACTIVE_NET /etc/sysconfig/network/ifcfg-$ACTIVE_NET
    rm /etc/sysconfig/network/ifcfg-br0
    systemctl restart network;
fi
EOF
    script_output($teardown);
    assert_script_run 'ip a';
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # needed for script_output
    zypper_call 'in curl';

    my $avocado_repo = get_var('AVOCADO_REPO');
    zypper_call "ar -f $avocado_repo avocado_repo", exitcode => [0, 4, 104];
    zypper_call '--gpg-auto-import-keys ref';

    # setup bridge, add needed SCC modules and install avocado-vt, tune tests, timeouts, test fixes
    my $avocado_setup = <<'EOF';
#!/bin/bash
EXT_STATUS=$(SUSEConnect --status)
ARCH=$(uname -m)
. /etc/os-release
if [[ ! $(grep 1 /sys/class/net/br0/carrier) ]]; then
    ACTIVE_NET=$(grep -l 1 /sys/class/net/eth*/carrier|head -n1|awk -F/ '{print$5}')
    cp /etc/sysconfig/network/ifcfg-$ACTIVE_NET /etc/sysconfig/network/old_ifcfg-$ACTIVE_NET
    interface="BOOTPROTO='none'\nSTARTMODE='auto'\nDHCLIENT_SET_DEFAULT_ROUTE='yes'"
    bridge="BOOTPROTO='dhcp'\nBRIDGE='yes'\nBRIDGE_FORWARDDELAY='0'\nBRIDGE_PORTS='$ACTIVE_NET'\nBRIDGE_STP='off'\nDHCLIENT_SET_DEFAULT_ROUTE='yes'\nSTARTMODE='auto'"
    echo -e $bridge >/etc/sysconfig/network/ifcfg-br0
    echo -e $interface >/etc/sysconfig/network/ifcfg-$ACTIVE_NET
    cat /etc/sysconfig/network/ifcfg-br0
    cat /etc/sysconfig/network/ifcfg-$ACTIVE_NET
    systemctl restart network;
    ip a
fi

# modules for avocado dependencies e.g. sle-module-legacy for bridge-utils
if ! echo $EXT_STATUS|grep sle-module-desktop-applications; then
    SUSEConnect -p sle-module-desktop-applications/$VERSION_ID/$ARCH
fi
if ! echo $EXT_STATUS|grep sle-module-development-tools; then
    SUSEConnect -p sle-module-development-tools/$VERSION_ID/$ARCH
fi
if ! echo $EXT_STATUS|grep sle-module-legacy; then
    SUSEConnect -p sle-module-legacy/$VERSION_ID/$ARCH
fi
if ! echo $EXT_STATUS|grep sle-module-public-cloud; then
    SUSEConnect -p sle-module-public-cloud/$VERSION_ID/$ARCH
fi

zypper -n in python3-avocado-plugins-vt || zypper -n in python2-avocado-plugins-vt
mkdir -p /var/lib/avocado/data/avocado-vt/images/
curl -O ftp://10.100.12.155/jeos-27-x86_64.qcow2.xz
mv jeos-27-x86_64.qcow2.xz /var/lib/avocado/data/avocado-vt/images/
echo n|avocado vt-bootstrap --vt-type qemu
sed -i 's/^arch =$/arch = x86_64/' /etc/avocado/conf.d/vt.conf
sed -i 's/^nettype =$/nettype = bridge/' /etc/avocado/conf.d/vt.conf
sed -i 's/^netdst =$/netdst = br0/' /etc/avocado/conf.d/vt.conf
sed -i 's/^netdst = virbr0$/netdst = br0/' /etc/avocado/conf.d/vt.conf
sed -i 's/^backup_image_before_test = True$/backup_image_before_test = False/' /etc/avocado/conf.d/vt.conf
sed -i 's/^restore_image_after_test = True$/restore_image_after_test = False/' /etc/avocado/conf.d/vt.conf
sed -i 's/^login_timeout = [0-9]*$/login_timeout = 25/' /var/lib/avocado/data/avocado-vt/backends/qemu/cfg/*
sed -i 's/^login_timeout = [0-9]*$/login_timeout = 25/' /var/lib/avocado/data/avocado-vt/test-providers.d/downloads/io-github-autotest-qemu/qemu/tests/cfg/*
sed -i 's/sleep_time = 90/sleep_time = 10/' /var/lib/avocado/data/avocado-vt/test-providers.d/downloads/io-github-autotest-qemu/qemu/tests/balloon_check.py
sed -i 's/timeout=360/timeout=20/' /var/lib/avocado/data/avocado-vt/test-providers.d/downloads/io-github-autotest-qemu/qemu/tests/nic_hotplug.py
sed -i 's/timeout=90/timeout=20/' /var/lib/avocado/data/avocado-vt/test-providers.d/downloads/io-github-autotest-qemu/qemu/tests/nic_hotplug.py
sed -i 's/ip, 10,/ip, 3,/' /var/lib/avocado/data/avocado-vt/test-providers.d/downloads/io-github-autotest-qemu/qemu/tests/nic_hotplug.py
sed -i 's/boot_menu_key = "f12"/boot_menu_key = "esc"/' /var/lib/avocado/data/avocado-vt/backends/qemu/cfg/subtests.cfg
egrep "^arch|^nettype|^netdst|^backup_image_before_test|^restore_image_after_test" /etc/avocado/conf.d/vt.conf
egrep ^login_timeout /var/lib/avocado/data/avocado-vt/backends/qemu/cfg/base.cfg
systemctl start openvswitch;
systemctl status openvswitch;
EOF
    script_output($avocado_setup, 700);
}

sub post_fail_hook {
    select_console('log-console');
    teardown();
    systemctl 'stop openvswitch';
}

sub test_flags {
    return {fatal => 1};
}

1;
