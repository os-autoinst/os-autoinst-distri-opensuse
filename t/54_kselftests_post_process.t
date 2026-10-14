use strict;
use warnings;
use Test::More;
use Test::Warnings;
use Test::MockModule;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Cwd qw(getcwd);
use testapi;
use Kselftests::utils;
use Kselftests::parser;

# Known issues: test_memcg_reclaim and test_memcg_swap_max_peak
package FakeWhitelist {
    sub new { bless {}, shift }

    sub find_whitelist_entry {
        my ($self, $env, $collection, @keys) = @_;
        my $name = $keys[-1];
        my $parent = @keys > 1 ? $keys[0] : undef;
        return {} if $name =~ /^(test_memcg_reclaim|test_memcg_swap_max_peak)$/;
        return {} if $name eq 'scoped_by_parent' && defined($parent) && $parent eq 'test_memcontrol';
        return undef;
    }
}

package main;

my $cwd = getcwd;
my @infos;
my %summary;

my $mock = Test::MockModule->new('Kselftests::utils');
$mock->redefine(get_whitelist => sub { FakeWhitelist->new });
$mock->redefine(get_var => sub { $_[1] // '' });
$mock->redefine(record_info => sub { push @infos, $_[0] });
$mock->redefine(upload_logs => sub { });
$mock->redefine(upload_asset => sub { });
$mock->redefine(script_output => sub {
        my ($cmd) = @_;
        return '6.12.0-160100.5-default' if $cmd eq 'uname -r';
        return $summary{$1} if $cmd =~ /^cat (.+)$/;
        die "unexpected script_output: $cmd";
});

# Write the log of one test run, as post_process_single() reads it
sub write_log {
    my ($test, $log) = @_;
    my $dir = tempdir(CLEANUP => 1);
    make_path("$dir/assets_private");
    open(my $fh, '>', "$dir/assets_private/$test") or die $!;
    print $fh $log;
    close($fh);
    chdir $dir;
}

sub memcontrol_log {
    my ($plan, $results, $top) = @_;
    return "TAP version 13\n1..1\n# selftests: cgroup: test_memcontrol\n"
      . "# TAP version 13\n# 1..$plan\n"
      . join('', map { "$_\n" } @$results)
      . "$top\n";
}

my @results_1_to_14 = (
    '# ok 1 test_memcg_subtree_control',
    '# ok 2 test_memcg_current_peak',
    '# ok 3 test_memcg_min',
    '# ok 4 test_memcg_low',
    '# ok 5 test_memcg_high',
    '# ok 6 test_memcg_high_sync',
    '# ok 7 test_memcg_max',
    '# not ok 8 test_memcg_reclaim',
    '# ok 9 test_memcg_oom_events',
    '# not ok 10 test_memcg_swap_max_peak',
    '# ok 11 test_memcg_sock',
    '# ok 12 test_memcg_oom_group_leaf_events',
    '# ok 13 test_memcg_oom_group_parent_events',
    '# ok 14 test_memcg_oom_group_score_events',
);

sub run_single {
    my ($log) = @_;
    @infos = ();
    write_log('test_memcontrol', $log);
    my @ret = post_process_single(logfile => '/tmp/test_memcontrol', collection => 'cgroup',
        test => 'cgroup:test_memcontrol', test_index => 1, ktap => []);
    chdir $cwd;
    return @ret;
}

subtest 'complete run with only known issues is a softfail' => sub {
    my @results = (@results_1_to_14, '# ok 15 test_memcg_inotify_delete_file', '# ok 16 test_memcg_inotify_delete_dir');
    my ($ktap, $s, $h) = run_single(memcontrol_log(16, \@results, 'not ok 1 selftests: cgroup: test_memcontrol # exit=1'));
    is $s, 2, 'two known issues';
    is $h, 0, 'no hard failures';
    like $ktap->[-1], qr/^ok 1 selftests: cgroup: test_memcontrol # TODO Known Issue$/, 'TODO propagated to the top level';
};

subtest 'timeout is a hard failure even with only known issues' => sub {
    my ($ktap, $s, $h) = run_single(memcontrol_log(16, \@results_1_to_14,
            'not ok 1 selftests: cgroup: test_memcontrol # TIMEOUT 300 seconds'));
    is $s, 2, 'two known issues';
    is $h, 1, 'timeout counted as a hard failure';
    ok !(grep { /# TODO Known Issue$/ && /selftests:/ } @$ktap), 'TODO not propagated to the top level';
    ok((grep { $_ eq 'Incomplete' } @infos), 'incomplete run recorded');
};

subtest 'missing subtest results are a hard failure' => sub {
    my ($ktap, $s, $h) = run_single(memcontrol_log(16, \@results_1_to_14,
            'not ok 1 selftests: cgroup: test_memcontrol # exit=1'));
    is $s, 2, 'two known issues';
    is $h, 1, 'missing results counted as a hard failure';
    ok !(grep { /# TODO Known Issue$/ && /selftests:/ } @$ktap), 'TODO not propagated to the top level';
};

subtest 'post_process keeps the failed top-level result of a timed out test' => sub {
    %summary = ('$HOME/summary.tap' => "TAP version 13\n1..1\n# selftests: cgroup: test_memcontrol\n"
          . "not ok 1 selftests: cgroup: test_memcontrol # TIMEOUT 300 seconds\n");
    write_log('test_memcontrol', memcontrol_log(16, \@results_1_to_14,
            'not ok 1 selftests: cgroup: test_memcontrol # TIMEOUT 300 seconds'));
    my ($ktap, $s, $h) = post_process(collection => 'cgroup', tests => ['cgroup:test_memcontrol']);
    chdir $cwd;
    ok $h > 0, 'hard failures reported';
    is $ktap->[-1], 'not ok 1 selftests: cgroup: test_memcontrol # TIMEOUT 300 seconds', 'top-level TIMEOUT result kept';
};

subtest 'subtest lookup is scoped to its parent test' => sub {
    my ($ktap, $s, $h) = run_single(memcontrol_log(1, ['# not ok 1 scoped_by_parent'], 'not ok 1 selftests: cgroup: test_memcontrol # exit=1'));
    is $s, 1, 'the subtest is matched only because the parent test name was passed through';
    is $h, 0, 'no hard failures';
};

subtest 'net default parser' => sub {
    my $p = Kselftests::parser::factory('net', 'bareudp_sh');
    is $p->parse_line('# TEST: IPv4 packets over UDPv4                                       [ OK ]'),
      '# ok 1 IPv4 packets over UDPv4', 'TEST: ... [ OK ] is converted';
    is $p->parse_line('#     TEST: rule6 check: oif redirect to table                        [ OK ]'),
      '# ok 2 rule6 check: oif redirect to table', 'indented TEST: ... [ OK ] is converted';
    is $p->parse_line('# PASS: bridge setup'), '# ok 3 bridge setup', 'PASS: ... is converted';
    is $p->parse_line('# FAIL: bridge_parent_id'), '# not ok 4 bridge_parent_id', 'FAIL: ... is converted';
    is $p->parse_line('# XFAIL: veth0: ethtool dump not supported'),
      '# ok 5 veth0: ethtool dump not supported # TODO Expected failure', 'XFAIL: ... is converted';
    is $p->parse_line('# SKIP: kernel is tainted'), '# SKIP: kernel is tainted', 'SKIP: ... is left untouched';
    is $p->parse_line('# some random text'), '# some random text', 'unmatched lines are left untouched';
};

subtest 'net:arp_ndisc_evict_nocarrier.sh / net:route_localnet.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'arp_ndisc_evict_nocarrier_sh');
    is $p->parse_line('# run arp_evict_nocarrier=1 test'), '# run arp_evict_nocarrier=1 test', 'header is kept as-is';
    is $p->parse_line('# ok'), '# ok 1 arp_evict_nocarrier=1', 'bare ok resolves the pending header';

    my $q = Kselftests::parser::factory('net', 'route_localnet_sh');
    isa_ok $q, 'Kselftests::parsers::net::arp_ndisc_evict_nocarrier_sh', 'route_localnet.sh reuses the same parser';
    $q->parse_line('# run arp_announce test');
    is $q->parse_line('# ok'), '# ok 1 arp_announce', 'bare ok resolves the pending header';
};

subtest 'net:io_uring_zerocopy_tx.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'io_uring_zerocopy_tx_sh');
    is $p->parse_line('# ipv4 udp -m 1 -t 1 -n 32'), '# ipv4 udp -m 1 -t 1 -n 32', 'header is kept as-is';
    is $p->parse_line('# cpu: unable to pin, may increase variance.'),
      '# cpu: unable to pin, may increase variance.', 'diagnostic lines are kept as-is';
    is $p->parse_line('# ok'), '# ok 1 ipv4 udp -m 1 -t 1 -n 32', 'bare ok resolves the pending header';
};

subtest 'net:ip_defrag.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'ip_defrag_sh');
    $p->parse_line('# ipv4 defrag');
    is $p->parse_line('# seed = 1791903594'), '# seed = 1791903594', 'diagnostic lines are kept as-is';
    is $p->parse_line('# PASS'), '# ok 1 ipv4 defrag', 'bare PASS resolves the pending header';
};

subtest 'net:ipv6_flowlabel.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'ipv6_flowlabel_sh');
    is $p->parse_line('# [OK]   flowlabel_get(fd, 1, 255, 0)'),
      '# ok 1 flowlabel_get(fd, 1, 255, 0)', 'status-first [OK] line is converted';
};

subtest 'net:l2_tos_ttl_inherit.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'l2_tos_ttl_inherit_sh');
    is $p->parse_line("# \xe2\x94\x82    gre \xe2\x94\x82     4 \xe2\x94\x82     4 \xe2\x94\x82 inherit 0x08 \xe2\x94\x82  inherit 134 \xe2\x94\x82 false \xe2\x94\x82     OK \xe2\x94\x82"),
      '# ok 1 gre 4->4 tos=inherit 0x08 ttl=inherit 134 vlan=false', 'a table row is converted';
};

subtest 'net:psock_snd.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'psock_snd_sh');
    is $p->parse_line('# raw csum_off with bad offset (expected to fail)'),
      '# raw csum_off with bad offset (expected to fail)', 'header is kept as-is';
    is $p->parse_line('# net.ipv4.conf.lo.accept_local = 1'), undef, 'first sysctl line has no previous case to resolve';
    is $p->parse_line('# ./psock_snd: write: Invalid argument'),
      '# ./psock_snd: write: Invalid argument', 'diagnostic lines are kept as-is';
    $p->parse_line('# raw min size');
    is $p->parse_line('# net.ipv4.conf.lo.accept_local = 1'),
      '# ok 1 raw csum_off with bad offset (expected to fail)',
      'the expected-to-fail case is resolved once the next case starts';
    $p->parse_line('# tx: 42');
    $p->parse_line('# rx: 0');
    is $p->parse_line('# OK'), '# OK', 'bare OK is kept as-is, it is not itself the resolution';
    is $p->parse_line('# OK. All tests passed'), '# ok 2 raw min size', 'the last case is resolved at the closing line';
};

