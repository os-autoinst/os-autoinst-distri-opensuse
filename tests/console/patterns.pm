# SUSE's openQA tests
#
# Copyright 2016-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test pattern selection for system role 'kvm host'
# Maintainer: Christopher Hofmann <cwh@suse.de>, QE Core <qe-core@suse.de>
# Tags: fate#317481 poo#16650

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    # System roles are defined in config.xml. Currently the role 'kvm host'
    # defines kvm_server as an additional pattern, xen_server defines 'xen host'.
    die "Only kvm|xen roles are supported" unless get_var('SYSTEM_ROLE', '') =~ /kvm|xen/;
    my $pattern_name = get_required_var('SYSTEM_ROLE') . '_server';
    record_info('Show only installed patterns', script_output('zypper patterns -i'));
    assert_script_run("zypper patterns -i | grep $pattern_name");
}

sub post_fail_hook {
    select_console 'log-console';
    upload_logs "/var/log/zypper.log";
}

1;
