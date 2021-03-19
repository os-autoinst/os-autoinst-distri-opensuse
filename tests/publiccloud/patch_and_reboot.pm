# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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

    $args->{my_instance}->retry_ssh_command(cmd => "sudo zypper -n ref", timeout => 240, retry => 6);
    ssh_fully_patch_system($args->{my_instance}->public_ip);
    $args->{my_instance}->softreboot();
}

1;
