# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

package sles4sap::sap_deployment_automation_framework::inventory_tools;

use warnings;
use strict;
use YAML::PP;
use testapi;
use Exporter qw(import);
use Carp qw(croak);
use sles4sap::sap_deployment_automation_framework::naming_conventions
  qw($deployer_private_key_path $sut_private_key_path);
use sles4sap::console_redirection;

=head1 SYNOPSIS

Library contains functions that handle SDAF inventory file.

SDAF inventory yaml file example:
QES_DB:
  hosts:
    dbhost01:
      ansible_host        : 192.168.1.2
      ansible_user        : someuser
      ansible_connection  : ssh
      connection_type     : key
      virtual_host        : virtualhostname01
      become_user         : root
      os_type             : linux
      vm_name             : somevmname01
    dbhost02:
      ansible_host        : 192.168.1.3
      ansible_user        : someuser
      ansible_connection  : ssh
      connection_type     : key
      virtual_host        : virtualhostname02
      become_user         : root
      os_type             : linux
      vm_name             : somevmname02
  vars:
    node_tier             : hana
    supported_tiers       : [hana, scs, pas]
QES_SCS:
  hosts:
  vars:
    node_tier             : scs
    supported_tiers       : [scs, pas]
QES_ERS:
  hosts:
  vars:
    node_tier             : ers
    supported_tiers       : [ers]

=cut

our @EXPORT = qw(
  read_inventory_file
  prepare_ssh_config
  verify_ssh_proxy_connection
);

=head2 read_inventory_file

    read_inventory_file($sap_inventory_file_path);

Returns SDAF inventory file content in perl HASHREF format.

=over

=item * B<inventory_file_path> Full file path pointing to SDAF inventory file

=back
=cut

sub read_inventory_file {
    my ($inventory_file_path) = @_;
    my $ypp = YAML::PP->new;
    return $ypp->load_string(script_output("cat $inventory_file_path"));
}

=head2 ssh_config_entry_add

    ssh_config_entry_add(entry_name=>'jump_host', hostname=>'SuperMario'
        [, identity_file=>'/path/to/private/key',
        identities_only=>1,
        user=>'luigi'
        proxy_jump=>'192.168.1.100',
        strict_host_key_checking=>0,
        batch_mode=>1]);

Produce ~/.ssh/config host entry like:

-----
Host Mario_host
  HostName 192.2.150.85 some_hostname
  IdentitiesOnly yes
  BatchMode yes
  User mario_plumber
  IdentityFile ~/.ssh/id_rsa
-----

=over

=item * B<entry_name> Config entry name. This name can be used instead of host/IP in ssh command. Example: ssh root@<entry_name>

=item * B<user> Define ssh username

=item * B<hostname> Target hostname or IP addr

=item * B<identity_file> Full path to SSH private key

=item * B<identities_only> If true, SSH will only attempt passwordless login

=item * B<batch_mode> If true, all SSH interactive features will be disabled. Test won't have to wait for timeouts.

=item * B<proxy_jump> Jump host hostname, IP addr or point to another entry in config file

=item * B<strict_host_key_checking> Turn off host key check

=back
=cut

sub ssh_config_entry_add {
    my (%args) = @_;
    my $config_path = '~/.ssh/config';
    my @mandatory_args = qw(entry_name hostname);
    foreach (@mandatory_args) {
        croak "Missing mandatory argument: $_" unless $args{$_};
    }

    # passwordless, non-interactive ssh by default
    $args{batch_mode} //= 'yes';
    $args{identities_only} //= 'yes';

    my @file_contents = (
        "Host $args{entry_name}",
        "  HostName $args{hostname}",
        "  IdentitiesOnly $args{identities_only}",
        "  BatchMode $args{batch_mode}"
    );
    push(@file_contents, "  User $args{user}") if $args{user};
    push(@file_contents, "  IdentityFile $args{identity_file}") if $args{identity_file};
    push(@file_contents, "  ProxyJump $args{proxy_jump}") if $args{proxy_jump};
    push(@file_contents, "  StrictHostKeyChecking $args{strict_host_key_checking}") if $args{strict_host_key_checking};
    assert_script_run("echo \"$_\" >> $config_path", quiet => 1) foreach @file_contents;
}

=head2 prepare_ssh_config

    prepare_ssh_config(inventory_data=>HASHREF, jump_host=>10.10.10.10, jump_host_user=>'azureadm');

Reads referenced SDAF inventory data and composes F<~/.ssh/config> entry for each host.
In case of SDAF you need to specify B<jump_host> if you want to set this up on worker VM and access SUT via SSH proxy.
For an example of an SDAF inventory data structure check B<SYNOPSIS> part of this module.

=over

=item * B<inventory_data> SDAF inventory content in referenced perl data structure.

=item * B<jump_host_ip> hostname, IP address or F<~/.ssh/config> entry pointing to jumphost. Keyless SSH must be working.

=item * B<jump_host_user> SSH login user.

=back
=cut

sub prepare_ssh_config {
    my (%args) = @_;
    foreach ('inventory_data', 'jump_host_ip', 'jump_host_user') {
        croak "Missing mandatory argument '\$args{$_}'" unless $args{$_};
    }

    # Add Jumphost first
    ssh_config_entry_add(
        entry_name => "deployer_jump $args{jump_host_ip}",
        user => $args{jump_host_user},
        hostname => $args{jump_host_ip},
        identities_only => 'yes',
        identity_file => $deployer_private_key_path
    );

    # Add all SUT systems defined in inventory file
    for my $instance_type (keys(%{$args{inventory_data}})) {
        my $hosts = $args{inventory_data}->{$instance_type}{hosts};
        for my $hostname (keys %$hosts) {
            my $host_data = $hosts->{$hostname};
            ssh_config_entry_add(
                entry_name => "$hostname $host_data->{ansible_host}",    # This allows both hostname and IP login
                user => $host_data->{ansible_user},
                hostname => $host_data->{ansible_host},
                identity_file => $sut_private_key_path,
                identities_only => 'yes',
                proxy_jump => 'deployer_jump',
                strict_host_key_checking => 'no'
            );
        }
    }
    record_info('SSH config', "SSH proxy setup added into '~/.ssh/config':\n" .
          script_output('cat ~/.ssh/config', quiet => 1));
}

=head2 verify_ssh_proxy_connection

    verify_ssh_proxy_connection(inventory_data=>HASHREF);

Reads parsed and referenced SDAF inventory data and executes simple C<hostname> command on each SUT to verify the
connection is working. A check is performed if C<hostname> output is the same as target from inventory file.
For an example of an SDAF inventory data structure check B<SYNOPSIS> part of this module.

=over

=item * B<inventory_data> SDAF inventory content in referenced perl data structure.

=back
=cut

sub verify_ssh_proxy_connection {
    my (%args) = @_;
    for my $instance_type (keys(%{$args{inventory_data}})) {
        my $hosts = $args{inventory_data}->{$instance_type}{hosts};
        for my $hostname (keys %$hosts) {
            # run simple 'hostname' command on each host
            my $hostname_output = script_output("ssh $hostname hostname", quiet => 1);
            die "Hostname returned does not match target host.\nExpected: $hostname\nGot: $hostname_output"
              unless $hostname_output =~ $hostname;
            record_info('SSH check', "SSH proxy connection to $hostname: OK");
        }
    }
}
