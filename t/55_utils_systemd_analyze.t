use strict;
use warnings;
use Test::More;
use Test::Warnings;
use Test::MockModule;

use Utils::SystemdAnalyze;

my $sa = Test::MockModule->new('Utils::SystemdAnalyze', no_auto => 1);
my @record_info;
$sa->redefine(record_info => sub { push @record_info, [@_]; note(join(' ', 'RECORD_INFO -->', @_)); });

subtest '[extract_analyze_time] systemd-analyze time output' => sub {
    my $res = extract_analyze_time('Startup finished in 1.500s (kernel) + 2.000s (initrd) + 10.000s (userspace) = 13.500s');
    is ref $res, 'HASH', 'returns hashref on success';
    cmp_ok $res->{kernel}, '==', 1.5, 'kernel time parsed';
    cmp_ok $res->{initrd}, '==', 2, 'initrd time parsed';
    cmp_ok $res->{userspace}, '==', 10, 'userspace time parsed';
    cmp_ok $res->{overall}, '==', 13.5, 'overall (after =) parsed';
};

subtest '[extract_analyze_time] hours and minutes' => sub {
    my $res = extract_analyze_time('Startup finished in 1.500s (kernel) + 2.000s (initrd) + 1h 2min 3.500s (userspace) = 1h 2min 7.000s');
    cmp_ok $res->{userspace}, '==', 3600 + 2 * 60 + 3.5, 'userspace hours + minutes + seconds parsed';
    cmp_ok $res->{overall}, '==', 3600 + 2 * 60 + 7, 'overall hours + minutes + seconds parsed';
};

subtest '[extract_analyze_time] unparseable time returns undef' => sub {
    is extract_analyze_time('Startup finished in 1.500s (kernel) + 2.000s (initrd) + garbage (userspace) = 13.500s'), undef, 'unparseable time returns undef';
};

subtest '[extract_analyze_time] missing component returns undef' => sub {
    is extract_analyze_time('Startup finished in 1.500s (kernel) + 10.000s (userspace) = 11.500s'), undef, 'incomplete data returns undef';
};

subtest '[extract_blame_time] systemd-analyze blame output' => sub {
    my $res = extract_blame_time(join("\n",
            '1min 30.000s slow.service',
            '5.000s foo.service',
            '2.500s bar.service',
            '500ms fast.service',
            '821us google-shutdown-scripts.service'));
    cmp_ok $res->{'slow.service'}, '==', 90, 'minutes + seconds parsed';
    cmp_ok $res->{'foo.service'}, '==', 5, 'seconds parsed';
    cmp_ok $res->{'bar.service'}, '==', 2.5, 'fractional seconds parsed';
    cmp_ok $res->{'fast.service'}, '==', 0.5, 'milliseconds converted';
    cmp_ok $res->{'google-shutdown-scripts.service'}, '==', 0.000821, 'microseconds converted (poo#207276)';
};

subtest '[extract_blame_time] unparseable line returns empty hashref' => sub {
    is_deeply extract_blame_time('totally bogus'), {}, 'bad time token returns empty hashref';
};

subtest 'SSH login banner does not break parsing (poo#203817)' => sub {
    my $banner = join("\n", '', 'Welcome to SUSE Linux Enterprise Server 15 SP7  (x86_64)', '', 'Authorized users only. All activity may be monitored and reported.');
    my $analyze = extract_analyze_time("$banner\nStartup finished in 2.406s (kernel) + 13.116s (initrd) + 19.353s (userspace) = 34.876s \ngraphical.target reached after 19.290s in userspace.");
    cmp_ok $analyze->{overall}, '==', 34.876, 'overall boot time parsed from banner-prefixed output';
    cmp_ok $analyze->{userspace}, '==', 19.353, 'userspace boot time parsed';
    @record_info = ();
    my $blame = extract_blame_time("$banner\n14.852s some.device\n5.000s other.service\n1h 2min 3.500s very-slow.service");
    cmp_ok $blame->{'some.device'}, '==', 14.852, 'blame entry parsed, banner skipped';
    ok !exists $blame->{'reported.'}, 'banner text not mistaken for a blame entry';
    cmp_ok $blame->{'very-slow.service'}, '==', 3723.5, 'multi-token time after banner parsed';
    is scalar @record_info, 0, 'banner lines do not record parse warnings';
};

done_testing;
