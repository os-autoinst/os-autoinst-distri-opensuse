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

sub run {
    select_serial_terminal;

    zypper_call('in valkey openssl wget');

    record_info('Generate Test Certificates');
    assert_script_run('mkdir -p valkey/tls/server');
    assert_script_run('mkdir -p valkey/tls/replica');
    assert_script_run('cd valkey/tls');
    # CA
    assert_script_run('openssl genrsa -out ca.key 4096');
    assert_script_run('openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj "/"');
    # Master
    assert_script_run('openssl genrsa -out server/valkey.key 2048');
    assert_script_run('openssl req -new -key server/valkey.key -out server/valkey.csr -subj "/"');
    assert_script_run('openssl x509 -req -in server/valkey.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server/valkey.crt -days 365 -sha256');
    # Replica
    assert_script_run('openssl genrsa -out replica/valkey.key 2048');
    assert_script_run('openssl req -new -key replica/valkey.key -out replica/valkey.csr -subj "/"');
    assert_script_run('openssl x509 -req -in replica/valkey.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out replica/valkey.crt -days 365 -sha256');

    record_info('Start master server');
    assert_script_run 'wget --quiet ' . data_url('valkey/valkey.conf');
    assert_script_run('valkey-server valkey.conf');
    upload_logs("/var/log/valkey/valkey_6379.log");

    record_info('Start replica server');
    assert_script_run 'wget --quiet ' . data_url('valkey/replica.conf');
    assert_script_run('valkey-server replica.conf');
    upload_logs("/var/log/valkey/valkey_6380.log");

    record_info('Master/replica check');
    my $MASTER_VALKEY_CLI = 'valkey-cli --tls --cert server/valkey.crt --key server/valkey.key --cacert ca.crt -p 6379';
    my $REPLICA_VALKEY_CLI = 'valkey-cli --tls --cert replica/valkey.crt --key replica/valkey.key --cacert ca.crt -p 6380';
    validate_script_output_retry($MASTER_VALKEY_CLI . " info replication", sub { m/connected_slaves:1/ }, delay => 5, retry => 4);
    validate_script_output_retry($REPLICA_VALKEY_CLI . " info replication", sub { m/master_link_status:up/ }, delay => 5, retry => 4);

    record_info('Client tests with master');
    validate_script_output($MASTER_VALKEY_CLI . " ping", sub { m/PONG/ });
    validate_script_output($MASTER_VALKEY_CLI . " set mykey 'valkey'", sub { m/OK/ });
    validate_script_output($MASTER_VALKEY_CLI . " get mykey", sub { m/valkey/ });
    assert_script_run 'wget --quiet ' . data_url('console/movies.redis');
    assert_script_run($MASTER_VALKEY_CLI . " -h localhost < ./movies.redis");
    validate_script_output($MASTER_VALKEY_CLI . ' HMGET "movie:343" title', sub { m/Spider-Man/ });

    record_info('Client tests with replica');
    validate_script_output($REPLICA_VALKEY_CLI . " ping", sub { m/PONG/ });
    validate_script_output($REPLICA_VALKEY_CLI . " get mykey", sub { m/valkey/ });
    validate_script_output($REPLICA_VALKEY_CLI . ' HMGET "movie:343" title', sub { m/Spider-Man/ });

    record_info('Clean up');
    clean_up();
}

sub clean_up {
    script_run('valkey-cli --tls --cert server/valkey.crt --key server/valkey.key --cacert ca.crt -h localhost flushall');
    script_run('killall valkey-server');
    upload_logs("/var/log/valkey/valkey_6379.log");
    upload_logs("/var/log/valkey/valkey_6380.log");
}

sub post_fail_hook {
    my $self = shift;
    $self->clean_up();
    $self->SUPER::post_fail_hook;
}

1;
