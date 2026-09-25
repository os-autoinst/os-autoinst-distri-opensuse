# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: SLE 16 Common Criteria automated installation
# Maintainer: QE Security <none@suse.de>
#
# Settings:
#
# DESKTOP - textmode
# ENCRYPT - 1
# INSTALLONLY - 1
# SYSTEM_ROLE - Common_Criteria
# DEFAULT_PASSWORD - password for root, sysadmin and disk encryption,
#   default: $testapi::password
# SCC_REGCODE - registration code
# QEMUCPU - host
# GRUB_LINUX_LINE_DOWN - aarch64 only. Lines to move down from the first
#   line of the grub entry
#   editor to reach the linux line, default: 4
# PUBLISH_HDD_1 - name of the qcow2 image to save after the installation
# PUBLISH_PFLASH_VARS - for UEFI.
#
# Set all settings in the job group, test suite or command line. The YAML
# schedule does not set them, because the openQA server and the backend need
# them before the test module runs.

use Mojo::Base 'installbasetest';
use testapi;
use power_action_utils 'power_action';
use serial_terminal 'select_serial_terminal';
use utils 'is_uefi_boot';
use Utils::Architectures 'is_aarch64';

use constant DEFAULT_TIMEOUT => 300;
use constant INSTALLATION_TIMEOUT => 3600;
# Wait for a screen and accept it with the default values.
sub accept_screen {
    my ($tag, $timeout) = @_;
    assert_screen $tag, $timeout // DEFAULT_TIMEOUT;
    send_key 'ret';
}

# Wait for a screen, type a text in the input field and confirm it.
sub fill_screen {
    my ($tag, $text) = @_;
    assert_screen $tag, DEFAULT_TIMEOUT;
    type_string $text;
    send_key 'ret';
}

# On aarch64 the kernel uses the serial port as the default console, so the
# installer is not shown on the screen. Add tty0 as the last console to the
# kernel command line in the grub editor. The editor has no search. The cursor
# starts on the first line, and the entry has these lines:
#   1 setparams, 2 empty, 3 set gfxpayload, 4 echo kernel, 5 linux,
#   6 echo initrd, 7 initrd
sub add_tty_console_to_grub_entry {
    my $lines_down = get_var('GRUB_LINUX_LINE_DOWN', 4);
    send_key 'e';
    wait_still_screen 2;
    send_key 'down' for 1 .. $lines_down;
    send_key 'end';
    type_string ' console=ttyAMA0 console=tty0';
    # Show the result of the edit in the test results
    wait_still_screen 2;
    save_screenshot;
    send_key 'ctrl-x';
}

# The BIOS menu has the extra first entry "Boot from Hard Disk", the UEFI menu
# has not. Therefore the CC entry is the 3rd entry on BIOS and the 2nd on UEFI.
# The next screen check fails, if a wrong entry is selected.
sub select_cc_grub_entry {
    assert_screen 'sle16-cc-grub-menu', 60;
    send_key 'down' for 1 .. (is_uefi_boot() ? 1 : 2);
    if (is_aarch64()) {
        record_info('aarch64 boot', 'Adding the tty0 console to the kernel command line');
        add_tty_console_to_grub_entry();
    }
    else {
        send_key 'ret';
    }
}

sub login_as_sysadmin {
    my ($password) = @_;
    assert_screen 'sle16-cc-login-prompt', DEFAULT_TIMEOUT;
    type_string 'sysadmin';
    send_key 'ret';
    assert_screen 'sle16-cc-password-prompt';
    type_string $password;
    send_key 'ret';
}

# Verify that the installed system is SLES 16.0
sub check_os_release {
    my $os_release = script_output 'cat /etc/os-release';
    my %expected = (
        NAME => 'SLES',
        PRETTY_NAME => 'SUSE Linux Enterprise Server 16.0',
    );
    for my $key (sort keys %expected) {
        # Values in /etc/os-release can be quoted
        my ($value) = $os_release =~ /^$key=["']?([^"'\n]*)["']?\s*$/m;
        die "$key is missing in /etc/os-release" unless defined $value;
        die "Unexpected $key in /etc/os-release: got '$value', expected '$expected{$key}'"
          unless $value eq $expected{$key};
    }
}

sub run {
    my $password = get_var('DEFAULT_PASSWORD', $testapi::password);

    select_cc_grub_entry();
    accept_screen 'sle16-cc-fips-installation';
    accept_screen 'sle16-cc-license-agreement';

    fill_screen 'sle16-cc-root-password', $password;
    fill_screen 'sle16-cc-root-password-confirmation', $password;

    # Keep the default user name (sysadmin) and full name (System Administrator)
    accept_screen 'sle16-cc-first-user-name';
    accept_screen 'sle16-cc-first-user-fullname';
    fill_screen 'sle16-cc-first-user-password', $password;
    fill_screen 'sle16-cc-first-user-password-confirmation', $password;

    fill_screen 'sle16-cc-disk-encryption', $password;
    fill_screen 'sle16-cc-disk-encryption-confirmation', $password;

    # Leave the NTP server and the registration e-mail blank
    accept_screen 'sle16-cc-ntp-server';
    fill_screen 'sle16-cc-registration-code', get_var('SCC_REGCODE');
    accept_screen 'sle16-cc-registration-email';

    # Load the configuration and start the installation
    accept_screen 'sle16-cc-configuration-summary';
    assert_screen 'sle16-cc-initializing', DEFAULT_TIMEOUT;
    accept_screen 'sle16-cc-storage-proposal';
    accept_screen 'sle16-cc-installation-finished', INSTALLATION_TIMEOUT;

    # The system reboots
    # The prompt looks different on UEFI, where tianocore shows it
    if (is_uefi_boot()) {
        record_info('UEFI boot', 'Using the tianocore disk encryption prompt');
        fill_screen 'sle16-cc-disk-encryption-prompt-tianocore', $password;
    }
    else {
        record_info('BIOS boot', 'Using the BIOS disk encryption prompt');
        fill_screen 'sle16-cc-disk-encryption-prompt', $password;
    }
    # The installed system may boot without showing the grub menu. Wait for the
    # menu or for the login prompt, and select the default entry only if the
    # menu is shown.
    assert_screen [qw(sle16-cc-grub-menu-installed sle16-cc-login-prompt)], DEFAULT_TIMEOUT;
    if (match_has_tag 'sle16-cc-grub-menu-installed') {
        record_info('Grub menu', 'The grub menu is shown, selecting the default entry');
        send_key 'ret';
    }
    else {
        record_info('No grub menu', 'The system boots without showing the grub menu');
    }
    login_as_sysadmin($password);

    wait_still_screen 2;
    # The sysadmin user cannot write to the serial device, so run the check as root
    select_serial_terminal;
    check_os_release();
    # A clean power off is required to save the disk image. os-autoinst publishes
    # the qcow2 image after the VM stops, if the setting PUBLISH_HDD_1 is set.
    power_action('poweroff', textmode => 1);
}

1;
