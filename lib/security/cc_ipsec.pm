# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Helpers shared by the Common Criteria IPsec test modules
#
# Maintainer: QE Security <none@suse.de>

package security::cc_ipsec;

use strict;
use warnings;
use testapi;
use Utils::Architectures 'is_s390x';
use mmapi qw(get_current_job_id get_parents);

use base 'Exporter';

our @EXPORT = qw(
  ipsec_peer_ips
  add_ipsec_mm_ip
);
our @EXPORT_OK = qw(ipsec_ip_pair_for_job_id);

# Addresses that tests/network/setup_multimachine.pm sets on x86_64 and aarch64
use constant DEFAULT_SERVER_IP => '10.0.2.101';
use constant DEFAULT_CLIENT_IP => '10.0.2.102';

# Third octet 110..249. This range does not include 192.168.100.0/24 (ipip tunnel),
# 192.168.101.0/24 (static pairs of other s390x multi-machine tests) and
# 192.168.250.0/24 (IPsec virtual IP pool).
use constant NET_FIRST => 110;
use constant NET_COUNT => 140;
# Host pairs .1/.2, .3/.4, ..., .251/.252
use constant PAIRS_PER_NET => 126;

=head1 SYNOPSIS

Helpers for the tests in tests/security/cc/ipsec.

=head2 ipsec_ip_pair_for_job_id

    my ($server_ip, $client_ip) = ipsec_ip_pair_for_job_id($server_job_id);

Return a pair of addresses in the same /24 network. The pair is derived from
the job id of the IPsec server. Jobs with consecutive ids get different pairs.

=cut

sub ipsec_ip_pair_for_job_id {
    my ($job_id) = @_;
    die "Invalid job id\n" unless defined($job_id) && $job_id =~ /^\d+$/;
    my $slot = $job_id % (NET_COUNT * PAIRS_PER_NET);
    my $net = NET_FIRST + int($slot / PAIRS_PER_NET);
    my $host = 1 + 2 * ($slot % PAIRS_PER_NET);
    return ("192.168.$net.$host", "192.168.$net." . ($host + 1));
}

=head2 ipsec_peer_ips

    my ($server_ip, $client_ip) = ipsec_peer_ips();

Return the addresses of the IPsec server and client.

If C<SERVER_IP> and C<CLIENT_IP> are set, use them. On s390x, all
multi-machine guests share one network. Thus a static pair causes address
conflicts when more than one cluster runs at the same time (poo#201363). On
s390x the pair is derived from the job id of the server, see
L</ipsec_ip_pair_for_job_id>. On the other architectures the function
returns the addresses that setup_multimachine sets.

=cut

sub ipsec_peer_ips {
    my @peer_ips;
    my $server_ip = get_var('SERVER_IP');
    my $client_ip = get_var('CLIENT_IP');
    if ($server_ip || $client_ip) {
        die "Set both SERVER_IP and CLIENT_IP, or none of them\n" unless $server_ip && $client_ip;
        @peer_ips = ($server_ip, $client_ip);
    }
    elsif (is_s390x) {
        # get_parents returns parallel parents only, the client has one: the server
        my $server_job_id = check_var('HOSTNAME', 'server') ? get_current_job_id() : get_parents()->[0];
        die "Cannot find the job id of the IPsec server\n" unless $server_job_id;
        @peer_ips = ipsec_ip_pair_for_job_id($server_job_id);
    }
    else {
        @peer_ips = (DEFAULT_SERVER_IP, DEFAULT_CLIENT_IP);
    }
    record_info('IPsec peers', "server: $peer_ips[0]\nclient: $peer_ips[1]");
    return @peer_ips;
}

=head2 add_ipsec_mm_ip

    add_ipsec_mm_ip($ip, $netdev);

Add C<$ip>/24 to C<$netdev>. Before that, do a duplicate address detection
with arping. If an other host uses the address, die with a clear message.

=cut

sub add_ipsec_mm_ip {
    my ($ip, $netdev) = @_;
    # arping -D: 0 = no reply (address is free), 1 = an other host replied
    my $ret = script_run("arping -D -q -c 2 -w 3 -I $netdev $ip");
    die "IP $ip is already in use on the shared network, maybe by an other job\n" if defined($ret) && $ret == 1;
    record_info('arping', "Duplicate address detection for $ip did not complete (exit code: " . ($ret // 'timeout') . ')') if !defined($ret) || $ret != 0;
    assert_script_run("ip addr add $ip/24 dev $netdev");
}

1;
