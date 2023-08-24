## Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run interactive installation with Agama,
# run playwright tests directly from the Live ISO.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::agama::agama_base;
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
    assert_screen('agama-main-page', 120);
    $testapi::password = 'linux';
    select_console 'root-console';

    assert_script_run('RUN_INSTALLATION=1 playwright test --trace on --project chromium --config /usr/share/e2e-agama-playwright default_installation', timeout => 600);

    assert_script_run('reboot');
    # For agama test, it is too short time to match the grub2, so we create
    # a new needle to avoid too much needles loaded.
    assert_screen('grub2-agama', 120);
    my @tags = ("welcome-to", "login");
    assert_screen(\@tags, 300);
}

sub post_fail_hook {
    upload_logs('./test-results/default_installation-The-main-page-Default-installation-test-chromium/trace.zip');
}

1;
