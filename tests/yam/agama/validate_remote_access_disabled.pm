## Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Validate feature restrict network access to the installer.
# integration test from GitHub.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'Yam::Agama::patch_agama_base';
use testapi;

sub run {
    select_console 'install-shell';

    die("Remote network hasn't been restricted") if (script_run("ss -tuln | grep -E '\[::1\]:80|443'") == 1);
}

1;
