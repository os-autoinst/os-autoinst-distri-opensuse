# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add ssh key dialog test
#    https://progress.opensuse.org/issues/11454 https://github.com/yast/skelcd-control-SLES/blob/d2f9a79c0681806bf02eb38c4b7c287b9d9434eb/control/control.SLES.xml#L53-L71
# G-Maintainer: Jozef Pupava <jpupava@suse.com>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    send_key_until_needlematch 'ssh-key-import-selected', 'tab';
    send_key 'ret';
    assert_screen "inst-import-ssh-key";
    if (get_var('SSH_KEY_IMPORT')) {
        send_key 'alt-i';    # select import ssh configuration
        assert_screen "inst-import-ssh-and-configuration-selected";
    }
    elsif (get_var('SSH_KEY_DO_NOT_IMPORT')) {
        send_key 'alt-w';    # unselect import ssh key checkbox
        assert_screen "inst-import-ssh-and-configuration-unselected";
    }
    send_key 'alt-a';        # accept
}

1;
# vim: set sw=4 et:
