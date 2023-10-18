# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: slurm db node
#    This tests only ensure the proper db is being set for the HPC cluster, so
#    that the slurm db accounting can be configured
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::configs), -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;
use hpc::utils 'get_slurm_version';
use version_utils 'is_sle';

sub run ($self) {
    select_serial_terminal();
    my $hostname = get_required_var("HOSTNAME");
    my $slurm_pkg = get_slurm_version(get_var('SLURM_VERSION', ''));

    barrier_wait('CLUSTER_PROVISIONED');

    $self->prepare_user_and_group();

    # Install slurm
    # $slurm_pkg-munge is installed explicitly since slurm_23_02
    zypper_call("in $slurm_pkg $slurm_pkg-munge $slurm_pkg-slurmdbd");
    zypper_call("in $slurm_pkg-node");

    my $mariadb_service = "mariadb";
    $mariadb_service = "mysql" if is_sle('<12-sp4');

    #for all slurm versions we have mariadb as a dependency apart from slurm18
    #TODO: remove below line as soon as not needed
    zypper_call("in mariadb") if $slurm_pkg =~ "slurm_18";
    systemctl("start $mariadb_service");
    systemctl("is-active $mariadb_service");

    # allow hostnames other than localhost
    my $config = << "EOF";
sed -i "/^bind-address.*/c\\#bind-address" /etc/my.cnf
EOF
    assert_script_run($_) foreach (split /\n/, $config);
    systemctl("restart $mariadb_service");
    systemctl("is-active $mariadb_service");
    record_info("mariadb conf", script_output("cat /etc/my.cnf"));

    # handle db preparation
    assert_script_run("mysql -uroot -e \"CREATE DATABASE slurm_acct_db;\"");
    assert_script_run("mysql -uroot -e \"CREATE USER \'slurm\'@\'$hostname.openqa.test\' IDENTIFIED BY \'password\';\"");
    assert_script_run("mysql -uroot -e \"CREATE USER \'slurm\'@\'master-node00.openqa.test\' IDENTIFIED BY \'password\';\"");
    # Handle permissons for master node
    assert_script_run("mysql -uroot -e \"GRANT ALL ON slurm_acct_db.* TO \'slurm\'@\'$hostname.openqa.test\';\"");
    assert_script_run("mysql -uroot -e \"GRANT ALL ON slurm_acct_db.* TO \'slurm\'@\'master-node00.openqa.test\';\"");
    assert_script_run("mysql -uroot -e \"FLUSH PRIVILEGES;\"");

    systemctl("restart $mariadb_service");
    systemctl("is-active $mariadb_service");

    barrier_wait("SLURM_SETUP_DONE");

    ## munge must start before other slurm daemons
    $self->enable_and_start('munge');
    systemctl('is-active munge');
    $self->prepare_slurmdb_conf();
    record_info("slurmdbd conf", script_output("cat /etc/slurm/slurmdbd.conf"));
    $self->enable_and_start("slurmdbd");
    systemctl('is-active slurmdbd');
    # wait for slurmdbd sockets to avoid 'Connection refused'
    assert_script_run('until ss -apn|grep pid=$(pidof slurmdbd)|grep LIST; do echo "waiting for slurmdb daemon"; done');
    assert_script_run('sacctmgr -i add cluster linux');
    barrier_wait('SLURM_SETUP_DBD');
    barrier_wait("SLURM_MASTER_SERVICE_ENABLED");

    systemctl('restart slurmdbd');
    systemctl('is-active slurmdbd');
    $self->enable_and_start('slurmd');
    systemctl('is-active slurmd');

    barrier_wait("SLURM_SLAVE_SERVICE_ENABLED");

    # always upload logs from slurmdbd as those are crucial and there is no simple
    # way to get those logs if slurctld fails
    upload_logs('/var/log/slurmdbd.log');

    barrier_wait("SLURM_MASTER_RUN_TESTS");
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    select_serial_terminal;
    $self->upload_service_log('slurmd');
    $self->upload_service_log('munge');
    $self->upload_service_log('slurmdbd');
    upload_logs('/var/log/slurmdbd.log');
}

1;
