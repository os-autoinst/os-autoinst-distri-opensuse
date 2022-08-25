# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Class with helpers related to SSH Interactive mode
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

package publiccloud::ssh_interactive;
use base Exporter;
use testapi;
use Utils::Backends qw(set_sshserial_dev unset_sshserial_dev);
use strict;
use warnings;

our @EXPORT = qw(ssh_interactive_tunnel ssh_interactive_leave select_host_console);

sub ssh_interactive_tunnel {
    # Establish the ssh interarctive tunnel to the publiccloud instance.
    # Optional arguments: 'force => 1' - reestablish tunnel, also if already established.

    my $instance = shift;
    my %args = testapi::compat_args({cmd => undef}, ['cmd'], @_);
    $args{force} //= 0;

    # $serialdev should be always set from os-autoinst/testapi.pm
    die '$serialdev is not set' if (!defined $serialdev || $serialdev eq '');
    return if ($args{force} != 1 && get_var('_SSH_TUNNELS_INITIALIZED', 0) == 1);

    # Prepare the environment for the SSH tunnel
    my $upload_port = get_required_var('QEMUPORT') + 1;
    my $upload_host = testapi::host_ip();

    $instance->run_ssh_command(
        # Create /dev/sshserial fifo on remote and tail|tee it to /dev/$serialdev on local
        #   timeout => switches to script_run instead of script_output to be used so the test will not wait for the command to end
        #   tunnel the worker port (for downloading from data/ and uploading assets / logs
        cmd => "'rm -rf /dev/sshserial; mkfifo -m a=rwx /dev/sshserial; tail -fn +1 /dev/sshserial' 2>&1 | tee /dev/$serialdev; clear",
        timeout => 0,
        no_quote => 1,
        ssh_opts => "-yt -R $upload_port:$upload_host:$upload_port",
        username => 'root',
    );
    sleep 3;
    save_screenshot;

    set_var('SERIALDEV_', $serialdev);
    set_var('_SSH_TUNNELS_INITIALIZED', 1);

    set_var('AUTOINST_URL_HOSTNAME', 'localhost');
    set_sshserial_dev();
}

sub ssh_interactive_leave {
    # Check if the SSH tunnel is still up and leave the SSH interactive session
    script_run("test -p /dev/sshserial && exit", timeout => 0);

    # Restore the environment to not use the SSH tunnel for upload/download from the worker
    #set_var('SUT_HOSTNAME',          testapi::host_ip());
    set_var('AUTOINST_URL_HOSTNAME', testapi::host_ip());
    unset_sshserial_dev();

    $testapi::distri->set_standard_prompt('root');
}

# Select console on the test host, if force is set, the interactive session will
# be destroyed. If called in TUNNELED environment, this function die.
#
# select_host_console(force => 1)
#
sub select_host_console {
    my (%args) = @_;
    $args{force} //= 0;
    my $tunneled = get_var('TUNNELED');

    if ($tunneled && check_var('_SSH_TUNNELS_INITIALIZED', 1)) {
        die("Called select_host_console but we are in TUNNELED mode") unless ($args{force});

        opensusebasetest::select_serial_terminal();
        ssh_interactive_leave();

        select_console('tunnel-console', await_console => 0);
        send_key 'ctrl-c';
        send_key 'ret';

        set_var('_SSH_TUNNELS_INITIALIZED', 0);
        opensusebasetest::clear_and_verify_console();
        save_screenshot;
    }
    set_var('TUNNELED', 0) if $tunneled;
    opensusebasetest::select_serial_terminal();
    set_var('TUNNELED', $tunneled) if $tunneled;
}

1;
