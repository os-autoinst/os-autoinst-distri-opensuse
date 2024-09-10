# oSUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Installation of Leap or Tumbleweed with Agama
# https://github.com/openSUSE/agama/

# Exepcted to be executed right after agama.pm
# This test handles actions that happen once we see the reboot button after install
# 1) Switch from installer to console to Upload logs
# 2) Switch back to X11/Wayland and reset_console s
#    so newly booted system does not think that we're still logged in console
# 3) workaround for no ability to disable grub timeout in agama 
#    https://github.com/openSUSE/agama/issues/1594
#    grub_test() is too slow to catch boot screen for us
# Maintainer: Lubos Kocman <lubos.kocman@suse.com>,

use strict;
use warnings;
use base "installbasetest";
use testapi;
use version_utils qw(is_leap is_sle);
use utils;
use Utils::Logging qw(export_healthcheck_basic);
use x11utils 'ensure_unlocked_desktop';

sub upload_agama_logs {
    return if (get_var('NOLOGS'));
    select_console("root-console");
    # stores logs in /tmp/agma-logs.tar.gz
    script_run('agama logs store');
    upload_logs('/tmp/agama-logs.tar.gz');
}

sub get_agama_install_console_tty {
    # get_x11_console_tty would otherwise autodetermine 2
    return 7;
}

sub run {
    my ($self) = @_;
  
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
    send_key_until_needlematch("bootloader-grub2", 'spc', 50, 3);

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
