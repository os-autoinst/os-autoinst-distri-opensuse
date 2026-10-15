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

subtest 'power_action leaves a serial terminal before reboot on qemu' => sub {
    set_var('S390_ZKVM', 0);
    set_var(DISTRI => 'sle');
    set_var(VERSION => '15-SP7');
    my (@selected, $serial);
    my $mock = Test::MockModule->new('power_action_utils');
    $mock->redefine(select_console => sub { push @selected, shift });
    $mock->redefine($_ => sub { 1 }) for qw(enter_cmd reset_consoles reboot_x11 poweroff_x11 assert_shutdown_with_soft_timeout);
    $mock->redefine(is_serial_terminal => sub { $serial });
    my $run = sub {
        my ($backend, $is_serial, @args) = @_;
        @selected = ();
        $serial = $is_serial;
        set_var(BACKEND => $backend);
        power_action(@args);
        return [@selected];
    };
    is_deeply $run->('qemu', 1, 'reboot', keepconsole => 1, textmode => 1), ['root-console'], 'qemu, serial, keepconsole -> root-console';
    is_deeply $run->('qemu', 1, 'reboot', keepconsole => 1, textmode => 0), ['x11'], 'qemu, serial, keepconsole, GUI -> x11';
    is_deeply $run->('qemu', 0, 'reboot', keepconsole => 1, textmode => 1), [], 'qemu on the VGA console -> unchanged';
    is_deeply $run->('qemu', 1, 'reboot', keepconsole => 1, textmode => 1, observe => 1), [], 'observe -> unchanged';
    is_deeply $run->('qemu', 1, 'poweroff', keepconsole => 1, textmode => 1), [], 'poweroff -> unchanged';
    is_deeply $run->('generalhw', 1, 'reboot', keepconsole => 1, textmode => 1), [], 'non-qemu -> unchanged';
    is_deeply $run->('qemu', 1, 'reboot', textmode => 1), ['root-console'], 'without keepconsole -> one select as before';
};

done_testing;
