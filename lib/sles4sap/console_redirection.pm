# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

package sles4sap::console_redirection;
use strict;
use warnings;
use testapi qw(is_serial_terminal :DEFAULT);
use testapi;
use Carp qw(croak);
use Exporter qw(import);
use Regexp::Common qw(net);
use serial_terminal qw(select_serial_terminal);

=head1 SYNOPSIS

Library that enables console redirection and file transfers from worker based VM to another host.
Can be used for cases where worker VM is not the target host for API calls and command execution, but serves only
as a jumphost. Console redirection is achieved by ssh remote port forwarding and redirecting remote VM ssh session
stdin and stdout outputs into serial terminal of the worker VM.

B<USAGE:>
1. Set mandatory OpenQA parameters (they can be as well provided directly as named arguments in functions):
    - REDIRECT_DESTINATION_USER: SSH user for remote SUT
    - REDIRECT_DESTINATION_IP: IP address for remote SUT
2. Establish console redirection to SUT host by calling function B<connect_target_to_serial>
    - all test code is now transparently executed on SUT instead of worker VM
    - from OpenQA perspective SUT is the worker VM
3. Disable console redirection from SUT host by calling function B<disconnect_target_from_serial>


=cut

our @EXPORT = qw(
  connect_target_to_serial
  disconnect_target_from_serial
  check_serial_redirection
);

my $ssh_opt = join(' ',
    '-o StrictHostKeyChecking=no',
    '-o ServerAliveInterval=60',
    '-o ServerAliveCountMax=120',
    '-o ConnectionAttempts=3',    # Retry connecting before failing
);

=head2 handle_login_prompt

    handle_login_prompt();

Detects if login prompt appears and types the password.
In case of ssh keys being in place and command prompt appears, the function does not type anything.

=cut

