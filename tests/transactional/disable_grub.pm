# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Disable Grub timeout by transactional update
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use transactional qw(process_reboot);

sub run {
    select_console 'root-console';
    assert_script_run("sed -i 's/GRUB_TIMEOUT=10/GRUB_TIMEOUT=-1/' /etc/default/grub");
    assert_script_run('transactional-update grub.cfg');
    process_reboot(trigger => 1);
}

sub test_flags {
    return {no_rollback => 1};
}

1;
