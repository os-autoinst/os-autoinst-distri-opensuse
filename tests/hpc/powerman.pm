# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: Add test for powerman package
#
#    https://fate.suse.com/321725
#
#    This tests the powerman package from the HPC module
#
# Maintainer: Matthias Griessmeier <mgriessmeier@suse.com>


use base "hpcbase";
use strict;
use warnings;
use testapi;
use utils;
use susedistribution;

sub run {
    my $self = shift;

    # install powerman
    zypper_call('in powerman');

    # Adapt config
    my $cfg_file = "/etc/powerman/powerman.conf";
    my $hostname = script_output('hostname');
    assert_script_run(
        "echo \"\$(cat <<EOF
listen \"0.0.0.0:10101\"
include \"/etc/powerman/bashfun.dev\"
device \"test\" \"bashfun\" \"/bin/bash |&\"
node \"$hostname\" \"test\" \"1\"
EOF
        )\" >> $cfg_file"
    );
    assert_script_run("cat $cfg_file");

    # enable and start service
    $self->enable_and_start('powerman');

    # list available targets
    script_run("powerman -l | tee /dev/$serialdev", 0);
    wait_serial($hostname);

    # check if target can be turned on
    assert_script_run("powerman -1 \$(hostname)");
    script_run("powerman -Q \$(hostname) | tee /dev/$serialdev", 0);
    wait_serial(/^on:.*$hostname.*/);

    # check if target can be turned off
    assert_script_run("powerman -0 \$(hostname)");
    script_run("powerman -Q \$(hostname) | tee /dev/$serialdev", 0);
    wait_serial(/^off:.*$hostname.*/);

    # check if command can be handled by power control device
    script_run("powerman -c \$(hostname) | tee /dev/$serialdev", 0);
    wait_serial(/.*cannot be handled by power control device.*/);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->upload_service_log('powerman');
}

1;
