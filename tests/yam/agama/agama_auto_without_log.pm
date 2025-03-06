## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Wait for unattended installation to finish,
# Reboot and reach login prompt.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;

use testapi;

sub run {
    my $self = shift;
    my $reboot_page = $testapi::distri->get_reboot();
    $reboot_page->expect_is_shown();
    # It does not work when using select_console('root-console') or selcect_console('install-console') on hyperv platform
    # Will add it if it works in future
    # $self->upload_agama_logs();
    $reboot_page->reboot();
}

1;
