use strict;
use warnings;
use Test::Fatal;
use Test::More;
use Test::Warnings;
use Test::MockModule;
use Test::MockObject;
use testapi 'set_var';

use power_action_utils;


is prepare_system_shutdown, undef, 'prepare_system_shutdown has no effect by default';
set_var('BACKEND', 'spvm');
my @calls;
my $mock = Test::MockModule->new('power_action_utils');
$mock->redefine(console => sub {
        push @calls, @_;
        Test::MockObject->new()->set_true('kill_ssh')->set_true('disable_vnc_stalls')->set_true('stop_serial_grab');
});
is prepare_system_shutdown, undef, 'prepare_system_shutdown for spvm is fine';
is_deeply \@calls, ['root-ssh'], 'root-ssh console accessed';
@calls = [];
set_var('S390_ZKVM', 1);
like exception { prepare_system_shutdown }, qr/required.*SVIRT_VNC_CONSOLE/, 'needs svirt VNC console';
set_var('SVIRT_VNC_CONSOLE', 'my_svirt_vnc');
is prepare_system_shutdown, undef, 'prepare_system_shutdown for zkvm is fine';
is $calls[-1], 'svirt', 'svirt consoles accessed';

my $shutdown_checks = 0;
my $shutdown_asserts = 0;
my $check_shutdown_result = 0;
$mock->redefine(check_shutdown => sub { $shutdown_checks++; return $check_shutdown_result });
$mock->redefine(assert_shutdown => sub { $shutdown_asserts++; return });

set_var('BACKEND', 's390x');
is assert_shutdown_with_soft_timeout({timeout => 240, soft_timeout => 60}), undef, 'z/VM skips the shutdown wait';
is $shutdown_checks, 0, 'z/VM does not check for shutdown';
is $shutdown_asserts, 0, 'z/VM does not assert shutdown';

set_var('BACKEND', 'qemu');
$check_shutdown_result = 1;
is assert_shutdown_with_soft_timeout({timeout => 240, soft_timeout => 60}), undef, 'soft timeout returns after check_shutdown succeeds';
is $shutdown_checks, 1, 'soft timeout calls check_shutdown';
is $shutdown_asserts, 0, 'soft timeout does not assert shutdown after success';

$shutdown_checks = 0;
$shutdown_asserts = 0;
$check_shutdown_result = 0;
is assert_shutdown_with_soft_timeout({timeout => 10}), undef, 'qemu still checks for shutdown';
is $shutdown_checks, 0, 'no check_shutdown without soft timeout';
is $shutdown_asserts, 1, 'qemu calls assert_shutdown';

done_testing;
