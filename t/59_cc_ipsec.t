use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::MockModule;
use Test::Warnings;
use testapi;

use security::cc_ipsec qw(:DEFAULT ipsec_ip_pair_for_job_id);

subtest '[ipsec_ip_pair_for_job_id] address range' => sub {
    my %seen;
    my $bad = 0;
    # One full cycle of slots and some real OSD job ids
    for my $id (0 .. 17639, 25576376, 25576377, 99999999) {
        my ($server, $client) = ipsec_ip_pair_for_job_id($id);
        my ($snet, $shost) = $server =~ /^192\.168\.(\d+)\.(\d+)$/;
        my ($cnet, $chost) = $client =~ /^192\.168\.(\d+)\.(\d+)$/;
        $bad++ unless defined($snet) && defined($cnet)
          && $snet == $cnet
          && $snet >= 110 && $snet <= 249
          && $shost % 2 == 1 && $shost >= 1 && $shost <= 251
          && $chost == $shost + 1;
        $seen{$server}++ if $id <= 17639;
    }
    is $bad, 0, 'all pairs are in 192.168.110-249.x, same /24, server odd, client = server + 1';
    is scalar(keys %seen), 17640, 'one full cycle gives 17640 different pairs';
    isnt((ipsec_ip_pair_for_job_id(25576376))[0], (ipsec_ip_pair_for_job_id(25576377))[0], 'consecutive job ids give different pairs');
    is_deeply [ipsec_ip_pair_for_job_id(17640)], [ipsec_ip_pair_for_job_id(0)], 'the pairs repeat after one cycle';
};

subtest '[ipsec_ip_pair_for_job_id] invalid job id' => sub {
    dies_ok { ipsec_ip_pair_for_job_id(undef) } 'undef job id';
    dies_ok { ipsec_ip_pair_for_job_id('abc') } 'not a number';
};

