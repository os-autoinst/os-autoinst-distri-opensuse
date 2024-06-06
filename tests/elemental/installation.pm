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
use version_utils qw(is_sle_micro);
use Utils::Architectures;

=head2 get_filename

 get_filename(file => '/path/to/file');

Extract the filename from F</path/to/file> and return it.

=cut

sub get_filename {
    my %args = @_;

    my @spl = split('/', $args{file});

    return $spl[$#spl];
}

sub run {
    my ($self) = @_;
    my @config_files = ('/oem/install.yaml', '/tmp/cloud-config.yaml');
    my $grub_env_path = is_sle_micro('<6.0') ? '/run/cos/state' : '/run/elemental/efi';
    my $hook = is_sle_micro('<6.0') ? 'after-install' : 'after-install-chroot';
    my %boot_entries = (
        active => {
            tag => 'elemental-bootmenu-default'
        },
        passive => {
            tag => 'elemental-bootmenu-passive'
        },
        recovery => {
            tag => 'elemental-bootmenu-recovery'
        }
    );

    # Wait for boot
    # Bypass Grub on aarch64 as it can take too long to match the first grub2 needle
    if (is_aarch64) {
        $self->wait_boot_past_bootloader(textmode => 1);
        sleep bmwqemu::scale_timeout(30);
    } else {
        $self->wait_boot(textmode => 1);
    }

    # We have to use this dirty workaround for older images...
    sleep bmwqemu::scale_timeout(20) if (is_sle_micro('<6.0'));

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Stop the installation service, to avoid issue with manual Elemental deployment
    assert_script_run('systemctl stop elemental-register-install.service');

    # Encode root password
    my $rootpwd = script_output('openssl passwd -6 ' . get_var('TEST_PASSWORD'));

    # Add configuration files
    foreach my $config_file (@config_files) {
        assert_script_run('curl ' . data_url('elemental/' . get_filename(file => $config_file)) . ' -o ' . $config_file);
        file_content_replace($config_file, '%TEST_PASSWORD%' => $rootpwd);
        file_content_replace($config_file, '%PATH%' => $grub_env_path);
    }

    # Install Elemental OS on HDD
    assert_script_run('elemental install /dev/vda --debug --cloud-init /tmp/*.yaml');

    # Loop on all entries to test them
    foreach my $boot_entry (keys %boot_entries) {
        # Fallback/passive Grub entry doesn't exist anymore in newer version
        next if (is_sle_micro('>=6.0') && $boot_entry eq 'passive');

        # Variables
        my $state = $boot_entries{$boot_entry};
        my $state_file = "/run/cos/${boot_entry}_mode";

        # Reboot to test the Grub entry
        power_action('reboot', keepconsole => 1, textmode => 1);

        # Force the use of new root password
        $testapi::password = get_var('TEST_PASSWORD');

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
