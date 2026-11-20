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
use utils 'script_retry';
use Utils::Architectures 'is_s390x';
use mmapi qw(get_current_job_id get_parents);

use base 'Exporter';

our @EXPORT = qw(
  ipsec_peer_ips
  add_ipsec_mm_ip
  wait_ipsec_conn
  upload_ipsec_diagnostics
  check_ipsec_traffic
  run_ipsec_case
  gmac_refused_by_kernel
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

# Address of the server in the ipip tunnel, see ipsec_setup_tunnel_server.sh
use constant SERVER_TUNNEL_IP => '192.168.100.1';
# Connection name in /etc/ipsec.conf of the client (TOE)
use constant CLIENT_CONN => 'ikev2suse';
# Logged when an ESP proposal mixes classic and AEAD algorithms
use constant AEAD_MIX_ERROR => 'classic and combined-mode (AEAD) encryption algorithms';
# Logged when the kernel does not have the AEAD algorithm of an SA. xfrm
# returns ENOSYS (38) in both cases. Kernels with netlink extended ACK in xfrm
# (SLE 15 SP6 and later) also give a message, older kernels (SLE 15 SP4 and
# SP5) only give the errno.
my $aead_refused_re = qr/received netlink error: (?:Requested AEAD algorithm not found|Function not implemented) \(38\)/;

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

=head2 wait_ipsec_conn

    wait_ipsec_conn($conn_name [, retry => 30] [, die => 1]);

Wait until charon is up and has loaded the connection C<$conn_name>.
C<ipsec start> and C<ipsec restart> return before this occurs.
With C<die =E<gt> 0>, return 1 if the connection is loaded, else 0.

=cut

sub wait_ipsec_conn {
    my ($conn, %args) = @_;
    # No 'grep -q': it can stop reading early and make the pipe fail with pipefail
    my $ret = script_retry("ipsec statusall | grep '^ *$conn:'", retry => $args{retry} // 30, delay => 2, timeout => 10, die => $args{die} // 1);
    return defined($ret) && $ret == 0 ? 1 : 0;
}

=head2 upload_ipsec_diagnostics

    upload_ipsec_diagnostics();

Collect the IPsec, xfrm and network state, and the strongSwan logs. Upload
them. Use this in post_fail_hook, it does not die.

=cut

sub upload_ipsec_diagnostics {
    my %cmds = (
        'ipsec-statusall' => 'ipsec statusall',
        'ip-xfrm' => 'ip -s xfrm state; ip -s xfrm policy',
        'ip-net' => 'ip -s addr; ip route show table all; ip neigh; ip tunnel show',
        'strongswan-journal' => "journalctl -b --no-pager -n 20000 -u 'strongswan*'; journalctl -b --no-pager -n 20000 -t charon -t ipsec_starter",
        # The kernel refuses algorithms that FIPS mode does not allow, strongSwan reports NO_PROPOSAL_CHOSEN then
        'kernel-crypto' => "dmesg | grep -E 'alg:|xfrm'",
    );
    foreach my $name (sort keys %cmds) {
        my $file = "/tmp/$name.txt";
        eval {
            script_run("($cmds{$name}) > $file 2>&1", timeout => 90);
            upload_logs($file, failok => 1);
        };
        record_info('diagnostics', "Cannot collect $name: $@") if $@;
    }
}

=head2 check_ipsec_traffic

    my ($ok, $message) = check_ipsec_traffic($conn, $virtual_ip);

Send ping requests from the virtual IP of the client to the server address in
the ipip tunnel. Only the CHILD_SA of C<$conn> protects this traffic.
Then make sure that the CHILD_SA counted bytes in both directions.

Do not ping the virtual IP itself: it is an address of the client, thus the
ping works also without an SA.

=cut

sub check_ipsec_traffic {
    my ($conn, $vip) = @_;
    return (0, 'The server did not assign a virtual IP') unless $vip;
    my $ret = script_retry("ping -c 3 -W 2 -I $vip " . SERVER_TUNNEL_IP, retry => 3, delay => 5, die => 0);
    return (0, "No ping replies from " . SERVER_TUNNEL_IP . " with source $vip") if !defined($ret) || $ret != 0;
    my $status = script_output("ipsec statusall $conn", proceed_on_failure => 1);
    my ($bytes_in, $bytes_out) = $status =~ /\Q$conn\E\{\d+\}:.*?\b(\d+) bytes_i\b.*?\b(\d+) bytes_o\b/;
    return (0, "The CHILD_SA did not count the traffic\n\n$status") unless $bytes_in && $bytes_out;
    return (1, "The CHILD_SA protected the traffic: $bytes_in bytes in, $bytes_out bytes out");
}

=head2 run_ipsec_case

    my $ok = run_ipsec_case(
        name => 'ESP: aes128-sha512-modp2048!',
        conf => {keyexchange => 'ikev2', ike => 'aes256ctr-sha256-modp2048', esp => 'aes128-sha512-modp2048!'},
        expect => 'pass',
        proposal => qr{ESP:AES_CBC_128/HMAC_SHA2_512_256/},
    );

Set the keys in C<conf> in the C<ikev2suse> connection of /etc/ipsec.conf,
start strongSwan, bring up the connection and compare the result with
C<expect>:

=over

=item * C<pass>: the IKE_SA and the CHILD_SA are established, the selected
proposal matches the regex C<proposal> and the CHILD_SA protects traffic.

=item * C<fail>: the connection is not established and the output of
C<ipsec up> matches the regex C<reason>.

=item * C<invalid>: strongSwan rejects the proposal because it mixes classic
and AEAD algorithms, thus it does not load the connection.

=back

Record the result and the output of C<ipsec up>, then stop strongSwan.
Return 1 if the result is as expected, else 0.

=cut

sub run_ipsec_case {
    my (%args) = @_;
    my $conn = CLIENT_CONN;
    my $expect = $args{expect};
    my $timeout = $args{timeout} // (is_s390x ? 300 : 90);
    die "Unknown expected result '$expect'\n" unless $expect =~ /^(pass|fail|invalid)$/;

    # Clean up after a previous case
    script_run('ipsec stop');
    foreach my $key (sort keys %{$args{conf}}) {
        # Single quotes: the values can contain '!'
        assert_script_run("sed -i 's/^\\(\\s*$key=\\).*/\\1$args{conf}->{$key}/' /etc/ipsec.conf");
    }

    my $count_aead_errors = "journalctl -b --no-pager -o cat | grep -cF '" . AEAD_MIX_ERROR . "'";
    my $aead_errors = $expect eq 'invalid' ? script_output("$count_aead_errors || true") : 0;

    # A problem in one case must not stop the next cases, thus do not die
    my ($ok, $message);
    if ((script_run('ipsec start') // 1) != 0) {
        $message = "'ipsec start' failed";
    }
    elsif ($expect eq 'invalid') {
        my $ret = script_retry("test \$($count_aead_errors) -gt $aead_errors", retry => 15, delay => 2, die => 0);
        my $up = script_output("ipsec up $conn 2>&1", timeout => $timeout, proceed_on_failure => 1);
        $ok = defined($ret) && $ret == 0 && $up =~ /no config named '$conn'/;
        $message = $ok ? 'strongSwan rejected the proposal as expected' : 'strongSwan did not reject the proposal';
        $message .= "\n\n$up";
    }
    elsif (!wait_ipsec_conn($conn, retry => 15, die => 0)) {
        $message = "charon did not load the connection $conn";
    }
    else {
        my $up = script_output("ipsec up $conn 2>&1", timeout => $timeout, proceed_on_failure => 1);
        my $established = $up =~ /CHILD_SA \Q$conn\E\{\d+\} established/ && $up =~ /connection '$conn' established successfully/;
        if ($expect eq 'fail') {
            $ok = !$established && $up =~ $args{reason};
            $message = $ok ? 'The connection failed as expected' : 'The connection did not fail with the expected reason';
        }
        elsif (!$established) {
            $message = 'The connection was not established';
        }
        elsif ($up !~ /selected proposal: $args{proposal}/) {
            $message = 'An unexpected proposal was selected';
        }
        else {
            my ($vip) = $up =~ /installing new virtual IP (\S+)/;
            ($ok, $message) = check_ipsec_traffic($conn, $vip);
        }
        $message .= "\n\n$up";
        script_run("ipsec down $conn", timeout => $timeout);
    }
    script_run('ipsec stop');

    record_info($args{name}, $message, result => $ok ? 'ok' : 'fail');
    return $ok ? 1 : 0;
}

=head2 gmac_refused_by_kernel

    my $refused = gmac_refused_by_kernel($server_log);

C<$server_log> holds the charon log of the server. Return 1 if the server
selected the ESP AES-GMAC proposal and the next ESP selection or kernel
error in the log is the netlink error ENOSYS (38), that is the kernel
refused the algorithm. Newer kernels log it as "Requested AEAD algorithm
not found (38)", older kernels as "Function not implemented (38)". Other
log lines between the two do not matter. Return 0 in all other cases, for
example when the server rejected the proposal because its proposals did not
match.

=cut

sub gmac_refused_by_kernel {
    my ($log) = @_;
    my @lines = grep { /selected proposal: ESP:|$aead_refused_re/ } split(/\n/, $log // '');
    foreach my $i (0 .. $#lines - 1) {
        return 1 if $lines[$i] =~ m{selected proposal: ESP:NULL_AES_GMAC_192/} && $lines[$i + 1] =~ $aead_refused_re;
    }
    return 0;
}

1;
