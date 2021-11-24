# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Refresh repositories, apply patches and reboot
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use Mojo::Base 'publiccloud::ssh_interactive_init';
use registration;
use warnings;
use testapi;
use strict;
use utils;
use publiccloud::utils qw(select_host_console);

sub run {
    my ($self, $args) = @_;
    select_host_console();    # select console on the host, not the PC instance

    my $remote = $args->{my_instance}->username . '@' . $args->{my_instance}->public_ip;

    $args->{my_instance}->retry_ssh_command(cmd => "sudo zypper -n ref", timeout => 240, retry => 6);
    ssh_fully_patch_system($remote);
    $args->{my_instance}->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
}

1;
