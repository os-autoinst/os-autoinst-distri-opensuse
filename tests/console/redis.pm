# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: redis tests
# - install redis and start redis-server
# - connect to redis client and perform few CRUD ops
# - load a test db from the data dir
# - start another redis instance with a different port
# - make new instance a replica of the earlier instance
#
# Maintainer: QE-Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils;
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # install redis package
    zypper_call 'in redis';

    # start redis server on port 6379 and 6380
    background_script_run('redis-server');
    wait_still_screen(5);
    background_script_run('redis-server --port 6380');
    wait_still_screen(5);
    assert_script_run 'curl -O ' . data_url('console/movies.redis');
    run_script('redis_cli.sh');
}

sub run_script {
    my $script = shift;
    record_info($script, "Running shell script: $script");
    assert_script_run("curl " . data_url("console/$script") . " -o '$script'");
    assert_script_run("chmod a+rx '$script'");
    assert_script_run("./$script");
}

sub post_fail_hook {
    my $self = shift;
    $self->cleanup();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my $self = shift;
    $self->cleanup();
    $self->SUPER::post_run_hook;
}

sub cleanup {
    script_run('redis-cli -h localhost flushall');
    wait_still_screen(5);
    script_run('killall redis-server');
    wait_still_screen(5);
    script_run('rm -f movies.redis');
    wait_still_screen(5);
    script_run('rm -f redis_cli.sh');
}

1;
