use strict;
use warnings;
use Test::More;
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

chdir $orig;
done_testing;
