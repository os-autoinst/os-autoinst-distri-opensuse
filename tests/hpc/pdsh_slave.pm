# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HPC_Module: pdsh slave
#    This test is setting up a pdsh scenario according to the testcase
#    described in FATE
# Maintainer: Kernel QE <kernel-qa@suse.de>
# Tags: https://fate.suse.com/321714

use Mojo::Base 'hpcbase', -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;

our $file = 'tmpresults.xml';

sub run ($self) {
    my $server_hostname = get_required_var("PDSH_MASTER_HOSTNAME");

    my $packages_to_install = 'munge pdsh';
    $packages_to_install .= ' pdsh-genders' if get_var('PDSH_GENDER_TEST');
    my $rt = zypper_call("in $packages_to_install");
    test_case('Install packages', 'pdsh installation', $rt);
    barrier_wait("PDSH_INSTALLATION_FINISHED");
    barrier_wait("PDSH_KEY_COPIED");

    # start munge
    $self->enable_and_start('munge');
    barrier_wait("PDSH_MUNGE_ENABLED");
    barrier_wait("MRSH_SOCKET_STARTED");

    assert_script_run('echo  "' . $server_hostname . ' type=genders-test" >> /etc/genders') if get_var('PDSH_GENDER_TEST');

    # make sure that user 'nobody' has permissions for $serialdev to get openQA work properly
    assert_script_run("chmod 666 /dev/$serialdev");

    $self->switch_user('nobody');
    my $genders_plugin = get_var('PDSH_GENDER_TEST') ? '-g type=genders-test' : '';
    $rt = assert_script_run("pdsh -R mrsh $genders_plugin -w $server_hostname ls / &> /tmp/pdsh.log");
    test_case('Run remotelly mrsh module on the server', 'pdsh remote invocation', $rt);
    assert_script_run("test -s /tmp/pdsh.log");
    upload_logs '/tmp/pdsh.log';
    barrier_wait("PDSH_SLAVE_DONE");
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_run_hook ($self) {
    pars_results('HPC pdsh tests', $file, @all_tests_results);
    parse_extra_log('XUnit', $file);
    $self->SUPER::post_run_hook();
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    select_serial_terminal;
    upload_logs '/tmp/pdsh.log';
    $self->upload_service_log('munge');
}

1;
