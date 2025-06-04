## Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: base class for Patch Agama tests
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::patch_agama_base;
use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use y2_base 'save_upload_y2logs';
use Utils::Architectures qw(is_s390x);
use Utils::Backends qw(is_svirt);

sub post_fail_hook {
    my ($self) = @_;
    select_console 'agama-console' unless is_s390x() && is_svirt();
    y2_base::save_upload_y2logs($self, skip_logs_investigation => 1);
}

1;
