## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Wait for unattended installation to finish,
# reboot and reach login prompt.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'Yam::Agama::agama_base';

use testapi;
use Utils::Architectures qw(is_s390x is_ppc64le);
use Utils::Backends qw(is_pvm is_svirt is_hyperv);
use power_action_utils qw(power_action);
use version_utils qw(is_vmware is_leap);

sub run {
    my $self = shift;
    select_console 'installation';
    my $reboot_page = $testapi::distri->get_reboot();

    if (check_var('INST_FINISH', 'reboot') || check_var('INST_FINISH_DISABLED', '1')) {
        $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
        return;
    }
    elsif (check_var('INST_FINISH', 'poweroff')) {
        assert_shutdown(300);
        power_action('reboot', keepconsole => 1, textmode => 1);
        return;
    }
    $reboot_page->expect_is_shown();

    $self->upload_agama_logs() unless is_hyperv();

    (is_s390x() || (is_ppc64le() && check_var("DESKTOP", "textmode")) || is_pvm() || is_vmware()) ?
      # reboot via console
      power_action('reboot', keepconsole => 1, first_reboot => 1) :
      # graphical reboot
      $reboot_page->reboot();
}

1;
