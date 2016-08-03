# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case 1463314  - FIPS: systemd

use base "consoletest";
use strict;
use testapi;

sub run() {

    select_console "root-console";
    assert_script_run("echo 'Seal=yes' >> /etc/systemd/journald.conf");
    assert_script_run("mkdir -p /var/log/journal");
    assert_script_run("systemctl restart systemd-journald.service");
    assert_script_run("journalctl --setup-keys");
    assert_screen("journalctl-qr");
    assert_script_run("journalctl --setup-keys --force | tee /tmp/key");
    assert_script_run("journalctl --verify --verify-key=`cat /tmp/key`");
    assert_script_run("rm -f /tmp/key");
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
