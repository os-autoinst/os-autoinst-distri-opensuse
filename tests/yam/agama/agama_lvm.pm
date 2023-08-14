## Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run interactive installation use lvm with Agama,
# run playwright tests directly from the Live ISO.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::agama::agama_base;
use strict;
use warnings;

use testapi qw(
  assert_screen
  assert_script_run
  enter_cmd
  get_required_var
  reset_consoles
  select_console
  upload_logs
);
use power_action_utils 'power_action';
use transactional 'process_reboot';

sub run {
    my $product_name = get_required_var('AGAMA_PRODUCT');
    assert_screen('agama-main-page', 120);
    $testapi::password = 'linux';
    select_console 'root-console';

    assert_script_run("RUN_INSTALLATION=1 PRODUCTNAME=\"$product_name\" playwright test --trace on --project chromium --config /usr/share/e2e-agama-playwright tests/lvm.spec.ts", timeout => 1200);
    upload_logs('./test-results/lvm-The-main-page-Use-logical-volume-management-LVM-as-storage-device-for-installation-chromium/trace.zip');

    enter_cmd "reboot";
    # For agama test, it is too short time to match the grub2, so we create
    # a new needle to avoid too much needles loaded.
    assert_screen('grub2-agama', 120);
    my @tags = ("welcome-to", "login");
    assert_screen(\@tags, 300);
    reset_consoles;
}

sub post_fail_hook {
    upload_logs('./test-results/lvm-The-main-page-Use-logical-volume-management-LVM-as-storage-device-for-installation-chromium/trace.zip');
}
1;
