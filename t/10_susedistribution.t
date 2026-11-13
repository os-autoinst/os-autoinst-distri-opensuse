#!/usr/bin/perl
# Copyright @ SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Test::Most;
use testapi;
use Test::MockModule;
use susedistribution;

my $testapi_mocked = Test::MockModule->new('testapi');
$testapi_mocked->mock(type_string => sub { 'randompass' });
my $susedistri = susedistribution->new();

my $suse_mocked = Test::MockModule->new('susedistribution');
$suse_mocked->noop(qw(send_key enter_cmd));
# Increase counter for each wait_serial invocation
my $wait_serial_hit = 0;
$suse_mocked->mock(wait_serial => sub { $wait_serial_hit++; return 'Password:' });
# Increase counter for each assert_screen invocation
my $assert_screen_called = 0;
$suse_mocked->mock(assert_screen => sub { $assert_screen_called++; return 1 });
# Increase counter for each wait_still_screen invocation
my $wait_still_screen_called = 0;
$suse_mocked->mock(wait_still_screen => sub { $wait_still_screen_called++; return 1 });

subtest 'handle_password_prompt on serial terminal checks wait_serial' => sub {
    set_var('VIRTIO_CONSOLE', '1');
    set_var('BACKEND', 'qemu');
    $suse_mocked->mock('is_serial_terminal' => 1);
    ok susedistribution::handle_password_prompt(), 'password prompt is handled';
    is $wait_serial_hit, 1, 'wait_serial is called';
    is $assert_screen_called, 0, 'assert screen is not called';
};

subtest 'handle_password_prompt assert screen on when not serial_terminal' => sub {
    set_var('BACKEND', 'qemu');
    $suse_mocked->mock('is_serial_terminal' => 0);
    ok susedistribution::handle_password_prompt(), 'password prompt handled';
    is $wait_serial_hit, 1, 'wait_serial is not called';
    is $assert_screen_called, 1, 'assert screen is called';
};

subtest 'script_sudo works when is not serial_terminal and wait>0' => sub {
    set_var('BACKEND', 'qemu');
    $suse_mocked->mock('is_serial_terminal' => 0);
    local $testapi::serialdev = 23;
    local $testapi::username = 'me';
    ok $susedistri->script_sudo('echo foo', 10);
    is $wait_serial_hit, 2, 'wait_serial is called';
    is $assert_screen_called, 2, 'assert screen is called';
    is $wait_still_screen_called, 0, 'wait still screen is not called';
};

subtest 'script_sudo works when is cmd is bash and is not serial_terminal and wait>0' => sub {
    set_var('BACKEND', 'qemu');
    $suse_mocked->mock('is_serial_terminal' => 0);
    local $testapi::serialdev = 23;
    local $testapi::username = 'me';
    ok $susedistri->script_sudo('bash', 10);
    is $wait_serial_hit, 2, 'wait_serial called';
    is $assert_screen_called, 3, 'assert screen called';
    is $wait_still_screen_called, 1, 'wait still screen is called';
};

subtest 'script_sudo works when is serial_terminal and wait>0' => sub {
    set_var('BACKEND', 'qemu');
    $suse_mocked->mock('is_serial_terminal' => 1);
    local $testapi::username = 'me';
    ok $susedistri->script_sudo('echo foo', 10);
    is $wait_serial_hit, 4, 'wait_serial is called twice';
    is $assert_screen_called, 3, 'assert screen is not called';
    is $wait_still_screen_called, 1, 'wait still screen is not called';
};

subtest 'activate_console sets serial device of ssh console' => sub {
    set_var('BACKEND', 'ipmi');
    my @devs;
    $suse_mocked->noop(qw(handle_password_prompt ensure_user set_standard_prompt diag));
    $suse_mocked->mock(has_serial_over_ssh => 1);
    $suse_mocked->mock(set_sshserial_dev => sub { push @devs, $_[0] });
    local $susedistri->{consoles} = {
        'root-ssh' => {args => {serialdev => 'sshserial'}},
        'root-ssh-virt' => {args => {serialdev => 'virtsshserial'}},
        'other-ssh' => {args => {}},
    };
    $susedistri->activate_console($_) for qw(root-ssh root-ssh-virt other-ssh unknown-ssh);
    is_deeply \@devs, ['sshserial', 'virtsshserial', undef, undef], 'serial device of each ssh console is used, default if not set';
    ok !exists $susedistri->{consoles}->{'unknown-ssh'}, 'no console entry is created for an unknown console';
    $suse_mocked->unmock($_) for qw(handle_password_prompt ensure_user set_standard_prompt diag has_serial_over_ssh set_sshserial_dev);
};

subtest 'save_serial_console does not use a FIFO of an ssh console' => sub {
    my $backends_mocked = Test::MockModule->new('Utils::Backends');
    $backends_mocked->noop('record_info');
    my $bmwqemu_mocked = Test::MockModule->new('bmwqemu');
    $bmwqemu_mocked->noop('save_vars');
    for my $case (['ttyS2', 'ttyS2'], ['sshserial', 'ttyS1'], ['virtsshserial', 'ttyS1']) {
        my ($serialdev, $expected) = @$case;
        set_var('SERIALCONSOLE', undef);
        set_var('SERIALDEV', $serialdev);
        Utils::Backends::save_serial_console();
        is get_var('SERIALCONSOLE'), $expected, "SERIALCONSOLE is $expected for SERIALDEV $serialdev";
    }
    set_var($_, undef) for qw(SERIALCONSOLE SERIALDEV);
};

done_testing;
