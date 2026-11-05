# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the installed system has a NVIDIA-specific kernel.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use Test::Assert 'assert_matches';

sub run {
    select_console 'root-console';

    assert_matches(qr/^.+-nvidia64kb$/, script_output('uname -r'), "The installed system doesn't have a NVIDIA-specific kernel");
}

1;
