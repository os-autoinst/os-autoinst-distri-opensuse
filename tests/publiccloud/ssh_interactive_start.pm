# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: openssh
# Summary: This tests will establish the tunnel and enable the SSH interactive console
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use Mojo::Base 'publiccloud::ssh_interactive_init';
use publiccloud::ssh_interactive;
use testapi;
use utils;
use publiccloud::utils "select_host_console";

sub run {
    my ($self, $args) = @_;

    # This ensure that we have used the setup console, even if no module was run before.
    select_host_console();
    my $setup_console = current_console();

    # Establish the tunnel (it will stay active in foreground and occupy this console!)
    select_console('tunnel-console');
    ssh_interactive_tunnel($args->{my_instance});

    # Enable ssh connection on setup console, this is done normally with the
    # first activation hook in susedistribution:activate_console()
    if ($setup_console !~ /tunnel/) {
        select_console($setup_console);
        script_run('ssh -t sut', timeout => 0);
    }

    die("expect ssh serial") unless (get_var('SERIALDEV') =~ /ssh/);

    # Verify most important consoles
    select_console('root-console');
    assert_script_run('test -e /dev/' . get_var('SERIALDEV'));
    assert_script_run('test $(id -un) == "root"');

    select_console('user-console');
    assert_script_run('test -e /dev/' . get_var('SERIALDEV'));
    assert_script_run('test $(id -un) == "' . $testapi::username . '"');

    $self->select_serial_terminal();
    assert_script_run('test -e /dev/' . get_var('SERIALDEV'));
    assert_script_run('test $(id -un) == "root"');
}

1;
