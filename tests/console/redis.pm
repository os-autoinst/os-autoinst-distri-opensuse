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
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call script_retry validate_script_output_retry);
use registration qw(add_suseconnect_product get_addon_fullname);
use version_utils qw(is_sle);

# https://jira.suse.com/browse/PED-11976
my @redis_versions = is_sle('=15-SP7') ? ("valkey-compat-redis") : ("redis");
push(@redis_versions, 'redis7') unless is_sle('<=15-sp4') || is_sle('>15-sp6');
my %ROLES = (
    MASTER => 'MASTER',
    REPLICA => 'REPLICA',
);
my $base_port = 6379;
my %PORTS = map { $ROLES{$_} => $base_port++ } keys %ROLES;
my %REDIS_CLI_CMD = map {
    $_ => "redis-cli -p " . $PORTS{$ROLES{$_}}
} keys %ROLES;

my %logfile_locations = map {
    my $version = $_;
    $version => {
        map {
            $ROLES{$_} => "/var/log/redis/redis-server_" . $version . "_${\lc($ROLES{$_})}" . ".log"
        } keys %ROLES
    }
} @redis_versions;
my $killall_redis_server_cmd = "killall redis-server";
my $remove_test_db_file_cmd = "rm -f movies.redis";

sub test_ping {
    my (%args) = @_;
    $args{target} //= $ROLES{MASTER};
    record_info("Test ping to target: " . $args{target});
    die("Invalid target: " . $args{target}) unless exists $REDIS_CLI_CMD{$args{target}};
    my $cmd = $REDIS_CLI_CMD{$args{target}};
    script_retry("$cmd ping", delay => 5, retry => 12);
    validate_script_output_retry("$cmd ping", sub { m/PONG/ }, delay => 5, retry => 12);
}

sub test_crud {
    record_info("Test Create Read Update Delete");
    validate_script_output($REDIS_CLI_CMD{$ROLES{MASTER}} . " set foo bar", sub { m/OK/ });
    validate_script_output($REDIS_CLI_CMD{$ROLES{MASTER}} . " get foo", sub { m/bar/ });
    validate_script_output($REDIS_CLI_CMD{$ROLES{MASTER}} . " pfselftest", sub { m/OK/ });
    validate_script_output($REDIS_CLI_CMD{$ROLES{MASTER}} . " flushdb", sub { m/OK/ });
    validate_script_output($REDIS_CLI_CMD{$ROLES{MASTER}} . " get foo", sub { !m/bar/ });
}

sub load_test_db_and_validate {
    record_info("Load test database and validate data");
    assert_script_run 'curl -O ' . data_url('console/movies.redis');
    assert_script_run($REDIS_CLI_CMD{$ROLES{MASTER}} . " < ./movies.redis");
    validate_script_output($REDIS_CLI_CMD{$ROLES{MASTER}} . " HMGET \"movie:343\" title", sub { m/Spider-Man/ });
}

sub verify_replication_status {
    record_info("Verify replication status");
    validate_script_output_retry($REDIS_CLI_CMD{$ROLES{MASTER}} . " info replication", sub { m/connected_slaves:1/ }, delay => 5, retry => 12);
    validate_script_output($REDIS_CLI_CMD{$ROLES{REPLICA}} . " info replication", sub { m/role:slave/ });
    validate_script_output_retry($REDIS_CLI_CMD{$ROLES{REPLICA}} . " info replication", sub { m/master_link_status:up/ }, delay => 5, retry => 12);
}

sub configure_and_test_master {
    record_info("Configure and test master");
    test_ping(target => $ROLES{MASTER});
    test_crud();
    load_test_db_and_validate();
}

sub configure_and_test_replica {
    record_info("Configure and test replica");
    test_ping(target => $ROLES{REPLICA});
    assert_script_run($REDIS_CLI_CMD{$ROLES{REPLICA}} . " replicaof localhost " . $PORTS{$ROLES{MASTER}});
    verify_replication_status();
    validate_script_output($REDIS_CLI_CMD{$ROLES{REPLICA}} . " HMGET \"movie:343\" title", sub { m/Spider-Man/ });
}

sub cleanup_redis {
    record_info("Cleanup after testing");
    foreach my $role (values %ROLES) {
        assert_script_run($REDIS_CLI_CMD{$role} . " flushall");
    }
    my $redis_conf_dir = script_output("redis-cli config get dir | tail -n 1") // '/';
    assert_script_run($killall_redis_server_cmd);
    assert_script_run($remove_test_db_file_cmd);
    assert_script_run("find $redis_conf_dir -type f -name 'dump.rdb' -print -exec rm -f {} + || true", timeout => 180);
}

sub upload_redis_logs {
    my (%args) = @_;
    $args{redis_version} //= $redis_versions[0];
    record_info("Upload logs for " . $args{redis_version});
    foreach my $role (values %ROLES) {
        my $logfile = $logfile_locations{$args{redis_version}}{$role};
        upload_logs($logfile) if -e $logfile;
    }
}

sub test_redis {
    my (%args) = @_;
    $args{redis_version} //= $redis_versions[0];
    zypper_call('in --force-resolution --solver-focus Update ' . $args{redis_version});
    record_info("Testing " . $args{redis_version});
    foreach my $role (values %ROLES) {
        my $port = $PORTS{$role};
        my $logfile = $logfile_locations{$args{redis_version}}{$role};
        my $redis_server_cmd = "redis-server --daemonize yes --port $port --logfile $logfile";
        assert_script_run($redis_server_cmd);
    }
    configure_and_test_master();
    configure_and_test_replica();
    cleanup_redis();
    upload_redis_logs(redis_version => $args{redis_version});
}

sub run {
    my $self = shift;
    select_serial_terminal;

    # For redis is removed from 15-SP7, so the log directory doesn't exist, which will cause failure.
    # So create this directory as a workaround.
    my $log_dir = "/var/log/redis/";
    if (script_run("test -d $log_dir") != 0) {
        record_info("Workaround for poo#179867");
        script_run("mkdir -p $log_dir");
    }

    foreach my $redis_version (@redis_versions) {
        test_redis(redis_version => $redis_version);
    }
}

sub post_fail_hook {
    my $self = shift;
    script_run($killall_redis_server_cmd);
    script_run($remove_test_db_file_cmd);
    foreach my $redis_version (@redis_versions) {
        upload_redis_logs(redis_version => $redis_version);
    }
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my $self = shift;
    zypper_call('rm -u ' . $redis_versions[-1]);
    $self->SUPER::post_run_hook;
}

1;
