# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# semodule" command with options "-l / -d / -e" can work
# Maintainer: QE Security <none@suse.de>
# Tags: poo#63490, tc#1741286

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    my $test_module = "openvpn";

    $self->select_serial_terminal;

    # test option "-l": list and verify some (not all as it changes often) standard modules
    validate_script_output(
        "semodule -lstandard",
        sub {
            m/
            .*application.*auditadm.*authlogin.*base.*bootloader.*clock.*
            dbus.*dmesg.*fstools.*getty.*hostname.*init.*ipsec.*iptables.*
            kerberos.*libraries.*locallogin.*logadm.*logging.*lvm.*
            miscfiles.*modutils.*mount.*netlabel.*
            secadm.*selinuxutil.*setrans.*seunshare.*ssh.*
            staff.*su.*sudo.*sysadm.*sysadm_secadm.*sysnetwork.*
            systemd.*udev.*unconfined.*unconfineduser.*unlabelednet.*
            unprivuser.*userdomain.*usermanage.*xserver.*/sx
        });

    # test option "-d": to disable a module, enable it in case
    assert_script_run("semodule -e $test_module");
    assert_script_run("semodule -d $test_module");
    validate_script_output("semodule -lfull | grep -w $test_module", sub { m/100\ $test_module\ .*pp\ disabled/sx });

    # test option "-e": to enable a module
    assert_script_run("semodule -e $test_module");
    my $ret = script_run("semodule -lfull | grep -w $test_module | grep disabled");
    if (!$ret) {
        die "ERROR:\ \"$test_module\"\ module\ was\ not\ enabled!";
    }
    assert_script_run("semodule -lfull | grep -w $test_module", sub { m/100\ $test_module\ .*pp.*/sx });

    # test option "-l": list all modules and verify some of them (disabled + enabled)
    validate_script_output(
        "semodule -lfull",
        sub {
            m/
            100\ abrt.*pp\ disabled.*
            100\ apache.*pp.*
            100\ userdomain.*pp.*
            100\ zosremote.*pp\ disabled.*/sx
        });
}

1;
