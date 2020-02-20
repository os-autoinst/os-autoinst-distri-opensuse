# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Refresh repositories, apply patches and reboot
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use Mojo::Base 'publiccloud::ssh_interactive_init';
use registration;
use warnings;
use testapi;
use strict;
use utils;

sub run {
    my ($self, $args) = @_;
    select_console 'tunnel-console';

    $args->{my_instance}->run_ssh_command(cmd => "sudo zypper ref", timeout => 360);
    ssh_fully_patch_system($args->{my_instance}->public_ip);
    $args->{my_instance}->softreboot();
}

1;
