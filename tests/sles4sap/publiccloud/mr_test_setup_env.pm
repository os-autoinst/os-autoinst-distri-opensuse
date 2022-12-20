# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Set up public cloud instance testing environment for 'mr_test'
# Maintainer: QE-SAP <qe-sap@suse.de>
# Tags: TEAM-6709

use warnings;
use Mojo::Base 'publiccloud::basetest';
use publiccloud::ssh_interactive qw(select_host_console);
use testapi;
use Mojo::File 'path';
use publiccloud::utils;
use Data::Dumper;

sub test_flags {
    return {
        fatal => 1,
        milestone => 0,
        publiccloud_multi_module => 1
    };
}

sub run {
    my ($self, $run_args) = @_;
    my $mr_test_tar = 'mr_test-master.tar.gz';
    my $instance = $run_args->{my_instance};

    # Select console on the host, not the PC instance
    select_host_console();

    # Download mr_test and extract it to '/root' later
    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        my $tarball = get_var('MR_TEST_TARBALL', "https://gitlab.suse.de/qa/mr_test/-/archive/master/$mr_test_tar");
        assert_script_run "curl -sk $tarball -o /root/$mr_test_tar";
    }

    # Copy the code to instance
    my $remote = $run_args->{my_instance}->username . '@' . $run_args->{my_instance}->public_ip;
    $instance->scp("/root/$mr_test_tar", "$remote:/tmp");
    $instance->ssh_assert_script_run("sudo tar zxf /tmp/$mr_test_tar --strip-components 1 -C /root/");
    record_info('Copy mr_test code to instance OK');

    # Clear $instance->ssh_opts which omit the known hosts file and strict host checking by default
    $instance->ssh_opts('');
    $instance->network_speed_test();

    # Set ssh-tunnel
    $testapi::username = 'bernhard';
    prepare_ssh_tunnel($instance) if (get_var('TUNNELED'));
    record_info('Instance ssh-tunnel setting OK');
}

1;
