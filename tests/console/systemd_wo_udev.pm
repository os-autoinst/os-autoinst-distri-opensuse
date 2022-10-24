# SUSE's openQA tests
#
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: systemd has no direct dependency for udev package
# Maintainer: QA-C <qa-c@suse.de>
# Tags: SLE-21856

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal qw(select_serial_terminal);

sub run {
    select_serial_terminal;
    script_run("zypper if --requires systemd | grep udev") or
      die 'systemd on sle15sp4+, leap15.4+ and TW should have no dependency to udev package!';
}

sub post_fail_hook {
    upload_logs('/var/log/zypper.log', failok => 1);
    upload_logs('/var/log/zypp/history', failok => 1);
}

1;
