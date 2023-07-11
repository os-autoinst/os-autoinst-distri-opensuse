## Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: base class for Patch Agama tests
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::agama::patch_agama_base;
use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use y2_base 'save_upload_y2logs';

sub pre_run_hook {
    $testapi::password = 'linux';
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    y2_base::save_upload_y2logs($self, skip_logs_investigation => 1);
}

1;
