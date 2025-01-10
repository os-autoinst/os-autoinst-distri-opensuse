# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: verify expected setroubleshootd behavior
#  - Install the package setroubleshoot-server, check that it installs setroubleshoot-plugins
#  - Check setroubleshootd DBus activation only via systemd service.
#  - Check if is-active shows inactive at first, then after restart shows active at first
#    but after about 15 seconds it should be no longer active again.
#  - Check setroubleshootd invoking via polkit as root, see
#    /usr/share/dbus-1/system.d/org.fedoraproject.SetroubleshootFixit.conf
# Maintainer: QE Security <none@suse.de>
# Tags: poo#174175

use base "selinuxtest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_sle';

sub ensure_setroubleshootd_cannot_be_directly_run_as_root {
    # ensure current test is run as root user
    validate_script_output 'id', sub { m/uid=0\(root\)/ };
    # ensure setroubleshootd cannot be run as root
    my $errmsg = 'org.freedesktop.DBus.Error.AccessDenied: Request to own name refused by policy';
    validate_script_output('setroubleshootd -d -f 2>&1', sub { m/$errmsg/ }, proceed_on_failure => 1);
}

# ensure service is inactive; then after restart should be active, and inactive again after some time
sub validate_service_restart {
    validate_script_output('systemctl is-active setroubleshootd.service', sub { m/inactive/ }, proceed_on_failure => 1);
    validate_script_output('systemctl restart setroubleshootd;systemctl is-active setroubleshootd.service;sleep 15;systemctl is-active setroubleshootd.service', sub { m/active.*inactive/s }, proceed_on_failure => 1);
}

sub validate_invocation_via_polkit() {
    # check for invoking via polkit as root
    my $cmd = 'pkcheck -p $$ -a org.fedoraproject.setroubleshootfixit.write';
    assert_script_run qq{runuser root -c "$cmd"};
    # should fail when run as non-privileged user
    validate_script_output(qq{runuser bernhard -c "$cmd"},
        sub { m/GDBus.Error:org.freedesktop.PolicyKit1.Error.NotAuthorized: Only trusted callers/ },
        proceed_on_failure => 1);
}

sub run {
    my ($self) = shift;
    select_serial_terminal;
    if (is_sle) {    # bail out on SLE
        record_info 'TEST SKIPPED', 'setroubleshootd is not yet implemented on SLE';
        return;
    }
    # ensure selinux is in enforcing mode
    validate_script_output 'getenforce', sub { m/Enforcing/ };
    # ensure pkg installation
    zypper_call 'in setroubleshoot-server';
    assert_script_run 'rpm -q setroubleshoot-plugins';
    ensure_setroubleshootd_cannot_be_directly_run_as_root;
    validate_service_restart;
    validate_invocation_via_polkit;
}

1;