subtest 'net:reuseport_addr_any.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'reuseport_addr_any_sh');
    is $p->parse_line('# UDP IPv4 ... pass'), '# ok 1 UDP IPv4', 'description ... pass is converted';
};

subtest 'net:rps_default_mask.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'rps_default_mask_sh');
    is $p->parse_line('# empty rps_default_mask                                     [ ok ]'),
      '# ok 1 empty rps_default_mask', 'a passing row is converted';
    is $p->parse_line("# changing rps_default_mask doesn't affect existing devices   [fail] expected 1 found 0"),
      "# not ok 2 changing rps_default_mask doesn't affect existing devices: expected 1 found 0",
      'a failing row keeps the extra detail';
};

subtest 'net:run_afpackettests / net:run_netsocktests parser' => sub {
    my $p = Kselftests::parser::factory('net', 'run_afpackettests');
    is $p->parse_line('# running psock_fanout test'), '# running psock_fanout test', 'header is kept as-is';
    is $p->parse_line('# --------------------'), '# --------------------', 'diagnostic lines are kept as-is';
    is $p->parse_line('# [PASS]'), '# ok 1 psock_fanout', 'bracketed status resolves the pending header';

    my $q = Kselftests::parser::factory('net', 'run_netsocktests');
    isa_ok $q, 'Kselftests::parsers::net::run_afpackettests', 'run_netsocktests reuses the same parser';
    $q->parse_line('# running socket test');
    is $q->parse_line('# [PASS]'), '# ok 1 socket', 'bracketed status resolves the pending header';
};

