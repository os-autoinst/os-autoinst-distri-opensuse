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

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # needed for script_output
    zypper_call 'in curl';

    my $counter = 1;
    my @repos   = split(/,/, get_var('AVOCADO_REPO'));
    for my $var (@repos) {
        zypper_call("--no-gpg-check ar -f $var 'AVOCADO_$counter'");
        $counter++;
    }
    zypper_call '--gpg-auto-import-keys ref';

    # setup bridge, add needed SCC modules and install avocado-vt, tune tests, timeouts, test fixes
    my $avocado_setup = <<'EOF';
#!/bin/bash
EXT_STATUS=$(SUSEConnect --status)
ARCH=$(uname -m)
. /etc/os-release
ACTIVE_NET=$(ip a|awk -F': ' '/state UP/ {print $2}'|head -n1)
interface="BOOTPROTO='none'\nSTARTMODE='auto'\nDHCLIENT_SET_DEFAULT_ROUTE='yes'"
bridge="BOOTPROTO='dhcp'\nBRIDGE='yes'\nBRIDGE_FORWARDDELAY='0'\nBRIDGE_PORTS='$ACTIVE_NET'\nBRIDGE_STP='off'\nDHCLIENT_SET_DEFAULT_ROUTE='yes'\nSTARTMODE='auto'"
echo -e $bridge >/etc/sysconfig/network/ifcfg-br0
echo -e $interface >/etc/sysconfig/network/ifcfg-$ACTIVE_NET
cat /etc/sysconfig/network/ifcfg-br0
cat /etc/sysconfig/network/ifcfg-$ACTIVE_NET
systemctl restart network;
ip a

# modules for avocado dependencies e.g. sle-module-legacy for bridge-utils
if [[ $VERSION_ID =~ '12' ]]; then
    if ! echo $EXT_STATUS|grep sle-sdk; then
        SUSEConnect -p sle-sdk/$VERSION_ID/$ARCH
    fi
    # legacy and public-cloud use only main version number
    VERSION_ID='12'
else
    if ! echo $EXT_STATUS|grep sle-module-desktop-applications; then
        SUSEConnect -p sle-module-desktop-applications/$VERSION_ID/$ARCH
    fi
    if ! echo $EXT_STATUS|grep sle-module-development-tools; then
        SUSEConnect -p sle-module-development-tools/$VERSION_ID/$ARCH
    fi
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

sub test_flags {
    return {fatal => 1};
}

1;
