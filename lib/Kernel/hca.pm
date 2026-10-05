# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Host Channel Adapter (HCA) helpers for kernel tests.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::hca;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT_OK = qw(
  get_hca_devices
  get_hca_info
  get_hca_ports
  get_hca_model
  get_hca_netdevs
);

=head1 SYNOPSIS

Helpers for InfiniBand and RDMA Host Channel Adapters (HCAs), for example
Mellanox/NVIDIA ConnectX adapters with the C<mlx5> driver.

The helpers read the RDMA devices from C</sys/class/infiniband>, so they do
not need C<ibv_devinfo> or other packages. Only C<get_hca_model()> uses
C<lspci>.

 for my $dev (get_hca_devices()) {
     my $info = get_hca_info($dev);
     my $ports = get_hca_ports($dev);
     record_info("HCA $dev", "fw: $info->{fw_ver}\nmodel: " . get_hca_model($dev));
 }

=cut

sub _check_dev {
    my ($dev) = @_;
    die 'No HCA device given' unless defined $dev;
    die "Invalid HCA device name '$dev'" unless $dev =~ /^[\w.-]+$/;
    return "/sys/class/infiniband/$dev";
}

=head2 get_hca_devices

 my @devs = get_hca_devices();

Returns the names of the RDMA devices in C</sys/class/infiniband>, for
example C<mlx5_0> and C<mlx5_1>, sorted. Returns an empty list if there is
no RDMA device, for example if the driver is not loaded.

=cut

sub get_hca_devices {
    my $out = script_output('ls /sys/class/infiniband 2>/dev/null', proceed_on_failure => 1);
    return sort split(' ', $out);
}

sub _parse_key_values {
    my ($text) = @_;
    my %values;
    for my $line (split /\n/, $text // '') {
        next unless $line =~ /^(\w+)=(.*)$/;
        $values{$1} = $2 eq '' ? undef : $2;
    }
    return \%values;
}

=head2 get_hca_info

 my $info = get_hca_info($dev);

Returns a hash reference with the attributes of the RDMA device C<dev>:

=over

=item * C<fw_ver>: firmware version, for example C<16.27.1016>

=item * C<hca_type>: HCA type, for example C<MT4119>

=item * C<board_id>: board ID (PSID), for example C<MT_0000000010>

=item * C<node_guid>: node GUID, for example C<b859:9f03:00d4:2c3a>

=item * C<pci>: PCI address of the adapter, for example C<0000:3b:00.0>

=back

A value is C<undef> if the driver does not provide the attribute. Dies if
the device does not exist.

=cut

sub get_hca_info {
    my ($dev) = @_;
    my $path = _check_dev($dev);
    assert_script_run("test -d $path");
    my $out = script_output(
        "cd $path && for f in fw_ver hca_type board_id node_guid; do echo \"\$f=\$(cat \$f 2>/dev/null)\"; done;"
          . ' echo "pci=$(basename "$(readlink -f device)")"');
    return _parse_key_values($out);
}

sub _parse_ports {
    my ($text) = @_;
    my %ports;
    for my $line (split /\n/, $text // '') {
        next unless $line =~ m{^(\d+)/(\w+):(.*)$};
        my ($port, $attr, $value) = ($1, $2, $3);
        # state and phys_state have a numeric prefix, for example "4: ACTIVE"
        $value =~ s/^\d+:\s*// if $attr =~ /state$/;
        $ports{$port}{$attr} = $value;
    }
    return \%ports;
}

=head2 get_hca_ports

 my $ports = get_hca_ports($dev);

Returns a hash reference of the port numbers of the RDMA device C<dev> to
a hash reference with:

=over

=item * C<state>: logical port state, for example C<ACTIVE> or C<DOWN>

=item * C<phys_state>: physical port state, for example C<LinkUp> or
C<Disabled>

=item * C<rate>: link rate, for example C<100 Gb/sec (4X EDR)>

=item * C<link_layer>: C<InfiniBand> or C<Ethernet>

=back

The numeric prefix of C<state> and C<phys_state> in sysfs (for example
C<4: ACTIVE>) is removed.

=cut

sub get_hca_ports {
    my ($dev) = @_;
    my $path = _check_dev($dev);
    my $out = script_output("cd $path/ports && grep -H . */state */phys_state */rate */link_layer");
    return _parse_ports($out);
}

sub _parse_lspci_model {
    my ($line) = @_;
    # 3b:00.0 Infiniband controller [0207]: Mellanox Technologies MT27800 Family [ConnectX-5] [15b3:1017]
    return $line =~ /^\S+\s+[^:]+:\s*(.+?)\s*$/ ? $1 : undef;
}

=head2 get_hca_model

 my $model = get_hca_model($dev [, pci => $pci]);

Returns the exact adapter model of the RDMA device C<dev> from
C<lspci -nn>, with the PCI vendor and device ID, for example
C<Mellanox Technologies MT27800 Family [ConnectX-5] [15b3:1017]>. The
C<pciutils> package must be installed.

If the caller already has the PCI address of the device, for example from
C<get_hca_info()>, give it as C<pci> to not read it again from sysfs.

=cut

sub get_hca_model {
    my ($dev, %args) = @_;
    my $pci = $args{pci} // get_hca_info($dev)->{pci};
    die "No PCI device for HCA $dev" unless $pci;
    die "Invalid PCI address '$pci'" unless $pci =~ /^[[:xdigit:]]{4}:[[:xdigit:]]{2}:[[:xdigit:]]{2}\.[0-7]$/;
    return _parse_lspci_model(script_output("lspci -nn -s $pci"));
}

=head2 get_hca_netdevs

 my @netdevs = get_hca_netdevs($dev);

Returns the network interfaces of the RDMA device C<dev>, for example
C<ib0> for IP over InfiniBand, sorted. Returns an empty list if the
adapter has no network interface.

=cut

sub get_hca_netdevs {
    my ($dev) = @_;
    my $path = _check_dev($dev);
    my $out = script_output("ls $path/device/net 2>/dev/null", proceed_on_failure => 1);
    return sort split(' ', $out);
}

1;
