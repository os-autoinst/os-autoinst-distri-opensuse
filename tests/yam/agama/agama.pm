## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run interactive installation with Agama,
# using a web automation tool to test directly from the Live ISO.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use strict;
use warnings;

use testapi qw(
  get_required_var
  script_run
  assert_script_run
  record_soft_failure
);

sub run {
    my $self = shift;
    my $test = get_required_var('AGAMA_TEST');
    my $test_options = get_required_var('AGAMA_TEST_OPTIONS');
    my $reboot_page = $testapi::distri->get_reboot();

    script_run("dmesg --console-off");
    assert_script_run("node --enable-source-maps /usr/share/agama/system-tests/" . $test . ".js " .
          $test_options, timeout => 2400);
    script_run("dmesg --console-on");

    $self->upload_agama_logs();
    $reboot_page->reboot();
}

1;
