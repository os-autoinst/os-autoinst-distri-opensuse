# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

package sles4sap::console_redirection;
use strict;
use warnings;
use testapi;
use Carp qw(croak);
use Exporter qw(import);
use Regexp::Common qw(net);

=head1 SYNOPSIS

Library that enables console redirection and file transfers from worker based VM to another host.
Can be used for cases where worker VM is not the target host for API calls and command execution, but serves only as a jumphost.

=cut

our @EXPORT = qw(
  connect_target_to_serial
  disconnect_target_from_serial
  redirection_init
  check_serial_redirection
);

my $ssh_opt = '-o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ServerAliveCountMax=120';
# Create ssh key into /tmp so all users have access to it.
our $reverse_ssh_key_base_name = '/tmp/id_reverse_openqa';

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

=head2 redirection_init

    redirection_init( [, ssh_user=>$ssh_user, destination_ip=>$destination_ip, ssh_tunnel_port=>$ssh_tunnel_port]);

B<ssh_user>: SSH login user for B<destination_ip> - default value is defined by OpenQA parameter REDIRECT_DESTINATION_USER

B<destination_ip>: Destination host IP - default value is defined by OpenQA parameter REDIRECT_DESTINATION_IP

B<ssh_tunnel_port>: Port on the B<destination_ip> to forward ssh traffic to. Default: 22022

Does initial setup for console redirection which includes:

=over

=item * Takes machine id value from currently controlled VM and sets BASE_VM_ID. This is considered origin point of
    console redirection and a point where function disconnect_target_from_serial() stops 'logging out'.

=item * SSH key exchange for reverse ssh connection.

=item * remote port forwarding for reverse SSH session

=item * remote port forwarding of incoming traffic from B<destination_ip> to OpenQA
    server resources (upload_logs, download from 'data')

=back
=cut

sub redirection_init {
    my (%args) = @_;
    $args{destination_ip} //= get_required_var('REDIRECT_DESTINATION_IP');
    $args{ssh_user} //= get_required_var('REDIRECT_DESTINATION_USER');
    $args{ssh_tunnel_port} //= '22022';

    croak 'Package autossh is not installed' if script_run('rpm -qi autossh');

    record_info('Redirection init', "Preparing console redirection to: $args{destination_ip}");

    # This should get base VM id before any redirection happening
    # ID serves as identification for origin point where redirection is not anymore in place.
    set_var('BASE_VM_ID', script_output 'cat /etc/machine-id');

    # Prepare keyless access from remote host to worker VM
    connect_target_to_serial(%args);
    script_run("sudo rm $reverse_ssh_key_base_name*", quiet => 1);
    # remove any existing entry in known_hosts file
    script_run("ssh-keygen -R [localhost]:$args{ssh_tunnel_port} -f ~/.ssh/known_hosts", quiet => 1);
    script_run("sudo ssh-keygen -R [localhost]:$args{ssh_tunnel_port} -f /root/.ssh/known_hosts", quiet => 1);
    assert_script_run("ssh-keygen -f $reverse_ssh_key_base_name -t rsa -b 2048 -N ''");
    my $public_key = script_output("cat $reverse_ssh_key_base_name.pub", quiet => 1);
    disconnect_target_from_serial(%args);

    # Add cloud VM key to worker VM authorized keys
    assert_script_run("echo \"$public_key\" >> ~/.ssh/authorized_keys", quiet => 1);

    # Forward common ports.
    # Starts permanent reverse SSH connection from remote VM to worker VM.
    remote_port_forward(destination_port => $args{ssh_tunnel_port},
        ssh_user => $args{ssh_user},
        destination_ip => 'localhost',
        monitor_port => '20000');

    # Port below is also required to access resources using generated port. Check QEMUPORT for details
    # https://github.com/os-autoinst/os-autoinst/blob/master/doc/backend_vars.asciidoc
    remote_port_forward(destination_port => get_var("QEMUPORT") + 1,
        ssh_user => $args{ssh_user},
        destination_ip => get_var('QEMU_HOST_IP', '10.0.2.2'),
        monitor_port => '20001');
    record_info('Redirected', 'Console redirection ready.');
}

=head2 remote_port_forward

    remote_port_forward(destination_port=>$destination_port, destination_ip=>$destination_ip
        [, source_port=>$source_port, monitor_port=>$monitor_port, source_ip=>$source_ip]);

B<source_ip>: Source IP address or hostname to forward incoming traffic from. Default: REDIRECT_DESTINATION_IP

B<destination_ip>: Destination IP or hostname where will the traffic be forwarded. Can be localhost as well.

B<monitor_port>: Port for autossh to monitor tunnel status. Needs to be unique for each autossh instance. Default: off

B<source_port>:  B<source_ip> port to forward traffic from. Default: source_port=destination_port

B<destination_port>: port which B<source_port> traffic should be forwarded to.

B<ssh_user>: Login user for B<source_ip> host.

Forwards traffic from B<source_ip>:B<source_port> to B<destination_ip>:B<destination_port>.
For example: It allows Cloud based SUT uploading logs directly to openQA instance without being able to resolve it directly.
Default finction behavior is:

- redirecting same port

- not using autossh monitoring port

