# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Class with helpers related to SSH Interactive mode
#
# Maintainer: qa-c@suse.de

package publiccloud::ssh_interactive;
use base Exporter;
use testapi;
use Utils::Backends qw(set_sshserial_dev unset_sshserial_dev);
use strict;
use warnings;
use distribution;

our @EXPORT = qw(ssh_interactive_tunnel ssh_interactive_leave select_host_console);

sub active_console {
    my $console = $_[0];
    select_console("$console");
    record_info("activating $console", "Activating the '$console' console");
    script_run('ssh -t sut', timeout => 0);
    save_screenshot;
}

sub ssh_interactive_tunnel {
    # Establish the ssh interarctive tunnel to the publiccloud instance.
    # Optional arguments: 'force => 1' - reestablish tunnel, also if already established.

    my $instance = shift;
    my %args = testapi::compat_args({cmd => undef}, ['cmd'], @_);
    $args{force} //= 0;

    # $serialdev should be always set from os-autoinst/testapi.pm
    die '$serialdev is not set' if (!defined $serialdev || $serialdev eq '');
    return if ($args{force} != 1 && get_var('_SSH_TUNNELS_INITIALIZED', 0) == 1);

    my $prev_console = current_console();
    select_console('tunnel-console') unless ($prev_console =~ /tunnel-console/);

    # Prepare the environment for the SSH tunnel
    my $upload_port = get_required_var('QEMUPORT') + 1;
    my $upload_host = testapi::host_ip();

    if (get_var("TUNNEL_AUTO_SSH")) {
        ## TODO: Use autossh -f to run in background
        # Pipe the output of the device fifo to the local serial terminal
        my $tunnel_pid = background_script_run("autossh -M 20000 sut 'rm -f /dev/sshserial && mkfifo -m a=rwx /dev/sshserial && tail -fn +1 /dev/sshserial' 2>&1 >/dev/$serialdev", quiet => 1);
        sleep 3;
        save_screenshot;
        record_info("autossh", "ssh tunnel started as process $tunnel_pid");
        # When re-activing the consoles we also need to setup the underlying ssh connections again
        if (get_var('_SSH_TUNNELS_INITIALIZED')) {
            active_console("root-console");
            active_console("user-console");
            active_console("user-virtio-terminal");
            active_console("root-virtio-terminal");
        }
    } else {
        $instance->ssh_script_run(
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
    }

    set_var('SERIALDEV_', $serialdev);
    set_var('_SSH_TUNNELS_INITIALIZED', 1);

    set_var('AUTOINST_URL_HOSTNAME', 'localhost');
    set_sshserial_dev();

    select_console($prev_console) if ($prev_console !~ /tunnel-console/);
}

sub ssh_interactive_leave {
    if (get_var("TUNNEL_AUTO_SSH")) {
        my $prev_console = current_console();
        select_console('tunnel-console') unless ($prev_console !~ /tunnel-console/);
        script_run("killall -q autossh");
        set_var('AUTOINST_URL_HOSTNAME', testapi::host_ip());
        unset_sshserial_dev();
        $testapi::distri->set_standard_prompt('root');
        assert_script_run("hostname");
        assert_script_run("whoami");
        select_console($prev_console) if ($prev_console !~ /tunnel-console/);
    } else {
        # Check if the SSH tunnel is still up and leave the SSH interactive session
        script_run("test -p /dev/sshserial && exit", timeout => 0);

        # Restore the environment to not use the SSH tunnel for upload/download from the worker
        #set_var('SUT_HOSTNAME',          testapi::host_ip());
        set_var('AUTOINST_URL_HOSTNAME', testapi::host_ip());
        unset_sshserial_dev();

        $testapi::distri->set_standard_prompt('root');
    }
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

    # In autossh mode, the tunnel console is not blocked.
    if ($tunneled && check_var("TUNNEL_AUTO_SSH", 1)) {
        select_console('tunnel-console');
        opensusebasetest::clear_and_verify_console();
        sleep 30;
        save_screenshot;
    } elsif ($tunneled && check_var('_SSH_TUNNELS_INITIALIZED', 1)) {
        die("Called select_host_console but we are in TUNNELED mode") unless ($args{force});

        # Note: The console is blocked by the ssh tunnel, so don't await_console
        select_console('tunnel-console', await_console => 0);
        sleep 30;
        send_key 'ctrl-c';
        send_key 'ret';

        ssh_interactive_leave();

        set_var('_SSH_TUNNELS_INITIALIZED', 0);
        opensusebasetest::clear_and_verify_console();
        save_screenshot;
    } else {
        set_var('TUNNELED', 0) if $tunneled;
        opensusebasetest::select_serial_terminal();
        set_var('TUNNELED', $tunneled);
    }
}

1;
