# oSUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Installation of Sle/Leap or Tumbleweed with Agama
# https://github.com/openSUSE/agama/

# Exepcted to be executed right after agama.pm or agama auto install
# This test handles actions that happen once we see the reboot button after install
# 1) Switch from installer to console to Upload logs
# 2) Switch back to X11/Wayland and reset_consoles
#    so newly booted system does not think that we're still logged in console
# 3) workaround for no ability to disable grub timeout in agama
#    https://github.com/openSUSE/agama/issues/1594
#    grub_test() is too slow to catch boot screen for us
# 4) for ipmi/pvm/s390x backend, vnc access during the installation is not available now,
#    we need to access to live root system to monitor installation process
# Maintainer: Lubos Kocman <lubos.kocman@suse.com>,

use base "installbasetest";
use testapi;
use version_utils qw(is_leap is_sle);
use utils;
use Utils::Logging qw(export_healthcheck_basic);
use x11utils 'ensure_unlocked_desktop';
use Utils::Backends qw(is_ipmi is_pvm is_svirt);
use Utils::Architectures qw(is_aarch64 is_s390x);
use power_action_utils 'assert_shutdown_and_restore_system';

sub upload_agama_logs {
    return if (get_var('NOLOGS'));
    select_console("install-shell");
    script_run('agama logs store -d /tmp');
    script_run('agama config show > /tmp/agama_config.txt');
    upload_logs('/tmp/agama-logs.tar.gz');
    upload_logs('/tmp/agama_config.txt');
}

sub verify_agama_auto_install_done_cmdline {
    # for some remote workers, there is no vnc access to the install console,
    # so we need to make sure the installation has completed from command line.
    my $timeout = get_var('AGAMA_INSTALL_TIMEOUT', '480');
    while ($timeout > 0) {
        if (script_run("journalctl -u agama | grep 'Install phase done'") == 0) {
            record_info("agama install phase done");
            return;
        }
        sleep 20;
        $timeout = $timeout - 20;
    }
    # Add some debug info for quick check for tester before investigating full agama logs
    # See https://progress.opensuse.org/issues/182258
    record_info('debug info', script_output('journalctl --no-pager -u agama -n 100'));
    die "Install phase is not done, please check agama logs";
}

sub run {
    my ($self) = @_;

    if ((is_ipmi || is_pvm || is_s390x) && get_var('INST_AUTO')) {
        select_console('install-shell');
        record_info 'Wait for installation phase done';
        verify_agama_auto_install_done_cmdline();
        upload_agama_logs();
        record_info 'Reboot system to disk boot';
        enter_cmd 'reboot';
        # Swith back to sol console, then user can monitor the boot log
        select_console 'sol', await_console => 0 if is_ipmi;
        reconnect_mgmt_console if is_pvm;
        if (is_s390x && is_svirt) {
            assert_shutdown_and_restore_system;
            reconnect_mgmt_console;
        }
        wait_still_screen 10;
        save_screenshot;
        return;
    }

    assert_screen('agama-congratulations');
    upload_agama_logs();
    select_console('installation', await_console => 0);
    # make sure newly booted system does not expect we're still logged in console
    reset_consoles();
    assert_and_click('agama-reboot-after-install');

}

=head2 post_fail_hook

 post_fail_hook();

When the test module fails, this method will be called.
It will try to fetch logs from agama.

=cut

sub post_fail_hook {
    my ($self) = @_;

    return if (get_var('NOLOGS'));

    select_console("install-shell");
    export_healthcheck_basic();
    upload_agama_logs();
}


1;
