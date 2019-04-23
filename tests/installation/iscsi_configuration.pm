# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configuration of iSCSI installation
#    check if iBFT is present
#    select iSCSI disk to install system on
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    assert_screen 'disk-activation-iscsi';
    send_key 'alt-i';    # configure iscsi disk
    assert_screen 'iscsi-overview', 100;
    send_key 'alt-i';    # iBFT tab
    assert_screen 'iscsi-ibft';
    send_key 'alt-o';    # OK
    assert_screen 'disk-activation-iscsi';
    send_key $cmd{next};
}

1;
