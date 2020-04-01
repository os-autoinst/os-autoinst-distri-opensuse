# SUSE's openQA tests
#
# Copyright © 2018-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Block device layer tests
# Maintainer: Michael Moese <mmoese@suse.de>, Sebastian Chlad <schlad@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use repo_tools 'add_qa_head_repo';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    #below variable exposes blktests options to the openQA testsuite
    #definition, so that it allows flexible ways of re-runing the tests
    my $tests   = get_required_var('BLK_TESTS');
    my $quick   = get_required_var('BLK_QUICK');
    my $exclude = get_required_var('BLK_EXCLUDE');
    my $config  = get_required_var('BLK_CONFIG');
    my $device  = get_required_var('BLK_DEVICE_ONLY');

    add_qa_head_repo();
    zypper_call('in blktests');

    #install test specific tools
    zypper_call('in fio blktrace');

    my @tests = split(',', $tests);
    assert_script_run('cd /usr/lib/blktests');

    foreach my $i (@tests) {
        script_run("./check --quick=$quick $i", 240);
    }

    ##TODO: this can grown into stand-alone "runner" for blktests
    ##  and perhaps could be done the same way as xfstests? to be checked
    script_run('wget --quiet ' . data_url('kernel/post_process') . ' -O post_process');
    script_run('chmod +x post_process');
    script_run('./post_process');

    parse_extra_log('XUnit', 'results.xml');
    script_run('tar -zcvf results.tar.gz results');
    upload_logs('results.tar.gz');
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook { }

1;
