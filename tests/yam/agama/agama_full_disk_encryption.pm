## Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run interactive installation with Agama,
# run playwright tests directly from the Live ISO.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;

use testapi qw(
  assert_screen
  assert_script_run
  select_console
  upload_logs
);
use power_action_utils 'power_action';
use transactional 'process_reboot';

sub run {
    assert_screen('agama_product_selection', 120);
    $testapi::password = 'linux';
    select_console 'root-console';

    assert_script_run('playwright test --trace on --project chromium --config /usr/share/e2e-agama-playwright full-disk-encryption', timeout => 600);

    $testapi::password = 'nots3cr3t';
    assert_script_run('reboot');
}

1;