sub handle_login_prompt {
    my $pwd = get_var('_SECRET_SUT_PASSWORD', $testapi::password);
    set_serial_term_prompt();
    # look for either password prompt or command prompt to appear
    my $serial_response = wait_serial(qr/Password:\s*$|:~/, timeout => 20, quiet => 1);

    die 'Neither password not command prompt appeared.' unless $serial_response;
    # Handle password prompt if it appears
    if (grep /Password:\s*$/, $serial_response) {
        type_password $pwd;
        send_key 'ret';
        # wait for command prompt to be ready
        die 'Command prompt did not appear within timeout' unless wait_serial(qr/:~|#|>/, timeout => 20, quiet => 1);
    }
    set_serial_term_prompt();    # set correct serial prompt
}

=head2 set_serial_term_prompt

    set_serial_term_prompt();

Set expected serial prompt according to user which is currently active.
This changes global setting $testapi::distri->{serial_term_prompt} which is important for calls like wait_for_serial.

=cut

sub set_serial_term_prompt {
    $testapi::distri->{serial_term_prompt} = '';    # This resets prompt since you don't know what user is currently logged in.
    $testapi::distri->{serial_term_prompt} = script_run('whoami | grep root', quiet => 1) == 0 ? '# ' : '> ';
}

=head2 connect_target_to_serial

    connect_target_to_serial( [, ssh_user=>ssh_user, destination_ip=>$destination_ip]);

B<ssh_user>: SSH login user for B<destination_ip> - default value is defined by OpenQA parameter REDIRECT_DESTINATION_USER

B<destination_ip>: Destination host IP - default value is defined by OpenQA parameter REDIRECT_DESTINATION_IP

B<fail_ok>: Do not die, return 0 instead. Good for verifying if redirection works.

Establishes ssh connection to destination host and redirects serial output to serial console on worker VM.
Connection activates remote port forwarding of OpenQA QEMUPORT+1.
This allows running standard OpenQA modules directly on a remote host accessed from worker VM via SSH.
Returns 1 if redirection was successful, or dies if redirection fails.
If B<fail_ok> is set to true, function does not fail, but returns 0.

=cut

sub connect_target_to_serial {
    my (%args) = @_;
    $args{destination_ip} //= get_required_var('REDIRECT_DESTINATION_IP');
    $args{ssh_user} //= get_required_var('REDIRECT_DESTINATION_USER');

    croak "IP address '$args{destination_ip}' is not valid." unless grep(/^$RE{net}{IPv4}$/, $args{destination_ip});
    croak 'Global variable "$serialdev" undefined' unless $serialdev;

    if (check_serial_redirection()) {
        record_info('Redirect ON', "Console is already redirected to:" . script_output('hostname', quiet => 1));
        return 1;
    }

    # Save original value for 'AUTOINST_URL_HOSTNAME', and point requests to localhost
    # https://github.com/os-autoinst/os-autoinst/blob/master/doc/backend_vars.asciidoc
    # check os-autoinst/testapi.pm host_ip() function to get an idea about inner workings
    set_var('AUTOINST_URL_HOSTNAME_ORIGINAL', get_var('AUTOINST_URL_HOSTNAME'));
    set_var('AUTOINST_URL_HOSTNAME', 'localhost');

    my $redirect_port = get_required_var("QEMUPORT") + 1;
    my $redirect_ip = get_var('QEMU_HOST_IP', '10.0.2.2');
    my $redirect_opts = "-R $redirect_port:$redirect_ip:$redirect_port";
    enter_cmd "ssh $ssh_opt $redirect_opts $args{ssh_user}\@$args{destination_ip} 2>&1 | tee -a /dev/$serialdev";
    handle_login_prompt($args{ssh_user});

    my $redirection_active = check_serial_redirection();
    if ($args{fail_ok} && !$redirection_active) {
        record_info('Redirect FAIL', 'Redirection FAILED. Argument "fail_ok" is set, test will continue.');
        return 0;
    }
    die 'Failed redirecting console' unless $redirection_active;
    record_info('Redirect ON', "Serial redirection established to: $args{destination_ip}");
    return 1;
}

=head2 disconnect_target_from_serial

    disconnect_target_from_serial();

Disconnects target from serial console by typing 'exit' command until host machine ID matches ID of the worker VM.

=cut

sub disconnect_target_from_serial {
    set_serial_term_prompt();
    my $serial_redirection_status = check_serial_redirection();
    while ($serial_redirection_status != 0) {
        enter_cmd('exit');    # Enter command and wait for screen start changing
        $testapi::distri->{serial_term_prompt} = '';    # reset console prompt
        wait_serial(qr/Connection.*closed./, timeout => 10, quiet => 1);    # Wait for connection to close
        wait_serial(qr/# |> /, timeout => 10, quiet => 1);    # Wait for console prompt to appear
        $serial_redirection_status = check_serial_redirection();
    }

    # restore original 'AUTOINST_URL_HOSTNAME'
    set_var('AUTOINST_URL_HOSTNAME', get_var('AUTOINST_URL_HOSTNAME_ORIGINAL'));
    record_info('Redirect OFF', "Serial redirection closed. Console set to: " . script_output('hostname', quiet => 1));
}

=head2 check_serial_redirection

    check_serial_redirection();

Checks if serial redirection is currently active by comparing worker VM machine id against id returned
from serial console. VM ID is collected by opening 'log-console' which is not redirected.

=cut

sub check_serial_redirection {
    # Do not select serial console if it is already done. This avoids log pollution and speeds up process.
    if (is_serial_terminal()) {
        select_serial_terminal();
        set_serial_term_prompt();
    }

    # check machine ID under serial console
    my $current_id = script_output('cat /etc/machine-id', quiet => 1);
    # Switch 'log-console' (which is not redirected) to check machine ID on worker
    select_console('log-console');
    my $redirection_status = script_run("grep $current_id /etc/machine-id", quiet => 1);
    select_serial_terminal();
    set_serial_term_prompt();
    return $redirection_status;
}

1;
