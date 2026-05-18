
# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: collect all coredumps
# Maintainer: Ondřej Súkup <osukup@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Logging qw(upload_coredumps cleanup_known_coredumps);
use version_utils qw(is_tumbleweed);
use utils qw(script_retry);

sub run {
    my $self = shift;
    select_serial_terminal;

    # Avoid tiny races where systemd-coredump is still busy compressing.
    # Otherwise we may get this on coredumpctl info:
    #   Timestamp: Sun 2026-05-17 23:34:06 CEST (684ms ago)
    # Note: We can't use systemd-coredump in pgrep because we'd get:
    #   pgrep: pattern that searches for process name longer than 15 characters will result in zero matches
    script_retry("pgrep systemd-cored >/dev/null", retry => 5, delay => 60);
    cleanup_known_coredumps unless is_tumbleweed;
    upload_coredumps;
}

1;
