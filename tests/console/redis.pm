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

sub wait_serial_or_die {
    my ($feedback, %args) = @_;
    $args{timeout} //= 10;

    my $e = wait_serial($feedback, %args);

    die('Unexpected serial output') unless (defined $e);
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # install redis package
    zypper_call 'in redis';

    # start redis server
    background_script_run('redis-server');
    wait_still_screen(5);

    # test if redis cli is working
    enter_cmd('redis-cli');
    wait_serial_or_die('127.0.0.1:6379');
    enter_cmd('quit');

    # test some redis cli commands
    validate_script_output('redis-cli ping', sub { m/PONG/ });
    validate_script_output('redis-cli set foo bar', sub { m/OK/ });
    validate_script_output('redis-cli get foo', sub { m/bar/ });
    validate_script_output('redis-cli pfselftest', sub { m/OK/ });
    validate_script_output('redis-cli flushdb', sub { m/OK/ });
    validate_script_output('redis-cli get foo', sub { m/(nil)/ });

    assert_script_run 'curl -O ' . data_url('console/movies.redis');
    assert_script_run('redis-cli -h localhost -p 6379 < ./movies.redis');
    wait_still_screen(5);

    validate_script_output('redis-cli HMGET "movie:343" title', sub { m/Spider-Man/ });

    # start another redis instance with a different port
    background_script_run('redis-server --port 6380');
    wait_still_screen(5);

    # get redis cli prompt of new instance
    enter_cmd('redis-cli -p 6380');
    wait_serial_or_die('127.0.0.1:6380');
    enter_cmd('quit');

    # make 6380 instance a replica of redis instance running on port 6379
    assert_script_run('redis-cli -p 6380 replicaof localhost 6379');
    wait_still_screen(5);

    # test replication
    validate_script_output('redis-cli info replication', sub { m/connected_slaves:1/ });
    validate_script_output('redis-cli -p 6380 info replication', sub { m/role:slave/ });
    validate_script_output('redis-cli -p 6380 HMGET "movie:343" title', sub { m/Spider-Man/ });
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
}

1;
