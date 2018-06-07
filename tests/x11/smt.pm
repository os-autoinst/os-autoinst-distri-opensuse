# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add smt configuration test
#    test installation and upgrade with smt pattern, basic configuration via
#    smt-wizard and validation with smt-repos smt-sync return value
# Maintainer: Jozef Pupava <jpupava@suse.com>, Jiawei Sun <jwsun@suse.com>, Dehai Kong <dhkong@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use repo_tools;

sub run {
    x11_start_program('xterm -geometry 150x35+5+5', target_match => 'xterm');
    become_root;
    smt_wizard();
    assert_script_run 'smt-sync', 800;
    assert_script_run 'smt-repos';

    # mirror and sync a base repo from SCC
    smt_mirror_repo();
    type_string "killall xterm\n";
}

sub test_flags {
    return {fatal => 1};
}

1;
