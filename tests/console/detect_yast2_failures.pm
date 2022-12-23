# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Decompress y2log files, as given in test data and parse for failures.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

sub run {
    my $self = shift;
    select_console 'root-console';
    assert_script_run("mkdir -p /tmp/var/log; tar -xvf '/tmp/y2logs.tar.bz2' -C " . "/tmp/var/log");
    $self->investigate_yast2_failure(logs_path => '/tmp');
}

1;

