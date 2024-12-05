# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: valkey tests
# - install valkey and start valkey-server
# - connect to valkey client and perform few CRUD ops
# - load a test db from the data dir
# - start another valkey instance with a different port
# - make new instance a replica of the earlier instance
#
# Maintainer: QE-Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call script_retry validate_script_output_retry);
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    my $self = shift;
    select_serial_terminal;

    # install valkey package
    zypper_call 'in valkey';
    assert_script_run('valkey-server --version');

    # start valkey server on port 6379 and test that it works
    assert_script_run('valkey-server --daemonize yes --logfile /var/log/valkey/valkey-server_6379.log');
    script_retry('valkey-cli ping', delay => 5, retry => 12);
    validate_script_output_retry('valkey-cli ping', sub { m/PONG/ }, delay => 5, retry => 12);

    # test some valkey cli commands
    validate_script_output('valkey-cli set foo bar', sub { m/OK/ });
    validate_script_output('valkey-cli get foo', sub { m/bar/ });
    validate_script_output('valkey-cli pfselftest', sub { m/OK/ });
    validate_script_output('valkey-cli flushdb', sub { m/OK/ });
    validate_script_output('valkey-cli get foo', sub { !m/bar/ });

    assert_script_run 'curl -O ' . data_url('console/movies.redis');
    assert_script_run('valkey-cli -h localhost -p 6379 < ./movies.redis');

    validate_script_output('valkey-cli HMGET "movie:343" title', sub { m/Spider-Man/ });

    # start valkey server on port 6380 and test that it works
    assert_script_run('valkey-server --daemonize yes --port 6380 --logfile /var/log/valkey/valkey-server_6380.log');
    validate_script_output_retry('valkey-cli -p 6380 ping', sub { m/PONG/ }, delay => 5, retry => 12);

    # make 6380 instance a replica of valkey instance running on port 6379
    assert_script_run('valkey-cli -p 6380 replicaof localhost 6379');

    # test master knows about the slave and vice versa
    validate_script_output_retry('valkey-cli info replication', sub { m/connected_slaves:1/ }, delay => 5, retry => 12);
    validate_script_output('valkey-cli -p 6380 info replication', sub { m/role:slave/ });

    # test that the synchronization finished and the data are reachable from slave
    validate_script_output_retry('valkey-cli info replication', sub { m/state=online/ }, delay => 5, retry => 12);
    validate_script_output('valkey-cli -p 6380 HMGET "movie:343" title', sub { m/Spider-Man/ });
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
    upload_logs('/var/log/valkey/valkey-server_6379.log');
    upload_logs('/var/log/valkey/valkey-server_6380.log');
    assert_script_run('valkey-cli -h localhost flushall');
    assert_script_run('killall valkey-server');
    assert_script_run('rm -f movies.redis');
}

1;
