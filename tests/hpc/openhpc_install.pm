# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Going through openhpc install guide
#    Trying to mimic behavior described at
#    https://github.com/openhpc/ohpc/releases/download/v1.2.GA/Install_guide-SLE_12_SP1-PBSPro-1.2-x86_64.pdf
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, soulofdestiny <mgriessmeier@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub run() {
    assert_script_run('systemctl stop SuSEfirewall2');
    zypper_call('install -t pattern ohpc-base ohpc-warewulf');
    zypper_call('install pbspro-server-ohpc');
}

1;
# vim: set sw=4 et:
