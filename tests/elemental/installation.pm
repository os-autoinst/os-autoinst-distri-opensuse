# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test boot of Elemental OS
# Maintainer: elemental@suse.de

use base 'opensusebasetest';
use strict;
use warnings;

use testapi;
use power_action_utils qw(power_action);
use serial_terminal qw(select_serial_terminal);
use utils qw(file_content_replace);

sub run {
    my ($self) = @_;
    my $cloudconfig = "/tmp/cloud-config.yaml";
    my %boot_entries = (
        active => {
            tag => 'elemental-bootmenu-default'
        },
        passive => {
            tag => 'elemental-bootmenu-fallback'
        },
        recovery => {
            tag => 'elemental-bootmenu-recovery'
        }
    );


    # Wait for GRUB
    $self->wait_grub(bootloader_time => 120);
    send_key('ret', wait_screen_change => 1);
    wait_still_screen(timeout => 90);
    save_screenshot();

    ## No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Add a simple cloud-config
    my $rootpwd = script_output('openssl passwd -6 ' . get_var('TEST_PASSWORD'));
    assert_script_run('curl ' . data_url('elemental/cloud-config.yaml') . ' -o ' . $cloudconfig);
    file_content_replace($cloudconfig, '%TEST_PASSWORD%' => $rootpwd);

    # Install Elemental OS on HDD
    assert_script_run('elemental install /dev/vda --cloud-init ' . $cloudconfig);

    # Reboot after installation
    power_action('reboot', keepconsole => 1, textmode => 1);

    # Use new root password
    $testapi::password = get_var('TEST_PASSWORD');

    # Loop on all entries to test them
    foreach my $boot_entry (keys %boot_entries) {
        my $state = $boot_entries{$boot_entry};
        my $state_file = "/run/cos/${boot_entry}_mode";

        # Select SUT for bootloader
        select_console('sut');

        # Wait for GRUB
        $self->wait_grub(bootloader_time => 120);

        # Choose entry to test
        send_key_until_needlematch($state->{tag}, 'down');
        send_key('ret', wait_screen_change => 1);
        wait_still_screen(timeout => 120);
        save_screenshot();

        # No GUI, easier and quicker to use the serial console
        select_serial_terminal();

        # Check that we are booted in the correct entry
        # NOTE: Shell and Perl return code are inverted!
        if (!script_run("[[ -f ${state_file} ]]")) {
            record_info("$boot_entry detected!", "$state_file has been detected!");
        } else {
            die("Not booted in $boot_entry!");
        }

        # Check the installed OS
        assert_script_run('cat /etc/os-release');

        # Reboot to test the next entry
        power_action('reboot', keepconsole => 1, textmode => 1);

        # Record boot
        record_info('OS boot', "$boot_entry: successfully tested!");
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