subtest 'net:sctp_vrf.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'sctp_vrf_sh');
    is $p->parse_line('# TEST 01: nobind, connect from client 1, l3mdev_accept=1, Y [PASS]'),
      '# ok 1 nobind, connect from client 1, l3mdev_accept=1, Y', 'numbered TEST line is converted';
};

subtest 'net:skf_net_off.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'skf_net_off_sh');
    $p->parse_line('# filter, fragmented skb (-f) (-F)');
    is $p->parse_line('# bpf filter enabled'), '# bpf filter enabled', 'known diagnostic lines are kept as-is';
    is $p->parse_line('# napi frags mode enabled'), '# napi frags mode enabled', 'known diagnostic lines are kept as-is';
    is $p->parse_line('# raw recv: 0xabababab'), '# raw recv: 0xabababab', 'known diagnostic lines are kept as-is';
    is $p->parse_line('# OK'), '# ok 1 filter, fragmented skb (-f) (-F)', 'bare OK resolves the pending header';
    is $p->parse_line('# net.ipv4.ip_early_demux = 0'), '# net.ipv4.ip_early_demux = 0', 'the one-time sysctl line is kept as-is';
    $p->parse_line('# filter offset=4');
    is $p->parse_line('# OK'), '# ok 2 filter offset=4', 'a description containing = is still used as the pending header';
};

subtest 'net:test_so_rcv.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'test_so_rcv_sh');
    is $p->parse_line('# Rcv test OK for SO_RCVPRIORITY, IPv4'),
      '# ok 1 SO_RCVPRIORITY, IPv4', 'Rcv test OK for ... is converted';
    is $p->parse_line('# Rcv test FAILED for SO_RCVPRIORITY, IPv4'),
      '# not ok 2 SO_RCVPRIORITY, IPv4', 'Rcv test FAILED for ... is converted';
};

subtest 'net:test_vxlan_under_vrf.sh / net:test_vxlan_fdb_changelink.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'test_vxlan_under_vrf_sh');
    is $p->parse_line('# Checking HV connectivity                                           [ OK ]'),
      '# ok 1 Checking HV connectivity', 'description [ OK ] on one line is converted';

    my $q = Kselftests::parser::factory('net', 'test_vxlan_fdb_changelink_sh');
    isa_ok $q, 'Kselftests::parsers::net::test_vxlan_under_vrf_sh', 'test_vxlan_fdb_changelink.sh reuses the same parser';
    is $q->parse_line("# expected two remotes after fdb append\t[ OK ]"),
      '# ok 1 expected two remotes after fdb append', 'tab-separated description [ OK ] is converted';
};

subtest 'net:udpgro.sh / net:udpgro_fwd.sh / net:veth.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'udpgro_sh');
    is $p->parse_line('#  no GRO                                  ok'), '# ok 1 no GRO', 'padded description + ok is converted';
    is $p->parse_line('# UDP fwd perf                             skip - needed 2 CPUs found 1'),
      '# UDP fwd perf                             skip - needed 2 CPUs found 1', 'a skip status is left untouched';

    my $q = Kselftests::parser::factory('net', 'udpgro_fwd_sh');
    isa_ok $q, 'Kselftests::parsers::net::udpgro_sh', 'udpgro_fwd.sh reuses the same parser';
    is $q->parse_line('# GRO frag list                            ok'), '# ok 1 GRO frag list', 'padded description + ok is converted';

    my $r = Kselftests::parser::factory('net', 'veth_sh');
    isa_ok $r, 'Kselftests::parsers::net::udpgro_sh', 'veth.sh reuses the same parser';
    is $r->parse_line('# default - gro flag                                         ok '),
      '# ok 1 default - gro flag', 'padded description + ok is converted';
};

