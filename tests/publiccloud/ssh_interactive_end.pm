# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: This test will leave the SSH interactive session, kill the SSH tunnel and destroy the public cloud instance
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use Mojo::Base 'publiccloud::basetest';
use publiccloud::ssh_interactive;
use publiccloud::utils;
use testapi;
use utils;

sub run {
    my ($self, $args) = @_;
    select_console 'root-console';

    ssh_interactive_leave();
    select_host_console(await_console => 0);
    $args->{my_provider}->cleanup();
}

1;

