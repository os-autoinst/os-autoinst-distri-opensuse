# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add ssh key dialog test
#    https://progress.opensuse.org/issues/11454 https://github.com/yast/skelcd-control-SLES/blob/d2f9a79c0681806bf02eb38c4b7c287b9d9434eb/control/control.SLES.xml#L53-L71
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    send_key_until_needlematch 'ssh-key-import-selected', 'tab', 31, 1;
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
    send_key 'alt-a';    # accept
}

1;