subtest 'net:udpgso.sh parser' => sub {
    my $p = Kselftests::parser::factory('net', 'udpgso_sh');
    $p->parse_line('# ipv4 cmsg');
    is $p->parse_line('# ipv4 tx:1 gso:0'), '# ipv4 tx:1 gso:0', 'internal tx:/gso: lines are kept as-is';
    is $p->parse_line('# ipv4 tx:1473 gso:0 (fail)'), '# ipv4 tx:1473 gso:0 (fail)',
      '(fail) is a case label, not treated as a new header';
    is $p->parse_line('# OK'), '# ok 1 ipv4 cmsg', 'bare OK resolves the pending header';
};

subtest 'net/netfilter:nf_conntrack_packetdrill.sh parser' => sub {
    my $p = Kselftests::parser::factory('net/netfilter', 'nf_conntrack_packetdrill_sh');
    my $warning_line = '# packetdrill/conntrack_syn_challenge_ack.pkt       (ipv4)                    '
      . 'packetdrill/conntrack_syn_challenge_ack.pkt:38: warning handling packet: ...';
    is $p->parse_line($warning_line), $warning_line, 'header with warning noise on the same line is kept as-is';
    is $p->parse_line('# script packet:  0.223897 . 1:1(0) ack 1 win 256 <nop,nop,TS val 1 ecr 1>'),
      '# script packet:  0.223897 . 1:1(0) ack 1 win 256 <nop,nop,TS val 1 ecr 1>', 'diagnostic lines are kept as-is';
    is $p->parse_line('# actual packet:  0.213892 . 1:1(0) ack 1 win 1050 <nop,nop,TS val 115 ecr 1>'),
      '# actual packet:  0.213892 . 1:1(0) ack 1 win 1050 <nop,nop,TS val 115 ecr 1>', 'diagnostic lines are kept as-is';
    is $p->parse_line('# OK'), '# ok 1 packetdrill/conntrack_syn_challenge_ack.pkt       (ipv4)',
      'bare OK resolves the pending header';
    is $p->parse_line('# packetdrill/conntrack_ack_loss_stall.pkt          (ipv4)                    OK'),
      '# ok 2 packetdrill/conntrack_ack_loss_stall.pkt          (ipv4)', 'header with OK on the same line is converted directly';
};

subtest 'net/netfilter:nft_concat_range.sh parser' => sub {
    my $p = Kselftests::parser::factory('net/netfilter', 'nft_concat_range_sh');
    is $p->parse_line('# TEST: correctness'), '# TEST: correctness', 'category header is kept as-is';
    is $p->parse_line('#   net,port                              1s                              [ OK ]'),
      '# ok 1 correctness: net,port', 'description is prefixed with the category';
    is $p->parse_line('#   port,net                              0s                              [ OK ]'),
      '# ok 2 correctness: port,net', 'description is prefixed with the category';
};

done_testing;
