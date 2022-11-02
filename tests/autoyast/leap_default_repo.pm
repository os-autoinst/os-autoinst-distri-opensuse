# Copyright 2015-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Use default repositories which copied from installed system via interactive installation
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#116006

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils qw(quit_packagekit zypper_call);

sub run {
    select_console 'root-console';
    quit_packagekit;
    assert_script_run 'cd /etc/zypp/repos.d; rm -rf *';
    assert_script_run 'wget --quiet ' . data_url('leap_repo/leap_repo.tar');
    assert_script_run 'tar xf leap_repo.tar; rm -f leap_repo.tar; cd';
    zypper_call 'ref';
}

1;
