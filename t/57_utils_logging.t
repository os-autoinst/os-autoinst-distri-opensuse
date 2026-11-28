use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::MockModule;
use Test::Warnings;
use Mojo::File qw(tempdir);
use Utils::Logging;

my $tmp = tempdir;
my $orig = Mojo::File->new('.')->to_abs;
chdir $tmp;
$tmp->child('ulogs')->make_path;
my (@cmds, @uploads, @i);
{
    package FakeInst;
    sub ssh_script_run { push @i, $_[1]; 0 }
    sub upload_log { my %a = @_[2 .. $#_]; push @i, "$_[1]|$a{log_name}"; $tmp->child('ulogs', $a{log_name})->spew('x') }
}
my $log = Test::MockModule->new('Utils::Logging');
$log->redefine(script_run => sub { push @cmds, shift; 0 });
$log->redefine(upload_logs => sub { my ($f, %a) = @_; push @uploads, $a{log_name}; $tmp->child('ulogs', $a{log_name})->spew('x'); });

subtest 'local' => sub {
    Utils::Logging::upload_sut_packages();
    like $cmds[0], qr/rpm -qa \| LC_ALL=C sort > \/tmp\/sut_packages\.txt/, 'command';
    is_deeply \@uploads, ['sut_packages.txt'], 'uploaded';
    ok -e 'sut_packages.txt', 'moved to result dir';
    ok !-e 'ulogs/sut_packages.txt', 'removed from ulogs';
};

subtest 'instance' => sub {
    unlink 'sut_packages.txt';
    Utils::Logging::upload_sut_packages(instance => bless {}, 'FakeInst');
    like $i[0], qr/LC_ALL=C sort/, 'ssh command';
    is $i[1], '/tmp/sut_packages.txt|sut_packages.txt', 'upload_log';
    ok -e 'sut_packages.txt', 'moved';
};

subtest 'read_ulog' => sub {
    $tmp->child('ulogs/early-log')->spew('early-content');
    $log->redefine(save_screenshot => sub { });
    my (@sleeps, @diags);
    $log->redefine(diag => sub { push @diags, $_[0] });
    $log->redefine(sleep => sub { push @sleeps, 1 });

    is read_ulog('early-log'), 'early-content', 'content read from an already uploaded file';
    is scalar @sleeps, 0, 'no sleep needed for an already uploaded file';
    is scalar @diags, 0, 'no wait message for an already uploaded file';

    $log->redefine(sleep => sub { push @sleeps, 1; $tmp->child('ulogs/late-log')->spew('late-content') });
    is read_ulog('late-log'), 'late-content', 'content read from a file that appears while polling';
    is scalar @sleeps, 1, 'slept once before the file appeared';

    @sleeps = ();
    @diags = ();
    my @screenshots;
    $log->redefine(sleep => sub { push @sleeps, 1 });
    $log->redefine(save_screenshot => sub { push @screenshots, 1 });
    throws_ok { read_ulog('missing-log', timeout => 1) } qr/Gave up reading ulogs\/missing-log after 1 seconds/,
      'dies when the file does not appear before the timeout';
    is scalar @sleeps, 1, 'sleeps once between the two attempts of a one second timeout';
    is scalar @screenshots, 1, 'saves a screenshot before giving up';
    is scalar @diags, 1, 'announces the wait only at the first attempt';
    like $diags[0], qr/^Waiting up to 1 seconds for ulogs\/missing-log$/, 'names the waited file and its bound';

    $log->redefine(save_screenshot => sub { die "no screen connection\n" });
    throws_ok { read_ulog('missing-log', timeout => 1) } qr/Gave up reading ulogs\/missing-log after 1 seconds/,
      'reports the timeout even when the screenshot fails';
    like $diags[-1], qr/Saving a screenshot failed: no screen connection/, 'names the failing screenshot as the cause';
};

chdir $orig;
done_testing;
