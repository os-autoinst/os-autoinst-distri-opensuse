use strict;
use warnings;
use Test::More;
use Test::MockModule;
use Test::Warnings;
use upload_system_log;

my (@runs, @uploads);
my $mock = Test::MockModule->new('upload_system_log');
$mock->redefine(script_run => sub { push @runs, $_[1]; 0 });
$mock->redefine(upload_logs => sub { my ($file, %args) = @_; push @uploads, $args{timeout} });

sub reset_calls { @runs = (); @uploads = () }

subtest 'default timeouts' => sub {
    reset_calls;
    upload_system_logs();
    ok scalar @runs, 'commands run';
    is_deeply [grep { $_ != 40 } @runs], [], 'all commands use 40s';
    is_deeply \@uploads, [100, 100, 100], 'all uploads use 100s';
};

subtest 'custom timeouts' => sub {
    reset_calls;
    upload_system_logs(timeout => 180, upload_timeout => 200);
    ok scalar @runs, 'commands run';
    is_deeply [grep { $_ != 180 } @runs], [], 'all commands use the given timeout';
    is_deeply \@uploads, [200, 200, 200], 'all uploads use the given upload_timeout';
};

subtest 'method call keeps default' => sub {
    reset_calls;
    my $log = upload_system_log->system_status();
    is $log, '/tmp/system-status.txt', 'default log file';
    is_deeply [grep { $_ != 40 } @runs], [], 'commands use 40s';
};

done_testing;
