# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

=head1 Lab

=head1 SYNOPSIS

Setup VPN to a remote lab using openconnect compatible with Cisco AnyConnect
VPN and connect.

=cut

package Remote::Lab;
use strict;
use warnings;
use base 'Exporter';
use Exporter;
use registration 'add_suseconnect_product';
use testapi;
use utils;
use Utils::Backends 'set_sshserial_dev';
use version_utils 'is_sle';


our @EXPORT = qw(setup_vpn connect_vpn setup_ssh_tunnels);


sub setup_vpn {
    my ($self) = @_;
    add_suseconnect_product('PackageHub', undef, undef, undef, 300, 1) if is_sle;
    zypper_call 'in --no-recommends openconnect';
    script_run 'read -s vpn_password', 0;
    type_password get_required_var('_SECRET_VPN_PASSWORD') . "\n";
}

sub connect_vpn {
    my ($self) = @_;
    my $vpn_username = get_required_var('VPN_USERNAME');
    my $vpn_endpoint = get_var('VPN_ENDPOINT', 'asa003b.centers.ihost.com');
    my $vpn_group = get_var('VPN_GROUP', 'ACC');
    # nohup should already go to background but during test development I
    # observed that it still blocked the terminal – regardless of e.g. using a
    # virtio serial terminal or VNC based – so let's force it to the
    # background.
    # accessing shell variables for the (secret) passwords defined in setup_vpn.
    script_run "(echo \$vpn_password | nohup openconnect --user=$vpn_username --passwd-on-stdin --authgroup=$vpn_group $vpn_endpoint | tee /dev/$serialdev > vpn.log &)", 0;
    wait_serial 'Welcome to the IBM Systems WW Client Experience Center';
    send_key 'ret';
    clear_console;
}

=head2 setup_ssh_tunnels

    setup_ssh_tunnels()

Setup tunnel(s) over SSH based on an openSSH configuration configuring a
"jumpbox" including forwarding a port for remote log uploading.

=cut

sub setup_ssh_tunnels {
    my ($self) = @_;
    return if get_var('_SSH_TUNNELS_INITIALIZED');
    zypper_call '--no-refresh in --no-recommends sshpass';
    script_run 'read -s jumpbox_password', 0;
    type_password get_required_var('_SECRET_JUMPBOX_PASSWORD') . "\n";
    script_run 'read -s sut_password', 0;
    type_password get_required_var('_SECRET_SUT_PASSWORD') . "\n";
    assert_script_run 'ssh-keygen -t ed25519 -N \'\' -f ~/.ssh/id_ed25519';

    # For the port we can reuse the same port that is used by "upload_logs"
    # but on the remote host. The port is computed as QEMUPORT + 1
    my $upload_port = get_required_var('QEMUPORT') + 1;
    my $jumpbox = get_var('JUMPBOX_HOSTNAME', '129.40.13.66');
    my $sut = get_var('SUT_HOSTNAME', '10.3.1.111');
    my $upload_host = testapi::host_ip();
    type_string "cat - > .ssh/config <<EOF
Host jumpbox
    HostName $jumpbox
    StrictHostKeyChecking no

Host sut
    HostName $sut
    ProxyJump jumpbox
    StrictHostKeyChecking no
EOF
";
    # we can switch '>>' to '>' to prevent piling up too many keys but
    # that means overriding the keys manually added as well
    assert_script_run 'cat ~/.ssh/id_ed25519.pub | sshpass -p $jumpbox_password ssh jumpbox "cat - >> .ssh/authorized_keys"';
    assert_script_run 'cat ~/.ssh/id_ed25519.pub | sshpass -p $sut_password ssh sut "cat - >> .ssh/authorized_keys"';
    # create a FIFO for serial port forwarding, reuse it when it is already
    # there but we need to get exclusive access so terminating others
    # potentially attached. Also use this connection for forwarding of a port
    # for log uploading
    script_run "ssh -t -R $upload_port:$upload_host:$upload_port sut 'mkfifo /dev/sshserial 2>/dev/null; lsof -t /dev/sshserial | xargs kill; tail -fn +1 /dev/sshserial' | tee /dev/$serialdev", 0;

    # "upload_logs" uses "host_ip" which returns a host that is not available
    # remotely but we can use an SSH tunnel for this as well so any connection
    # from the remote SUT for uploading should reach localhost.
    set_var('AUTOINST_URL_HOSTNAME', 'localhost');
    set_var('_SSH_TUNNELS_INITIALIZED', 1);
    # selecting the root console will now ensure we are connected to the
    # remote SUT
    select_console 'root-console';
    # now we can redirect the serial output
    set_sshserial_dev;
}

1;
