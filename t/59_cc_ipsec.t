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

done_testing;
