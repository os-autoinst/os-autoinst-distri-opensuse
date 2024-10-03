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

    my @env_vars = ();
    push(@env_vars, "AGAMA_DASD=" . get_var('AGAMA_DASD')) if get_var('AGAMA_DASD');
    push(@env_vars, "AGAMA_PRODUCT=" . get_var('AGAMA_PRODUCT')) if get_var('AGAMA_PRODUCT');

    my $test = get_required_var('AGAMA_TEST');
    my $reboot_page = $testapi::distri->get_reboot();

    script_run("dmesg --console-off");
    assert_script_run(join(' ', @env_vars) . " /usr/share/agama/system-tests/" . $test . ".cjs", timeout => 1200);
    script_run("dmesg --console-on");

    Yam::Agama::agama_base::upload_agama_logs();
    Yam::Agama::agama_base::upload_system_logs();

    $reboot_page->reboot();
}

1;
