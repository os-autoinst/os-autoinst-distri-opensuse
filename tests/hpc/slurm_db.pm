# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: slurm db node
#    This tests only ensure the proper db is being set for the HPC cluster, so
#    that the slurm db accounting can be configured
# Maintainer: Sebastian Chlad <schlad@suse.de>

use base "hpcbase";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use version_utils 'is_sle';

sub run {
    my $self     = shift;
    my $hostname = get_required_var("HOSTNAME");
    $self->prepare_user_and_group();

    # Install slurm
    zypper_call("in slurm-munge slurm-slurmdbd");
    # install slurm-node if sle15, not available yet for sle12
    zypper_call('in slurm-node') if is_sle '15+';

    zypper_call("in mariadb");
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

    # handle db preparation
    assert_script_run("mysql -uroot -e \"CREATE DATABASE slurm_acct_db;\"");
    assert_script_run("mysql -uroot -e \"CREATE USER \'slurm\'@\'$hostname.openqa.test\' IDENTIFIED BY \'password\';\"");
    assert_script_run("mysql -uroot -e \"GRANT ALL ON slurm_acct_db.* TO \'slurm\'@\'$hostname.openqa.test\';\"");
    assert_script_run("mysql -uroot -e \"FLUSH PRIVILEGES;\"");

    systemctl("restart mariadb");
    systemctl("is-active mariadb");

    $self->prepare_slurmdb_conf();
    record_info("slurmdbd conf", script_output("cat /etc/slurm/slurmdbd.conf"));
    $self->enable_and_start("slurmdbd");
    systemctl "status slurmdbd";

    barrier_wait("SLURM_SETUP_DONE");
    barrier_wait("SLURM_MASTER_SERVICE_ENABLED");

    # enable and start munge
    $self->enable_and_start("munge");
    record_info("munge is enabled as desired by slurmdbd");

    # enable and start slurmd
    $self->enable_and_start('slurmd');
    systemctl 'status slurmd';

    barrier_wait("SLURM_SLAVE_SERVICE_ENABLED");
    barrier_wait("SLURM_MASTER_RUN_TESTS");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->upload_service_log('slurmd');
    $self->upload_service_log('munge');
    $self->upload_service_log('slurmdbd');
    upload_logs('/var/log/slurmdbd.log');
}

1;