sub mock_env {
    my (%args) = @_;
    my $mock = Test::MockModule->new('security::cc_ipsec');
    my %vars = %{$args{vars} // {}};
    $mock->redefine(get_var => sub { $vars{$_[0]} // $_[1] });
    $mock->redefine(check_var => sub { ($vars{$_[0]} // '') eq $_[1] });
    $mock->redefine(is_s390x => sub { $args{s390x} // 0 });
    $mock->redefine(get_current_job_id => sub { $args{job_id} });
    $mock->redefine(get_parents => sub { $args{parents} // [] });
    $mock->noop('record_info');
    return $mock;
}

subtest '[ipsec_peer_ips] SERVER_IP and CLIENT_IP are set' => sub {
    my $mock = mock_env(s390x => 1, vars => {SERVER_IP => '192.168.101.1', CLIENT_IP => '192.168.101.2'});
    is_deeply [ipsec_peer_ips()], ['192.168.101.1', '192.168.101.2'], 'the variables win';
};

subtest '[ipsec_peer_ips] only one variable is set' => sub {
    my $mock = mock_env(vars => {SERVER_IP => '192.168.101.1'});
    throws_ok { ipsec_peer_ips() } qr/Set both SERVER_IP and CLIENT_IP/, 'dies';
};

subtest '[ipsec_peer_ips] not s390x' => sub {
    my $mock = mock_env(s390x => 0, vars => {HOSTNAME => 'client'});
    is_deeply [ipsec_peer_ips()], ['10.0.2.101', '10.0.2.102'], 'setup_multimachine addresses';
};

subtest '[ipsec_peer_ips] s390x derives the same pair on both peers' => sub {
    my @expected = ipsec_ip_pair_for_job_id(25576375);
    my $mock = mock_env(s390x => 1, job_id => 25576375, vars => {HOSTNAME => 'server'});
    is_deeply [ipsec_peer_ips()], \@expected, 'server uses its own job id';
    $mock = mock_env(s390x => 1, job_id => 25576376, parents => [25576375], vars => {HOSTNAME => 'client'});
    is_deeply [ipsec_peer_ips()], \@expected, 'client uses the job id of its parallel parent';
    $mock = mock_env(s390x => 1, job_id => 25576376, parents => [], vars => {HOSTNAME => 'client'});
    throws_ok { ipsec_peer_ips() } qr/Cannot find the job id/, 'client without parallel parent dies';
};

subtest '[add_ipsec_mm_ip]' => sub {
    my $mock = Test::MockModule->new('security::cc_ipsec');
    my (@cmds, @infos, $arping);
    $mock->redefine(script_run => sub { push @cmds, $_[0]; return $arping });
    $mock->redefine(assert_script_run => sub { push @cmds, $_[0]; return 0 });
    $mock->redefine(record_info => sub { push @infos, $_[0] });

    $arping = 0;
    add_ipsec_mm_ip('192.168.120.1', 'eth0');
    like $cmds[0], qr/^arping -D .*-I eth0 192\.168\.120\.1$/, 'duplicate address detection first';
    is $cmds[1], 'ip addr add 192.168.120.1/24 dev eth0', 'then the address is added';

    @cmds = ();
    $arping = 1;
    throws_ok { add_ipsec_mm_ip('192.168.120.1', 'eth0') } qr/already in use/, 'dies on a duplicate address';
    is scalar(@cmds), 1, 'the address is not added';

    @cmds = ();
    $arping = undef;
    add_ipsec_mm_ip('192.168.120.1', 'eth0');
    is $cmds[1], 'ip addr add 192.168.120.1/24 dev eth0', 'arping timeout does not block the test';
    is $infos[-1], 'arping', 'but it is recorded';
};

# Output of 'ipsec up' from real jobs, shortened
my $up_ok = <<'EOS';
selected proposal: IKE:AES_GCM_12_128/PRF_HMAC_SHA2_256/MODP_2048
installing new virtual IP 192.168.250.1
IKE_SA ikev2suse[1] established between 192.168.100.2[client]...192.168.100.1[server]
selected proposal: ESP:AES_CBC_128/HMAC_SHA2_512_256/NO_EXT_SEQ
CHILD_SA ikev2suse{1} established with SPIs ca713048_i c8282f74_o and TS 192.168.250.1/32 === 192.168.100.1/32
connection 'ikev2suse' established successfully
EOS
my $up_no_child = <<'EOS';
selected proposal: IKE:AES_GCM_12_128/PRF_HMAC_SHA2_256/MODP_2048
installing new virtual IP 192.168.250.1
IKE_SA ikev2suse[1] established between 192.168.100.2[client]...192.168.100.1[server]
received NO_PROPOSAL_CHOSEN notify, no CHILD_SA built
failed to establish CHILD_SA, keeping IKE_SA
establishing connection 'ikev2suse' failed
EOS
my $status_ok = "ikev2suse{1}:  AES_CBC_128/HMAC_SHA2_512_256, 252 bytes_i (3 pkts, 0s ago), 252 bytes_o (3 pkts, 0s ago)\n";

sub mock_case {
    my (%args) = @_;
    my $mock = Test::MockModule->new('security::cc_ipsec');
    my %calls = (cmds => [], infos => []);
    $mock->redefine(is_s390x => sub { 0 });
    $mock->redefine(script_run => sub { push @{$calls{cmds}}, $_[0]; 0 });
    $mock->redefine(assert_script_run => sub { push @{$calls{cmds}}, $_[0]; 0 });
    $mock->redefine(wait_ipsec_conn => sub { push @{$calls{cmds}}, "wait $_[0]"; $args{conn_loaded} // 1 });
    $mock->redefine(script_retry => sub { push @{$calls{cmds}}, $_[0]; $args{retry} // 0 });
    $mock->redefine(record_info => sub { push @{$calls{infos}}, {title => $_[0], text => $_[1], @_[2 .. $#_]} });
    $mock->redefine(script_output => sub {
            my ($cmd) = @_;
            push @{$calls{cmds}}, $cmd;
            return $args{up} if $cmd =~ /^ipsec up/;
            return $args{status} // '' if $cmd =~ /^ipsec statusall/;
            return 3 if $cmd =~ /grep -cF/;
            die "unexpected command: $cmd";
    });
    return ($mock, \%calls);
}

my %esp_case = (
    name => 'ESP: aes128-sha512-modp2048!',
    conf => {keyexchange => 'ikev2', ike => 'aes256ctr-sha256-modp2048', esp => 'aes128-sha512-modp2048!'},
    expect => 'pass',
    proposal => qr{ESP:AES_CBC_128/HMAC_SHA2_512_256/},
);

subtest '[run_ipsec_case] pass' => sub {
    my ($mock, $calls) = mock_case(up => $up_ok, status => $status_ok);
    is run_ipsec_case(%esp_case), 1, 'expected result';
    ok((grep { $_ eq q{sed -i 's/^\(\s*esp=\).*/\1aes128-sha512-modp2048!/' /etc/ipsec.conf} } @{$calls->{cmds}}), 'esp set with single quotes');
    ok((grep { /^ping -c 3 -W 2 -I 192\.168\.250\.1 192\.168\.100\.1$/ } @{$calls->{cmds}}), 'ping from the virtual IP to the server');
    is $calls->{infos}[-1]{result}, 'ok', 'recorded as ok';
};

subtest '[run_ipsec_case] IKE_SA without CHILD_SA is not a pass' => sub {
    my ($mock, $calls) = mock_case(up => $up_no_child, status => $status_ok);
    is run_ipsec_case(%esp_case), 0, 'the old false positive is detected';
    like $calls->{infos}[-1]{text}, qr/not established/, 'reason recorded';
    is $calls->{infos}[-1]{result}, 'fail', 'recorded as fail';
};

subtest '[run_ipsec_case] unexpected proposal' => sub {
    my ($mock, $calls) = mock_case(up => $up_ok =~ s{AES_CBC_128/HMAC_SHA2_512_256}{AES_GCM_16_256}r, status => $status_ok);
    is run_ipsec_case(%esp_case), 0, 'wrong ESP proposal';
    like $calls->{infos}[-1]{text}, qr/unexpected proposal/, 'reason recorded';
};

subtest '[run_ipsec_case] no traffic through the CHILD_SA' => sub {
    my ($mock, $calls) = mock_case(up => $up_ok, status => $status_ok =~ s/252 bytes_i/0 bytes_i/r);
    is run_ipsec_case(%esp_case), 0, 'zero bytes in';
    my ($mock2) = mock_case(up => $up_ok, status => $status_ok, retry => 1);
    is run_ipsec_case(%esp_case), 0, 'no ping replies';
};

subtest '[run_ipsec_case] a stuck case is a failure, not a die' => sub {
    my ($mock, $calls) = mock_case(up => $up_ok, status => $status_ok, conn_loaded => 0);
    is run_ipsec_case(%esp_case), 0, 'charon did not load the connection';
    like $calls->{infos}[-1]{text}, qr/did not load the connection/, 'reason recorded';
    ok(!(grep { /^ipsec up/ } @{$calls->{cmds}}), 'no ipsec up without the connection');
    is $calls->{cmds}[-1], 'ipsec stop', 'strongSwan is stopped for the next case';
};

subtest '[run_ipsec_case] fail' => sub {
    my %case = (%esp_case, expect => 'fail', reason => qr/no CHILD_SA built/);
    my ($mock, $calls) = mock_case(up => $up_no_child);
    is run_ipsec_case(%case), 1, 'failed with the expected reason';
    ($mock, $calls) = mock_case(up => $up_ok, status => $status_ok);
    is run_ipsec_case(%case), 0, 'an established connection is not a fail';
    ($mock, $calls) = mock_case(up => "parsed IKE_SA_INIT response 0 [ N(NO_PROP) ]\n");
    is run_ipsec_case(%case), 0, 'a different failure reason is not accepted';
};

subtest '[run_ipsec_case] invalid' => sub {
    my %case = (name => 'ESP: aes192-aes192gmac-modp2048!', conf => {esp => 'aes192-aes192gmac-modp2048!'}, expect => 'invalid');
    my ($mock, $calls) = mock_case(up => "no config named 'ikev2suse'\n");
    is run_ipsec_case(%case), 1, 'rejected proposal';
    ok(!(grep { /^wait / } @{$calls->{cmds}}), 'does not wait for a connection that cannot load');
    ($mock, $calls) = mock_case(up => "no config named 'ikev2suse'\n", retry => 1);
    is run_ipsec_case(%case), 0, 'no rejection message in the journal';
    dies_ok { run_ipsec_case(%case, expect => 'maybe') } 'unknown expected result';
};

subtest '[gmac_refused_by_kernel]' => sub {
    my $refused = <<'EOS';
selected proposal: ESP:AES_CBC_128/HMAC_SHA2_512_256/NO_EXT_SEQ
CHILD_SA ikev2ios{3} established with SPIs c1d3a819_i c6b92e72_o
selected proposal: ESP:NULL_AES_GMAC_192/NO_EXT_SEQ
received netlink error: Requested AEAD algorithm not found (38)
unable to add SAD entry with SPI c15fb0d0 (FAILED)
selected proposal: ESP:AES_CBC_256/HMAC_SHA2_256_128/NO_EXT_SEQ
EOS
    ok gmac_refused_by_kernel($refused), 'GMAC selected, then the kernel error';
    my $extra = $refused =~ s/(GMAC_192\/NO_EXT_SEQ\n)/$1 . "some other charon line\n" x 8/er;
    ok gmac_refused_by_kernel($extra), 'other log lines between the two do not matter';
    my $mismatch = <<'EOS';
selected proposal: ESP:AES_CBC_128/HMAC_SHA2_512_256/NO_EXT_SEQ
no acceptable proposal found
selected proposal: ESP:AES_CBC_256/HMAC_SHA2_256_128/NO_EXT_SEQ
EOS
    ok !gmac_refused_by_kernel($mismatch), 'server proposals that do not match are not a kernel refusal';
    ok !gmac_refused_by_kernel("selected proposal: ESP:NULL_AES_GMAC_192/NO_EXT_SEQ\nselected proposal: ESP:AES_CBC_256/HMAC_SHA2_256_128/NO_EXT_SEQ\nreceived netlink error: Requested AEAD algorithm not found (38)\n"), 'the kernel error must follow the GMAC selection';
    ok !gmac_refused_by_kernel("received netlink error: Requested AEAD algorithm not found (38)\n"), 'kernel error without a GMAC selection';
    ok !gmac_refused_by_kernel(''), 'empty log';
    ok !gmac_refused_by_kernel(undef), 'no log';
};

done_testing;
