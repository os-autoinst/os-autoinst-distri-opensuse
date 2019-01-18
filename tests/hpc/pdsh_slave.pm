# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: pdsh slave
#    This test is setting up a pdsh scenario according to the testcase
#    described in FATE
# Maintainer: soulofdestiny <mgriessmeier@suse.com>
# Tags: https://fate.suse.com/321714

use base "hpcbase";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;

sub run {
    my $self            = shift;
    my $server_hostname = get_required_var("PDSH_MASTER_HOSTNAME");

    my $packages_to_install = 'munge pdsh';
    $packages_to_install .= ' pdsh-genders' if get_var('PDSH_GENDER_TEST');
    zypper_call("in $packages_to_install");
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
    assert_script_run("pdsh -R mrsh $genders_plugin -w $server_hostname ls / &> /tmp/pdsh.log");
    upload_logs '/tmp/pdsh.log';
    barrier_wait("PDSH_SLAVE_DONE");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    upload_logs '/tmp/pdsh.log';
    $self->upload_service_log('munge');
}

1;
