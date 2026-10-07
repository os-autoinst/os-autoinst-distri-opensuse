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
# DEFAULT_PASSWORD - password for root, the first user and disk encryption,
#   default: $testapi::password
# USERNAME - login name of the first user, default: bernhard
#   ($testapi::username). The installer default is sysadmin, so the name is
#   replaced. The later modules, like console/consoletest_setup, need this user.
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
use serial_terminal 'select_serial_terminal';
use utils 'is_uefi_boot';
use Utils::Architectures 'is_aarch64';
use security::sle16cc qw(fill_screen unlock_and_login_cc_system);

use constant DEFAULT_TIMEOUT => 300;
use constant INSTALLATION_TIMEOUT => 3600;
# Wait for a screen and accept it with the default values.
sub accept_screen {
    my ($tag, $timeout) = @_;
    assert_screen $tag, $timeout // DEFAULT_TIMEOUT;
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

# Wait for a screen, replace the default text of the input field with a text
# and confirm it. The installer prefills the field, and typing appends to it.
sub replace_screen {
    my ($tag, $text) = @_;
    assert_screen $tag, DEFAULT_TIMEOUT;
    send_key 'backspace' for 1 .. 30;
    type_string $text;
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
    my $user = get_var('USERNAME', $testapi::username);

    select_cc_grub_entry();
    accept_screen 'sle16-cc-fips-installation';
    accept_screen 'sle16-cc-license-agreement';

    fill_screen 'sle16-cc-root-password', $password;
    fill_screen 'sle16-cc-root-password-confirmation', $password;

    # Replace the default user name (sysadmin) and keep the full name (System Administrator)
    replace_screen 'sle16-cc-first-user-name', $user;
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
    unlock_and_login_cc_system($user, $password);

    # The first user cannot write to the serial device, so run the check as root
    select_serial_terminal;
    assert_script_run("id $user");
    check_os_release();
    # The system stays running, poweroff is called in the schedule
}

1;
