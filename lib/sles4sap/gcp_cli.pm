# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Library wrapper around some gcloud cli commands.

package sles4sap::gcp_cli;
use strict;
use warnings FATAL => 'all';
use Mojo::Base -signatures;
use testapi;
use Carp qw(croak);
use Exporter qw(import);
use utils;


=head1 SYNOPSIS

Library to compose and run GCP gcloud cli commands.
=cut

our @EXPORT = qw(
  gcp_network_create
  gcp_network_delete
  gcp_subnet_create
  gcp_subnet_delete
  gcp_firewall_rule_create
  gcp_firewall_rule_delete
  gcp_external_ip_create
  gcp_external_ip_delete
  gcp_vm_create
  gcp_vm_wait_running
  gcp_vm_terminate
  gcp_public_ip_get
);


=head2 gcp_network_create

    gcp_network_create(
        project => 'my-project',
        name => 'my-network');

Create a new GCP VPC network

=over

=item B<project> - GCP project ID

=item B<name> - name for the VPC network

=back
=cut

sub gcp_network_create(%args) {
    foreach (qw(project name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    assert_script_run(join(' ',
            'gcloud compute networks create', $args{name},
            '--project', $args{project},
            '--subnet-mode=custom'));
}

=head2 gcp_network_delete

    my $ret = gcp_network_delete(name => 'my-network');

Delete a VPC network. Does not assert but returns the exit code.

=over

=item B<name> - name of the VPC network to delete

=back
=cut

sub gcp_network_delete(%args) {
    foreach (qw(name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_run(join(' ',
            'gcloud compute networks delete', $args{name},
            '--quiet'));
}

=head2 gcp_subnet_create

    gcp_subnet_create(
        project => 'my-project',
        region => 'us-central1',
        name => 'my-subnet',
        network => 'my-network',
        cidr => '10.0.0.0/24');

Create a subnet within a VPC network

=over

=item B<project> - GCP project ID

=item B<region> - GCP region (e.g., 'us-central1')

=item B<name> - name for the subnet

=item B<network> - name of the VPC network

=item B<cidr> - CIDR range for the subnet (e.g., '10.0.0.0/24')

=back
=cut

sub gcp_subnet_create(%args) {
    foreach (qw(project region name network cidr)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    assert_script_run(join(' ',
            'gcloud compute networks subnets create', $args{name},
            '--project', $args{project},
            '--region', $args{region},
            '--network', $args{network},
            '--range', $args{cidr}));
}

=head2 gcp_subnet_delete

    my $ret = gcp_subnet_delete(
        region => 'us-central1',
        name => 'my-subnet');

Delete a subnet. Does not assert but returns the exit code.

=over

=item B<region> - GCP region

=item B<name> - name of the subnet to delete

=back
=cut

sub gcp_subnet_delete(%args) {
    foreach (qw(region name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_run(join(' ',
            'gcloud compute networks subnets delete', $args{name},
            '--quiet',
            '--region', $args{region}));
}

=head2 gcp_firewall_rule_create

    gcp_firewall_rule_create(
        project => 'my-project',
        name => 'allow-ssh',
        network => 'my-network',
        port => 22);

Create a firewall rule to allow inbound traffic on a specific port

=over

=item B<project> - GCP project ID

=item B<name> - name for the firewall rule

=item B<network> - name of the VPC network

=item B<port> - port number to allow (e.g., 22 for SSH)

=item B<protocol> - Optional. By default is tcp

=back
=cut

sub gcp_firewall_rule_create(%args) {
    foreach (qw(project name network port)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $protocol = $args{protocol} // 'tcp';
    assert_script_run(join(' ',
            'gcloud compute firewall-rules create', $args{name},
            '--project', $args{project},
            '--network', $args{network},
            '--allow', "$protocol:$args{port}",
            '--source-ranges', '0.0.0.0/0'));
}

=head2 gcp_firewall_rule_delete

    my $ret = gcp_firewall_rule_delete(name => 'allow-ssh');

Delete a firewall rule. Does not assert but returns the exit code.

=over

=item B<name> - name of the firewall rule to delete

=back
=cut

sub gcp_firewall_rule_delete(%args) {
    foreach (qw(name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_run(join(' ',
            'gcloud compute firewall-rules delete', $args{name},
            '--quiet'));
}

=head2 gcp_external_ip_create

    gcp_external_ip_create(
        project => 'my-project',
        region => 'us-central1',
        name => 'my-ip');

Reserve an external static IP address

=over

=item B<project> - GCP project ID

=item B<region> - GCP region

=item B<name> - name for the external IP address

=back
=cut

sub gcp_external_ip_create(%args) {
    foreach (qw(project region name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    assert_script_run(join(' ',
            'gcloud compute addresses create', $args{name},
            '--project', $args{project},
            '--region', $args{region}));
}

=head2 gcp_external_ip_delete

    my $ret = gcp_external_ip_delete(
        region => 'us-central1',
        name => 'my-ip');

Release an external IP address. Does not assert but returns the exit code.

=over

=item B<region> - GCP region

=item B<name> - name of the external IP address to delete

=back
=cut

sub gcp_external_ip_delete(%args) {
    foreach (qw(region name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_run(join(' ',
            'gcloud compute addresses delete', $args{name},
            '--quiet',
            '--region', $args{region}));
}

=head2 gcp_vm_create

    gcp_vm_create(
        project => 'my-project',
        zone => 'us-central1-a',
        name => 'my-vm',
        image => 'sles-sap-$version',
        image_prject => 'cloud',
        machine_type => 'n1-standard-2',
        network => 'my-network',
        subnet => 'my-subnet',
        address => 'my-ip',
        ssh_key => 'ssh public key file);

Create a VM instance

=over

=item B<project> - GCP project ID

=item B<zone> - GCP zone (e.g., 'us-central1-a')

=item B<name> - name for the VM instance

=item B<image> - specifies the boot image for the instances

=item B<image_project> - the Google Cloud project against which all image and image family references will be resolved.
                         If not specified and either image or image-family is provided, the current default project is used.

=item B<machine_type> - machine type (e.g., 'n1-standard-2')

=item B<network> - name of the VPC network

=item B<subnet> - name of the subnet

=item B<address> - name of the external IP address to assign

=item B<ssh_key> - SSH public key file to add to the VM

=item B<timeout> - optional, timeout for the command (default 900)

=back
=cut

sub gcp_vm_create(%args) {
    foreach (qw(project zone name image machine_type network subnet address)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    croak("Argument < image > contains '/' : $args{image}. Please use 'image_project' argument instead.") if $args{image} =~ /\//;
    $args{timeout} //= 900;

    my $ssh_key = script_output("cat $args{ssh_key}");

    my @cmd = ('gcloud compute instances create',
        $args{name},
        '--project', $args{project},
        '--zone', $args{zone},
        '--machine-type', $args{machine_type},
        '--network', $args{network},
        '--subnet', $args{subnet},
        '--address', $args{address},
        '--metadata', "'ssh-keys=cloudadmin:$ssh_key'");
    push @cmd, '--image', $args{image};
    push @cmd, '--image-project', $args{image_project} if $args{image_project};
    assert_script_run(join(' ', @cmd), timeout => $args{timeout});
}

=head2 gcp_vm_wait_running

    gcp_vm_wait_running(
        zone => 'us-central1-a',
        name => 'my-vm',
        timeout => 300);

Wait for a VM instance to reach RUNNING state

=over

=item B<zone> - GCP zone

=item B<name> - name of the VM instance

=item B<timeout> - optional, timeout in seconds (default 300)

=back
=cut

sub gcp_vm_wait_running(%args) {
    foreach (qw(zone name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{timeout} //= 300;

    my $start_time = time();
    while ((time() - $start_time) < $args{timeout}) {
        my $status = script_output(join(' ',
                'gcloud compute instances describe', $args{name},
                '--zone', $args{zone},
                '--format="get(status)"'),
            proceed_on_failure => 1);
        return (time() - $start_time) if ($status eq 'RUNNING');
        sleep 10;
    }
    die "VM $args{name} not running after $args{timeout} seconds";
}

=head2 gcp_vm_terminate

    my $ret = gcp_vm_terminate(
        zone => 'us-central1-a',
        name => 'my-vm');

Delete a VM instance. Does not assert but returns the exit code.

=over

=item B<zone> - GCP zone

=item B<name> - name of the VM instance to delete

=back
=cut

sub gcp_vm_terminate(%args) {
    foreach (qw(zone name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_run(join(' ',
            'gcloud compute instances delete', $args{name},
            '--quiet',
            '--zone', $args{zone}));
}

=head2 gcp_public_ip_get

    my $ip = gcp_public_ip_get(
        project => 'my-project',
        zone => 'us-central1-a',
        name => 'my-vm');

Get the external (public) IP address of a VM instance

=over

=item B<project> - GCP project ID

=item B<zone> - GCP zone

=item B<name> - name of the VM instance

=back
=cut

sub gcp_public_ip_get(%args) {
    foreach (qw(zone name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_output(join(' ',
            'gcloud compute instances describe', $args{name},
            '--zone', $args{zone},
            '--format="get(networkInterfaces[0].accessConfigs[0].natIP)"'));
}

1;

