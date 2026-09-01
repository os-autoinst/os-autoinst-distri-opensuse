# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Host Bus Adapter (HBA) detection helpers for kernel tests.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::hba;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT_OK = qw(
  detect_fc_hba
  list_scsi_hosts
  list_fc_hosts
  check_fc_hosts
);

=head1 SYNOPSIS

Utils for working with Host Bus Adapters.

=cut

=head2 detect_fc_hba

 detect_fc_hba();

Checks whether at least one Fibre Channel HBA port is registered in sysfs.
Returns true/false.

=cut

sub detect_fc_hba {
    return scalar(list_fc_hosts()) > 0;
}

=head2 list_scsi_hosts

 my @hosts = list_scsi_hosts();

Lists the SCSI/SAS host adapters (initiators), via C<lsscsi -H -t> (list
hosts, not devices/LUNs, with transport info), as an array of hashes:
- C<host>: sysfs host name, e.g. C<host0>
- C<driver>: kernel driver bound to the host, e.g. C<ahci>, C<virtio_scsi>,
  C<qla2xxx>
- C<transport>: raw transport string as reported by lsscsi, e.g.
  C<fc:0x50060b00741cc28e,0x0b1900>, C<sata:>, C<usb: 7-1:1.0>; undef if
  lsscsi reports none.

Returns an empty list if none are found.

=cut

sub list_scsi_hosts {
    my @errors;
    my @ret;
    my $lsscsi = script_output('lsscsi -H -t', proceed_on_failure => 1);

    for my $line (split /\n/, $lsscsi) {
        # lsscsi also lists NVMe controllers, tagged '[N:...]' instead of a
        # numeric host; NVMe isn't a SCSI host, so skip it rather than
        # treating it as unrecognized data
        # https://lwn.net/Articles/760545/
        next if $line =~ m/^\[N:/;

        if ($line !~ m/^\[(\d+)\]\s+(\S+)(?:\s+(.*\S))?\s*$/) {
            push @errors, $line;
            next;
        }

        push @ret, {
            host => "host$1",
            driver => $2,
            transport => $3
        };
    }

    if (@errors) {
        record_info('lsscsi -H -t error', "Unrecognized data in lsscsi -H -t output:\n" . join("\n", @errors), result => 'fail');
    }

    return @ret;
}

=head2 list_fc_hosts

 my @hosts = list_fc_hosts();

Lists the Fibre Channel host ports registered in sysfs
(C</sys/class/fc_host>), as an array of hashes:
- C<host>: sysfs host name, e.g. C<host6>
- C<port_state>: link state, e.g. C<Online>, C<Linkdown>, C<Offline>
- C<port_type>: topology, e.g. C<NPort> (fabric via switch), C<NLPort>
  (loop), C<Point-To-Point>
- C<speed>: negotiated link speed, e.g. C<16 Gbit>

Returns an empty list if none are found.

=cut

sub list_fc_hosts {
    my %hosts;
    my $output = script_output(
        'grep -H . /sys/class/fc_host/*/port_state /sys/class/fc_host/*/port_type /sys/class/fc_host/*/speed 2>/dev/null',
        proceed_on_failure => 1
    );

    for my $line (split /\n/, $output) {
        next unless $line =~ m{^/sys/class/fc_host/(host\d+)/(port_state|port_type|speed):(.*)$};
        $hosts{$1}{$2} = $3;
    }

    return map { {host => $_, %{$hosts{$_}}} } sort keys %hosts;
}

=head2 check_fc_hosts

 check_fc_hosts();

Checks that at least C<REQUIRED_FC_PORTS_ONLINE> Fibre Channel ports are
C<Online>, per C<list_fc_hosts()>. Does nothing if the job setting is not
set. Records a failure if fewer are found than required.

Returns the number of C<Online> ports found.

=cut

sub check_fc_hosts {
    my $required = get_var('REQUIRED_FC_PORTS_ONLINE');
    return unless defined $required;

    my @online = grep { $_->{port_state} eq 'Online' } list_fc_hosts();
    if (@online < $required) {
        record_info('FC ports missing',
            "Expected $required Online FC port(s), found " . scalar(@online),
            result => 'fail');
    }
    return scalar(@online);
}

1;
