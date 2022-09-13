# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openssh
# Summary: This tests will establish the tunnel and enable the SSH interactive console
#
# Maintainer: qa-c@suse.de

use Mojo::Base 'consoletest';
use testapi;
use utils;
use publiccloud::ssh_interactive "ssh_interactive_tunnel";

sub run {
    my ($self, $args) = @_;
    die "tunnel-console requires the TUNELLED=1 setting" unless (get_var("TUNNELED"));

    $self->{provider} = $args->{my_provider};    # required for cleanup

    # Only initialize tunnels, if not previously done
    if (!get_var('_SSH_TUNNELS_INITIALIZED', 0)) {
        # This ensures that we have used the setup console, even if no module was run before.
        my $setup_console = current_console();

        # Establish the tunnel (it will stay active in foreground and occupy this console!)
        select_console('tunnel-console');
        ssh_interactive_tunnel($args->{my_instance});

        # Enable ssh connection on setup console, this is done normally with the
        # first activation hook in susedistribution:activate_console()
        if ($setup_console !~ /tunnel/) {
            select_console($setup_console);
            # The verbose output is visible only at the tunnel-console -
            #   it doesn't interfere with tests as it isn't piped to /dev/sshserial
            if (get_var("TUNNEL_AUTO_SSH")) {
                script_run('autossh -M 20002 sut', timeout => 0);
            } else {
                script_run('ssh -E /var/tmp/ssh_sut.log -vt sut', timeout => 0);
            }
        }
    }
    die("expect ssh serial") unless (get_var('SERIALDEV') =~ /ssh/);

    # Verify most important consoles
    select_console('root-console');
    assert_script_run('test -e /dev/' . get_var('SERIALDEV'), 180);
    assert_script_run('test $(id -un) == "root"');

    select_console('user-console');
    assert_script_run('test -e /dev/' . get_var('SERIALDEV'));
    assert_script_run('test $(id -un) == "' . $testapi::username . '"');

    $self->select_serial_terminal();
    assert_script_run('test -e /dev/' . get_var('SERIALDEV'));
    assert_script_run('test $(id -un) == "root"');
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
