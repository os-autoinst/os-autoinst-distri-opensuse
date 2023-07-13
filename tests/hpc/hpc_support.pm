# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HPC support node
#    This tests only ensure the availability of a node which could hold some
#    supportive services, like for instance required database
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::configs hpc::migration);
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;
use version_utils 'is_sle';

sub prepare_db {
    my $hostname = get_required_var("HOSTNAME");

    assert_script_run("mysql -uroot -e \"CREATE DATABASE slurm_acct_db;\"");
    assert_script_run("mysql -uroot -e \"CREATE USER \'slurm\'@\'$hostname.openqa.test\' IDENTIFIED BY \'password\';\"");
    assert_script_run("mysql -uroot -e \"GRANT ALL ON slurm_acct_db.* TO \'slurm\'@\'$hostname.openqa.test\';\"");
    assert_script_run("mysql -uroot -e \"FLUSH PRIVILEGES;\"");
}

sub run {
    my $self = shift;
    $self->prepare_user_and_group();

    # make sure products are registered; it might happen that the older SPs aren't
    # register with valid scc regcode
    if (get_var("HPC_MIGRATION")) {
        $self->register_products();
        barrier_wait("HPC_PRE_MIGRATION");
    }

    zypper_call("in slurm-munge slurm-slurmdbd mariadb ganglia-gmond");
    # install slurm-node if sle15, not available yet for sle12
    zypper_call('in slurm-node') if is_sle '15+';

    systemctl("start mariadb");
    systemctl("is-active mariadb");

    # allow hostnames other than localhost
    my $config = << "EOF";
sed -i "/^bind-address.*/c\\#bind-address" /etc/my.cnf
EOF
    assert_script_run($_) foreach (split /\n/, $config);
    systemctl("restart mariadb");
    systemctl("is-active mariadb");
    record_info("mariadb conf", script_output("cat /etc/my.cnf"));

    prepare_db();

    systemctl("restart mariadb");
    systemctl("is-active mariadb");

    $self->prepare_slurmdb_conf();
    record_info("slurmdbd conf", script_output("cat /etc/slurm/slurmdbd.conf"));
    $self->enable_and_start("slurmdbd");
    systemctl("is-active slurmdbd");

    barrier_wait("HPC_SETUPS_DONE");
    barrier_wait("HPC_MASTER_SERVICES_ENABLED");

    # enable and start munge
    $self->enable_and_start("munge");
    systemctl("is-active munge");
    record_info("munge is enabled as desired by slurmdbd");

    $self->enable_and_start("gmond");
    systemctl("is-active gmond");

    # enable and start slurmd
    $self->enable_and_start("slurmd");
    systemctl("is-active slurmd");

    barrier_wait("HPC_SLAVE_SERVICES_ENABLED");
    barrier_wait("HPC_MASTER_RUN_TESTS");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    $self->upload_service_log('slurmd');
    $self->upload_service_log('munge');
    $self->upload_service_log('slurmdbd');
    upload_logs('/var/log/slurmdbd.log');
}

1;
