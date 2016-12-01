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
# Maintainer: asmorodskyi <asmorodskyi@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub run() {

    my $repo = get_required_var("OPENHPC_REPO");

    select_console('root-console');

    assert_script_run "zypper -n addrepo -f $repo openhpc";
    assert_script_run "zypper -n  --gpg-auto-import-keys ref";
    assert_script_run "systemctl disable SuSEfirewall2";
    assert_script_run "systemctl stop SuSEfirewall2";
    assert_script_run "zypper -n install -t pattern ohpc-base ohpc-warewulf";
    assert_script_run "zypper -n install pbspro-server-ohpc";
}

1;
