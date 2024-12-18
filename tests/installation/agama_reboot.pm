# oSUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Installation of Sle/Leap or Tumbleweed with Agama
# https://github.com/openSUSE/agama/

# Exepcted to be executed right after agama.pm or agama auto install
# This test handles actions that happen once we see the reboot button after install
# 1) Switch from installer to console to Upload logs
# 2) Switch back to X11/Wayland and reset_console s
#    so newly booted system does not think that we're still logged in console
# 3) workaround for no ability to disable grub timeout in agama
#    https://github.com/openSUSE/agama/issues/1594
#    grub_test() is too slow to catch boot screen for us
# 4) for ipmi backend, vnc access during the installation is not available now,
#    we need to access to live root system to monitor installation process
# Maintainer: Lubos Kocman <lubos.kocman@suse.com>,

use strict;
use warnings;
use base "installbasetest";
use testapi;
use version_utils qw(is_leap is_sle);
use utils;
use Utils::Logging qw(export_healthcheck_basic);
use x11utils 'ensure_unlocked_desktop';
use Utils::Backends qw(is_ipmi);
use Utils::Architectures qw(is_aarch64);

sub upload_agama_logs {
    return if (get_var('NOLOGS'));
    select_console("root-console");
    # stores logs in /tmp/agma-logs.tar.gz
    script_run('agama logs store -d /tmp');
    upload_logs('/tmp/agama-logs.tar.gz');
}

sub get_agama_install_console_tty {
    # get_x11_console_tty would otherwise autodetermine 2
    return 7;
}

sub verify_agama_auto_install_done_cmdline {
    # for some remote workers, there is no vnc access to the install console,
    # so we need to make sure the installation has completed from command line.
    my $timeout = 300;
    while ($timeout > 0) {
        if (script_run("journalctl -u agama | grep 'Install phase done'") == 0) {
            record_info("agama install phase done");
            return;
        }
        sleep 20;
        $timeout = $timeout - 20;
    }
    die "Install phase is not done, please check agama logs";
}

sub agama_system_prepare_ipmi {
    # Mount the root disk after installation, and do some prepare tasks:
    # Configure serial console, enable root ssh access, etc

    # Get the root disk name
    my $device = script_output qq(agama config show | grep -oP '(?<="disk": ")[^"]+');
    # Use partition prefix for nvme devices
    my $prefix = $device =~ /nvme/ ? "p" : "";
    my $root_partition_id = 2;
    my $root_partition = "${device}" . $prefix . $root_partition_id;
    record_info("Device information", "Device: ${device}\nRoot partition: ${root_partition}");
    assert_script_run("mount ${root_partition} /mnt");
    # Set correct serial console to be able to see login in first boot
    record_info("Set serial console");
    my $sol_console = (is_aarch64) ? get_var('SERIALCONSOLE', 'ttyAMA0') : get_var('SERIALCONSOLE', 'ttyS1');
    assert_script_run("sed -i 's/quiet/console=$sol_console,115200/g' /mnt/boot/grub2/grub.cfg");
    # Upload original grub configuration
    upload_logs("/mnt/etc/default/grub", failok => 1);
    upload_logs("/mnt/boot/grub2/grub.cfg", failok => 1);
    # Set permanent grub configuration
    assert_script_run("sed -i 's/quiet/console=$sol_console,115200/g' /mnt/etc/default/grub");
    # Enable root ssh access
    record_info("Enable root ssh login");
    assert_script_run("echo 'PermitRootLogin yes' > /mnt/etc/ssh/sshd_config.d/root.conf");
    assert_script_run("umount /mnt");
}

sub run {
    my ($self) = @_;

    if (is_ipmi && get_var('AGAMA_AUTO')) {
        select_console('root-console');
        record_info 'Wait for installation phase done';
        verify_agama_auto_install_done_cmdline();
        script_run('agama logs store -d /tmp');
        upload_logs('/tmp/agama-logs.tar.gz');
        record_info 'Prepare system before rebooting';
        agama_system_prepare_ipmi();
        record_info 'Reboot system to disk boot';
        enter_cmd 'reboot';
        # Swith back to sol console, then user can monitor the boot log
        select_console 'sol', await_console => 0;
        wait_still_screen 10;
        save_screenshot;
        return;
    }

    assert_screen('agama-congratulations');
    console('installation')->set_tty(get_agama_install_console_tty());
    upload_agama_logs();
    select_console('installation', await_console => 0);
    # make sure newly booted system does not expect we're still logged in console
    reset_consoles();
    assert_and_click('agama-reboot-after-install');

    # workaround for lack of disable bootloader timeout
    # https://github.com/openSUSE/agama/issues/1594
    # simply send space until we hit grub2
    send_key_until_needlematch("grub2", 'spc', 50, 3);

}

=head2 post_fail_hook

 post_fail_hook();

When the test module fails, this method will be called.
It will try to fetch logs from agama.

=cut

sub post_fail_hook {
    my ($self) = @_;

    return if (get_var('NOLOGS'));

    select_console("root-console");
    export_healthcheck_basic();
    upload_agama_logs();
}


1;
