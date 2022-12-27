# SUSE's openQA tests
#
# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Class with helpers related to SSH Interactive mode
#
# Maintainer: qa-c@suse.de

package publiccloud::ssh_interactive;
use base Exporter;
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends qw(set_sshserial_dev unset_sshserial_dev);
use version_utils qw(is_tunneled);

our @EXPORT = qw(ssh_interactive_tunnel ssh_interactive_leave select_host_console);

# Helper call to activate a console and establish the ssh connection therein
sub establish_tunnel_console {
    my ($console) = @_;

    select_console("$console");
    # Note: Don't use script_run here! The serial terminal is set to /dev/sshserial, so every script_run will time out
    type_string("\n~.\n", max_interval => 1);    # ensure no previous ssh connection is present
    enter_cmd("clear");
    enter_cmd('ssh -t sut');
    # give the ssh connection some time to settle
    sleep 5;
}

sub ssh_interactive_tunnel {
    # Establish the ssh interarctive tunnel to the publiccloud instance.
    # Optional arguments: 'force => 1' - reestablish tunnel, also if already established.
    #                     'reconnect => 1' - reestablish the tunnel after disconnecting. Use this to re-establish the tunnels after e.g. an instance reboot

    my $instance = shift;
    my %args = testapi::compat_args({force => 0, reconnect => 0}, ['force', 'reconnect'], @_);

    # $serialdev should be always set from os-autoinst/testapi.pm
    die '$serialdev is not set' if (!defined $serialdev || $serialdev eq '');
    return if ($args{force} != 1 && get_var('_SSH_TUNNELS_INITIALIZED', 0) == 1);

    my $prev_console = current_console();
    select_console('tunnel-console') unless ($prev_console =~ /tunnel-console/);

    # Prepare the environment for the SSH tunnel
    my $upload_port = get_required_var('QEMUPORT') + 1;
    my $upload_host = testapi::host_ip();

    # Pipe the output of the device fifo to the local serial terminal
# Note: We run this in a loop so that the ssh tunnel gets automatically re-established after device reboots and such. The sleep helps to avoid unnecessary CPU hogging in case of connection issues
    enter_cmd("while true; do ssh sut -yt -R '$upload_port:$upload_host:$upload_port' 'rm -f /dev/sshserial && mkfifo -m a=rwx /dev/sshserial && tail -fn +1 /dev/sshserial' 2>&1 >/dev/$serialdev; sleep 5; done");
    # give the ssh connection some time to settle
    sleep 10;

    # from here onwards, the serial output should be directed to /dev/sshserial instead to /dev/ttyS0
    set_var('SERIALDEV_', $serialdev);
    set_sshserial_dev();
    set_var('_SSH_TUNNELS_INITIALIZED', 1);
    set_var('AUTOINST_URL_HOSTNAME', 'localhost');

    # When re-activing the consoles we also need to setup the underlying ssh connections again,
    # because this only happens the first time the console is activated
    if ($args{reconnect}) {
        establish_tunnel_console("root-console");
        establish_tunnel_console("user-console");
        establish_tunnel_console("root-virtio-terminal");
    }

    select_console($prev_console) if ($prev_console !~ /tunnel-console/);
}

sub ssh_interactive_leave {
    my $prev_console = current_console();
    # Switch to the local console, terminate the ssh tunnel and set the serial device back
    select_console('tunnel-console') unless ($prev_console =~ /tunnel-console/);
    unset_sshserial_dev();
    set_var('AUTOINST_URL_HOSTNAME', testapi::host_ip());

    # While the tunnel console is active, the serial terminal sometimes swallows characters. To terminate the
    # ssh tunnel reliably, we repeat the process until it succeeds. A delay between retries is useful to let thinks
    # cool down after a failed attempt
    my $retries = 8;
    while ($retries-- > 0) {
        send_key 'ctrl-c';
        send_key 'ctrl-c';
        send_key 'ret';
        last if (script_run("true", timeout => 5, die_on_timeout => 0) == 0);
        sleep 5;    # some cool down after a failed attempt
    }
    die "tunnel-console is not functional" if ($retries <= 0);

    select_console($prev_console) if ($prev_console !~ /tunnel-console/);
    set_var('_SSH_TUNNELS_INITIALIZED', 0);    # set after the last select_console!
}

# Select console on the test host, if force is set, the interactive session will
# be destroyed. If called in TUNNELED environment, this function die.
#
# select_host_console(force => 1)
#
sub select_host_console {
    my (%args) = @_;
    $args{force} //= 0;
    my $tunneled = is_tunneled();

    if ($tunneled && get_var('_SSH_TUNNELS_INITIALIZED')) {
        # Note: Because the serial device is set to /dev/sshserial in TUNNELED mode, it does not
        # make any sense to allow this to pass, unless we would terminate the existing session.
        die("Called select_host_console but we are in TUNNELED mode") unless ($args{force});

        select_console('tunnel-console');
        ssh_interactive_leave();
    }
    set_var('TUNNELED', 0);
    select_serial_terminal();
    # ssh termination sequence to ensure any ssh connections we're in are terminated
    type_string("\n~.\n", max_interval => 1);    # send the ssh termination sequence to ensure no previous ssh connection is present
    set_var('TUNNELED', $tunneled);
    record_info("hostname", script_output("hostname"));
    assert_script_run("true", fail_message => "host console is broken");    # basic health check
}

1;
