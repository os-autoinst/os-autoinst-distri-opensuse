# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HPC_Module: mrsh master
#    This test is setting up a mrsh scenario according to the testcase
#    described in FATE
# Maintainer: Kernel QE <kernel-qa@suse.de>
# Tags: https://fate.suse.com/321722

use Mojo::Base 'hpcbase', -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;

our $file = 'tmpresults.xml';

sub run {
    my $self = shift;
    select_serial_terminal();
    # Get number of nodes
    my $nodes = get_required_var("CLUSTER_NODES");

    # install mrsh
    my $rt = zypper_call('in mrsh mrsh-server');
    test_case('Installation', 'install mrsh', $rt);
    barrier_wait("MRSH_INSTALLATION_FINISHED");

    # Copy munge key to all slave nodes
    for (my $node = 1; $node < $nodes; $node++) {
        my $node_name = sprintf("mrsh-slave%02d", $node);
        exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root\@${node_name}:/etc/munge/munge.key");
    }
    barrier_wait("MRSH_KEY_COPIED");

    # start munge
    $self->enable_and_start('munge');
    barrier_wait("MRSH_MUNGE_ENABLED");
    barrier_wait("SLAVE_MRLOGIN_STARTED");

    # make sure that nobody has permissions for $serialdev to get openQA work properly
    assert_script_run("chmod 666 /dev/$serialdev");

    # run mrlogin, mrcp, and mrsh (as normal and local user, e.g. nobody)
    $self->switch_user('nobody');
    for (my $node = 1; $node < $nodes; $node++) {
        my $node_name = sprintf("mrsh-slave%02d", $node);
        enter_cmd("mrlogin ${node_name} ");
        sleep(1);
        assert_script_run('hostname|grep mrsh-slave01');
        enter_cmd("exit");
        sleep(1);
        assert_script_run('hostname|grep mrsh-master');
        $rt = (assert_script_run("mrsh ${node_name}  rm -f /tmp/hello")) ? 1 : 0;
        test_case('Delete file remotely', 'mrsh test remote deletion', $rt);
        assert_script_run("echo \"Hello world!\" >/tmp/hello");
        $rt = (assert_script_run("mrcp /tmp/hello ${node_name}:/tmp/hello")) ? 1 : 0;
        test_case('Create file remotely', 'mrsh test remote copy', $rt);
        assert_script_run("mrsh ${node_name}  cat /tmp/hello");
    }
    barrier_wait("MRSH_MASTER_DONE");
}

sub post_run_hook ($self) {
    pars_results('HPC mrsh tests', $file, @all_tests_results);
    parse_extra_log('XUnit', $file);
    $self->SUPER::post_run_hook();
}
sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->destroy_test_barriers();
    select_serial_terminal;
    $self->upload_service_log('munge');
}

1;
