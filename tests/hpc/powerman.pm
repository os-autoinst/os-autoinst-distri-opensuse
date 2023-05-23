# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HPC_Module: Add test for powerman package
#
#    https://fate.suse.com/321725
#
#    This tests the powerman package from the HPC module
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'hpcbase', -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use susedistribution;

our $cfg_file = "/etc/powerman/powerman.conf";
our $file = 'tmpresults.xml';

our $dev_caps = sub {
    my $dev = shift;
    my %dat;
    my $dev_file_cnt = script_output("cat /etc/powerman/${dev}.dev");
    ($dat{$1} = 1) while $dev_file_cnt =~ m/script (.*)\W\S/g;
    return \%dat;
};

sub run ($self) {
    zypper_call('in powerman');
    my $powerman_dev = 'bashfun';
    assert_script_run("touch $file");
    my $cfg_file = "/etc/powerman/powerman.conf";
    my $hostname = script_output('hostname');
    test_case('hostname', 'Check hostname', $hostname);

    assert_script_run(
        "echo \"\$(cat >> $cfg_file <<EOF
listen \"0.0.0.0:10101\"
include \"/etc/powerman/$powerman_dev.dev\"
device \"test\" \"$powerman_dev\" \"/bin/bash |&\"
node \"$hostname\" \"test\" \"1\"
EOF
        )\""
    );
    record_info("$cfg_file", script_output("cat $cfg_file"));
    record_info('bashrun specs', script_output("cat /etc/powerman/$powerman_dev.dev"));
    my $powerman_dev_caps = $dev_caps->($powerman_dev);
    record_info 'info', $powerman_dev_caps;

    # enable and start service
    $self->enable_and_start('powerman');

    # list available targets
    my $rt = validate_script_output("powerman -l", sub { m/$hostname/ });
    test_case('Test powerman -l', 'powerman can find nodes', $rt);

    # check if target can be turned on
    $rt = (assert_script_run("powerman -1 \$(hostname)")) ? 1 : 0;
    test_case('powerman on', 'powerman can turn on nodes', $rt);

    $rt = validate_script_output("powerman -Q \$(hostname)", sub { /on:\s+$hostname.*/ });
    test_case('powerman list online nodes', 'powerman can find nodes', $rt);

    # check if target can be turned off
    $rt = (assert_script_run("powerman -0 \$(hostname)")) ? 1 : 0;
    test_case('powerman off', 'powerman can turn off nodes', $rt);
    $rt = (validate_script_output("powerman -Q \$(hostname)", sub { /off:\s+$hostname.*/ })) ? 1 : 0;
    test_case('powerman list online nodes', 'powerman can turn off nodes', $rt);

    # check if command can be handled by power control device
    # This depends on the device/driver type.
    # Power cycle is not supported by *bashfun*.
    if (exists $$powerman_dev_caps{cycle}) {
        record_info('skip cycle', 'cycle is supported but check is not implemented');
        $rt = (assert_script_run("powerman -c \$(hostname)")) ? 1 : 0;
        test_case('powerman cycle', 'powerman can show node cycle', $rt);
    } else {
        $rt = validate_script_output("powerman -c \$(hostname)", sub { /.*cannot be handled by power control device.*/ }, proceed_on_failure => 1);
        test_case('powerman cycle', 'powerman dev doesnt support cycle command', $rt);
    }
}

sub post_run_hook ($self) {
    pars_results('HPC powerman tests', $file, @all_tests_results);
    parse_extra_log('XUnit', $file);
    $self->SUPER::post_run_hook();
}

sub post_fail_hook ($self) {
    select_serial_terminal;
    $self->upload_service_log('powerman');
}

1;
