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

done_testing;