=cut

sub remote_port_forward {
    my (%args) = @_;
    foreach ('destination_port', 'destination_ip') {
        croak "Missing $args{$_} argument" unless $args{$_};
    }

    # source IP means source of the incomming traffic.
    # REDIRECT_DESTINATION_IP and destination_ip are different things!
    $args{source_ip} //= get_required_var('REDIRECT_DESTINATION_IP');
    $args{ssh_user} //= get_required_var('REDIRECT_DESTINATION_USER');
    $args{monitor_port} //= '0';
    $args{source_port} //= $args{destination_port};

    my $current_user = script_output('whoami', quiet => 1);
    my $autossh_cmd = join(' ', 'autossh',
        "-M $args{monitor_port}",
        '-f', '-N',
        "-R $args{source_port}:$args{destination_ip}:$args{destination_port}",
        "$args{ssh_user}\@$args{source_ip}"
    );
    $autossh_cmd = 'sudo ' . $autossh_cmd if $current_user ne 'root';

    assert_script_run($autossh_cmd);
    record_info('Port FWD',
        "Forwarding set from '$args{source_ip}:$args{source_port}' to '$args{destination_ip}:$args{destination_port}'");
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

Establishes ssh connection to destination host and redirects serial output to serial console on worker VM.
This allows OpenQA access to command return codes and output for evaluation by standard API call.

=cut

sub connect_target_to_serial {
    my (%args) = @_;
    $args{destination_ip} //= get_required_var('REDIRECT_DESTINATION_IP');
    $args{ssh_user} //= get_required_var('REDIRECT_DESTINATION_USER');

    croak "OpenQA variable BASE_VM_ID undefined. Run 'redirection_init()' first" unless get_var('BASE_VM_ID');
    croak "IP address '$args{destination_ip}' is not valid." unless grep(/^$RE{net}{IPv4}$/, $args{destination_ip});
    croak 'Global variable "$serialdev" undefined' unless $serialdev;
    croak "Console is already redirected to:" . script_output('hostname', quiet => 1) if check_serial_redirection();

    # Save original value for 'AUTOINST_URL_HOSTNAME', and point requests to localhost
    # https://github.com/os-autoinst/os-autoinst/blob/master/doc/backend_vars.asciidoc
    # check os-autoinst/testapi.pm host_ip() function to get an idea about inner workings
    set_var('AUTOINST_URL_HOSTNAME_ORIGINAL', get_var('AUTOINST_URL_HOSTNAME'));
    set_var('AUTOINST_URL_HOSTNAME', 'localhost');

    enter_cmd "ssh $ssh_opt $args{ssh_user}\@$args{destination_ip} 2>&1 | tee -a /dev/$serialdev";
    handle_login_prompt($args{ssh_user});
    check_serial_redirection();
    record_info('Redirect ON', "Serial redirection established to: $args{destination_ip}");
}

=head2 disconnect_target_from_serial

    disconnect_target_from_serial( [, base_vm_machine_id=$base_vm_machine_id]);

B<base_vm_machine_id>: ID of the base VM before redirection. Default is BASE_VM_ID value set by redirect_init()

Disconnects target from serial console by typing 'exit' command until host machine ID matches ID of the worker VM.

=cut

sub disconnect_target_from_serial {
    my (%args) = @_;
    $args{base_vm_machine_id} //= get_required_var('BASE_VM_ID');
    set_serial_term_prompt();
    my $serial_redirection_status = check_serial_redirection(base_vm_machine_id => $args{base_vm_machine_id});
    while ($serial_redirection_status != 0) {
        enter_cmd('exit');    # Enter command and wait for screen start changing
        $testapi::distri->{serial_term_prompt} = '';    # reset console prompt
        wait_serial(qr/Connection.*closed./, timeout => 10, quiet => 1);    # Wait for connection to close
        wait_serial(qr/# |> /, timeout => 10, quiet => 1);    # Wait for console prompt to appear
        set_serial_term_prompt();    # after logout user might change and prompt with it.
        $serial_redirection_status = check_serial_redirection($args{base_vm_machine_id});
    }

    # restore original 'AUTOINST_URL_HOSTNAME'
    set_var('AUTOINST_URL_HOSTNAME', get_var('AUTOINST_URL_HOSTNAME_ORIGINAL'));
    record_info('Redirect OFF', "Serial redirection closed. Console set to: " . script_output('hostname', quiet => 1));
}

=head2 check_serial_redirection

    check_serial_redirection( [, base_vm_machine_id=$base_vm_machine_id]);

B<base_vm_machine_id>: ID of the base VM before redirection. Default is BASE_VM_ID value set by redirect_init()

Compares current machine-id to the worker VM ID either defined by BASE_VM_ID variable or positional argument.
Machine ID is used instead of IP addr since cloud VM IP might not be visible from the inside (for example via 'ip a')

=cut

sub check_serial_redirection {
    my (%args) = @_;
    $args{base_vm_machine_id} //= get_required_var('BASE_VM_ID');
    my $current_id = script_output('cat /etc/machine-id', quiet => 1);
    my $redirection_status = $current_id eq $args{base_vm_machine_id} ? 0 : 1;
    return $redirection_status;
}

1;
