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
  gcp_external_ip_get
  gcp_external_ip_delete
  gcp_vm_create
  gcp_vm_wait_running
  gcp_vm_terminate
  gcp_get_public_ip
  gcp_get_image_id
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

    my $ret = gcp_network_delete(
        project => 'my-project',
        name => 'my-network');

Delete a VPC network. Does not assert but returns the exit code.

=over

=item B<project> - GCP project ID

=item B<name> - name of the VPC network to delete

=back
=cut

sub gcp_network_delete(%args) {
    foreach (qw(project name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_run(join(' ',
            'gcloud compute networks delete', $args{name},
            '--project', $args{project}));
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
        project => 'my-project',
        region => 'us-central1',
        name => 'my-subnet');

Delete a subnet. Does not assert but returns the exit code.

=over

=item B<project> - GCP project ID

=item B<region> - GCP region

=item B<name> - name of the subnet to delete

=back
=cut

sub gcp_subnet_delete(%args) {
    foreach (qw(project region name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_run(join(' ',
            'gcloud compute networks subnets delete', $args{name},
            '--project', $args{project},
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

=back
=cut

sub gcp_firewall_rule_create(%args) {
    foreach (qw(project name network port)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    assert_script_run(join(' ',
            'gcloud compute firewall-rules create', $args{name},
            '--project', $args{project},
            '--network', $args{network},
            '--allow', "tcp:$args{port}",
            '--source-ranges', '0.0.0.0/0'));
}

=head2 gcp_firewall_rule_delete

    my $ret = gcp_firewall_rule_delete(
        project => 'my-project',
        name => 'allow-ssh');

Delete a firewall rule. Does not assert but returns the exit code.

=over

=item B<project> - GCP project ID

=item B<name> - name of the firewall rule to delete

=back
=cut

sub gcp_firewall_rule_delete(%args) {
    foreach (qw(project name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_run(join(' ',
            'gcloud compute firewall-rules delete', $args{name},
            '--project', $args{project}));
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

=head2 gcp_external_ip_get

    my $ip = gcp_external_ip_get(
        project => 'my-project',
        region => 'us-central1',
        name => 'my-ip');

Get the IP address of a reserved external IP

=over

=item B<project> - GCP project ID

=item B<region> - GCP region

=item B<name> - name of the external IP address

=back
=cut

sub gcp_external_ip_get(%args) {
    foreach (qw(project region name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_output(join(' ',
            'gcloud compute addresses describe', $args{name},
            '--project', $args{project},
            '--region', $args{region},
            '--format="get(address)"'));
}

=head2 gcp_external_ip_delete

    my $ret = gcp_external_ip_delete(
        project => 'my-project',
        region => 'us-central1',
        name => 'my-ip');

Release an external IP address. Does not assert but returns the exit code.

=over

=item B<project> - GCP project ID

=item B<region> - GCP region

=item B<name> - name of the external IP address to delete

=back
=cut

sub gcp_external_ip_delete(%args) {
    foreach (qw(project region name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_run(join(' ',
            'gcloud compute addresses delete', $args{name},
            '--project', $args{project},
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
        address => 'my-ip');

Create a VM instance

=over

=item B<project> - GCP project ID

=item B<zone> - GCP zone (e.g., 'us-central1-a')

=item B<name> - name for the VM instance

=item B<image> - image name

=item B<image_project> - image project name

=item B<machine_type> - machine type (e.g., 'n1-standard-2')

=item B<network> - name of the VPC network

=item B<subnet> - name of the subnet

=item B<address> - name of the external IP address to assign

=item B<timeout> - optional, timeout for the command (default 900)

=back
=cut

sub gcp_vm_create(%args) {
    foreach (qw(project zone name image image_project machine_type network subnet address)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{timeout} //= 900;

    assert_script_run(join(' ',
            'gcloud compute instances create', $args{name},
            '--project', $args{project},
            '--zone', $args{zone},
            '--image', $args{image},
	    '--image-project', $args{image_project},
            '--machine-type', $args{machine_type},
            '--network', $args{network},
            '--subnet', $args{subnet},
            '--address', $args{address}),
        timeout => $args{timeout});
}

=head2 gcp_vm_wait_running

    gcp_vm_wait_running(
        project => 'my-project',
        zone => 'us-central1-a',
        name => 'my-vm',
        timeout => 300);

Wait for a VM instance to reach RUNNING state

=over

=item B<project> - GCP project ID

=item B<zone> - GCP zone

=item B<name> - name of the VM instance

=item B<timeout> - optional, timeout in seconds (default 300)

=back
=cut

sub gcp_vm_wait_running(%args) {
    foreach (qw(project zone name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{timeout} //= 300;

    my $start_time = time();
    while ((time() - $start_time) < $args{timeout}) {
        my $status = script_output(join(' ',
                'gcloud compute instances describe', $args{name},
                '--project', $args{project},
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
        project => 'my-project',
        zone => 'us-central1-a',
        name => 'my-vm');

Delete a VM instance. Does not assert but returns the exit code.

=over

=item B<project> - GCP project ID

=item B<zone> - GCP zone

=item B<name> - name of the VM instance to delete

=back
=cut

sub gcp_vm_terminate(%args) {
    foreach (qw(project zone name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_run(join(' ',
            'gcloud compute instances delete', $args{name},
            '--project', $args{project},
            '--zone', $args{zone}));
}

=head2 gcp_get_public_ip

    my $ip = gcp_get_public_ip(
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

sub gcp_get_public_ip(%args) {
    foreach (qw(project zone name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_output(join(' ',
            'gcloud compute instances describe', $args{name},
            '--project', $args{project},
            '--zone', $args{zone},
            '--format="get(networkInterfaces[0].accessConfigs[0].natIP)"'));
}

=head2 gcp_get_image_id

    gcp_get_image_id(
        project => 'my-project',
        version => 'OS version'
        image_project => 'image-project');

Get the image name

=over

=item B<project> - GCP project ID

=item B<version> - OS version

=item B<image_project> - name for the image project

=back
=cut

sub gcp_get_image_id(%args) {
    foreach (qw(project version image_project)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $image_id = script_output(join(' ',
            'gcloud compute images list --project', $args{project},
            '| grep -i', "sles-sap-$args{version}",
            '| grep -i', $args{image_project},
            '| tail -n 1',
            "| awk '{print \$1}'"));
    return $image_id if ($image_id && $image_id ne '');
    die "No available image found"
}

1;

