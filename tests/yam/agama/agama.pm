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

use Utils::Architectures;
use version_utils qw(is_sle);

sub pre_run_hook {
    if (is_sle() && (is_s390x() || is_ppc64le())) {
        record_soft_failure("bsc#1231421");
        assert_script_run("curl --insecure -o /tmp/ca-certificates-suse.rpm https://download.suse.de/browse/ibs/SUSE:/CA/SLE_15_SP7/noarch/ca-certificates-suse-1.0-150700.8.1.noarch.rpm");
        assert_script_run("zypper -n install /tmp/ca-certificates-suse.rpm");
        assert_script_run("systemctl restart agama");
    }
}

sub run {
    my $test = get_required_var('AGAMA_TEST');
    my $test_options = get_required_var('AGAMA_TEST_OPTIONS');
    my $reboot_page = $testapi::distri->get_reboot();

    script_run("dmesg --console-off");
    assert_script_run("node --enable-source-maps /usr/share/agama/system-tests/" . $test . ".js " .
          $test_options, timeout => 1200);
    script_run("dmesg --console-on");

    Yam::Agama::agama_base::upload_agama_logs();
    Yam::Agama::agama_base::upload_system_logs();

    $reboot_page->reboot();
}

1;
