# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check if mouse and keyboard work properly after boot
# This test verifies basic mouse and keyboard functionality in the VM during installation
# with agama by testing mouse movement, clicking, and keyboard input
# Maintainer: Nan Zhang <nan.zhang@suse.com>, qa-virt@suse.de

use Mojo::Base 'opensusebasetest';
use testapi;
use version_utils qw(is_vmware);

sub run {
    my $self = shift;

    record_info('Mouse & Keyboard Check', 'Starting mouse and keyboard functionality tests');

    my @agama_screens = qw(agama-product-selection agama-configuring-the-product agama-installing agama-sle-overview);
    assert_screen(\@agama_screens, 30);
    test_keyboard_input(\@agama_screens);

    my $on_product_selection = match_has_tag('agama-product-selection');
    if ($on_product_selection) {
        test_mouse_movement();
    } else {
        record_info('Mouse Test Failed', 'Not on agama-product-selection screen — no safe click target on current screen');
        die "Mouse test failed: not on expected screen for mouse interaction";
    }

    record_info('Test Complete', 'Mouse and keyboard tests passed successfully');
}

sub test_keyboard_input {
    my ($agama_screens) = @_;
    record_info('Keyboard Test', 'Testing keyboard input via focus movement');

    # Each tab must move focus highlight; assert_screen_change dies if it doesn't.
    for (1 .. 3) {
        assert_screen_change { send_key 'tab' };
        wait_still_screen(2);
        save_screenshot;
    }
    for (1 .. 3) {
        assert_screen_change { send_key 'shift-tab' };
        wait_still_screen(2);
        save_screenshot;
    }

    assert_screen($agama_screens, 10);
    record_info('Keyboard OK', 'Keyboard input verified via screen change');
}

sub test_mouse_movement {
    record_info('Mouse Test', 'Testing mouse via click on a known UI element');

    # Click a product radio button; verify its selected-state needle appears.
    # If the click never reaches the guest, assert_and_click or the post-click
    # assert_screen will fail loudly.
    assert_and_click('agama-product-selection-sle16', timeout => 10);
    assert_screen('agama-product-selection-sle16-selected', 10);

    record_info('Mouse OK', 'Mouse click verified via UI state change');
}

sub test_flags {
    return {fatal => 0};
}

sub post_fail_hook {
    my $self = shift;

    save_screenshot;

    # Upload system logs for debugging if test fails
    select_console 'install-shell';

    # Collect relevant logs
    script_run('dmesg > /tmp/dmesg.log');
    upload_logs('/tmp/dmesg.log', failok => 1);

    # Check for input device issues
    script_run('cat /proc/bus/input/devices > /tmp/input_devices.log');
    upload_logs('/tmp/input_devices.log', failok => 1);

    # VMware tools logs if applicable
    if (is_vmware) {
        upload_logs('/var/log/vmware-vmsvc.log', failok => 1);
        upload_logs('/var/log/vmware-vmtoolsd-root.log', failok => 1);
    }
}

1;
