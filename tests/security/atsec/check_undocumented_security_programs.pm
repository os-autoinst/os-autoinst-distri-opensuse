# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'Check for undocumented security-relevant programs' test case of ATSec test suite
# Maintainer: xiaojing.liu <xiaojing.liu@suse.com>
# Tags: poo#111671

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # The programs are defined by the FSP and corresponding man pages
    my $known_programs = {
        '/usr/bin/passwd' => 1,
        '/usr/bin/crontab' => 1,
        '/usr/bin/su' => 1,
        '/usr/bin/sudo' => 1,
        '/sbin/unix_chkpwd' => 1
    };

    # Search for setuid programs
    my $output = script_output('find / -user root -perm -4000 -exec ls -ls {} \; | grep -v ".snapshots"', proceed_on_failure => 1);

    # Add step results for each setuid program to show if it is known
    foreach my $info (split(/\n/, $output)) {
        my $program = (split(/\s+/, $info))[-1];
        if ($program !~ /^\//) {
            next;
        }
        unless ($known_programs->{$program}) {
            record_info($program, "This program is not in known list\n$info", result => 'fail');
            $self->result('fail');
            next;
        }
        record_info($program, "This is a known safe program\n$info");
    }
}

1;
