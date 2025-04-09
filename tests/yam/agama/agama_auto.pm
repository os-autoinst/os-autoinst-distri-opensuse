## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Wait for unattended installation to finish,
# reboot and reach login prompt.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;

use testapi;
use Utils::Architectures qw(is_s390x is_ppc64le);
use Utils::Backends qw(is_svirt is_hyperv);
use power_action_utils 'power_action';
use version_utils qw(is_vmware);

sub run {
    my $self = shift;
    my $reboot_page = $testapi::distri->get_reboot();

    $reboot_page->expect_is_shown();
    $self->upload_agama_logs() unless is_hyperv();

    (is_s390x() || is_ppc64le() || is_vmware()) ?
      # reboot via console
      power_action('reboot', keepconsole => 1, first_reboot => 1) :
      # graphical reboot
      $reboot_page->reboot();
}

1;
