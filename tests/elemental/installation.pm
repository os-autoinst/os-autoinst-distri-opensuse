# Copyright 2023-2024 SUSE LLC
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
use Utils::Architectures;

sub run {
    my ($self) = @_;
    my $cloudconfig = "/tmp/cloud-config.yaml";
    my %boot_entries = (
        active => {
            tag => 'elemental-bootmenu-default'
        },
        recovery => {
            tag => 'elemental-bootmenu-recovery'
        }
    );

    # Wait for boot
    # Bypass Grub on aarch64 as it can take too long to match the first grub2 needle
    if (is_aarch64) {
        $self->wait_boot_past_bootloader(textmode => 1);
    } else {
        $self->wait_boot(textmode => 1);
    }

    ## No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Stop the installation service, to avoid issue with mnanual Elemental deployment
    assert_script_run('systemctl stop elemental-register-install.service');

    # Add a simple cloud-config
    my $rootpwd = script_output('openssl passwd -6 ' . get_var('TEST_PASSWORD'));
    assert_script_run('curl ' . data_url('elemental/cloud-config.yaml') . ' -o ' . $cloudconfig);
    file_content_replace($cloudconfig, '%TEST_PASSWORD%' => $rootpwd);

    # Install Elemental OS on HDD
    assert_script_run('elemental install /dev/vda --debug --cloud-init ' . $cloudconfig);

    # Loop on all entries to test them
    my @loop_count;
    foreach my $boot_entry (keys %boot_entries) {
        my $state = $boot_entries{$boot_entry};
        my $state_file = "/run/cos/${boot_entry}_mode";

        # Incrememnt the loop counter
        push @loop_count, $_;

        # Reboot to test the Grub entry
        power_action('reboot', keepconsole => 1, textmode => 1);

        # Use new root password after the first reboot (so after OS installation)
        $testapi::password = get_var('TEST_PASSWORD') if @loop_count == 1;

        # Select SUT for bootloader
        select_console('sut');

        # Wait for GRUB
        $self->wait_grub();

        # Choose entry to test
        send_key_until_needlematch($state->{tag}, 'down');
        send_key('ret', wait_screen_change => 1);
        wait_still_screen(timeout => 120);
        save_screenshot();

        # No GUI, easier and quicker to use the serial console
        select_serial_terminal();

        # Check that we are booted in the correct entry
        # NOTE: Shell and Perl return codes are inverted!
        if (!script_run("[[ -f ${state_file} ]]")) {
            record_info("$boot_entry detected!", "$state_file has been detected!");
        } else {
            die("Not booted in $boot_entry!");
        }

        # Check the installed OS
        assert_script_run('cat /etc/os-release');

        # Record boot
        record_info('OS boot', "$boot_entry: successfully tested!");
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
