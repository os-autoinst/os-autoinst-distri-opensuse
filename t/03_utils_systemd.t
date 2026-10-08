use strict;
use warnings;
use Test::More;
use Test::Warnings;

use Utils::Systemd;

use Test::MockModule;
my $systemd = Test::MockModule->new('Utils::Systemd', no_auto => 1);
my @calls;
$systemd->redefine(script_run => sub { push @calls, @_; });
disable_and_stop_service('foo', ignore_failure => 1);
like $calls[0], qr/systemctl.*disable foo/, 'script_run called with arguments';

done_testing;
