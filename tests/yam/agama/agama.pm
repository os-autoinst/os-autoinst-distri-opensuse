## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run interactive installation with Agama,
# using a web automation tool to test directly from the Live ISO.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;
use testapi;

use testapi qw(
  assert_script_run
  get_required_var
);

sub run {
    my $self = shift;
    my $test = get_required_var('AGAMA_TEST');

    script_run("dmesg --console-off");
    assert_script_run("/usr/share/agama/system-tests/" . $test . ".cjs", timeout => 1200);
    script_run("dmesg --console-on");

    my $reboot_page = $testapi::distri->get_reboot_page();
    $reboot_page->expect_is_shown();
    $reboot_page->reboot();
}

sub post_run_hook {
    my ($self) = shift;
    $self->SUPER::post_run_hook;
}

1;
