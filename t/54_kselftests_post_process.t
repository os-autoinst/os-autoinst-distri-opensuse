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

# Known issues: test_memcg_reclaim and test_memcg_swap_max_peak
package FakeWhitelist {
    sub new { bless {}, shift }

    sub find_whitelist_entry {
        my ($self, $env, $collection, $name) = @_;
        return {} if $name =~ /^(test_memcg_reclaim|test_memcg_swap_max_peak)$/;
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

done_testing;
