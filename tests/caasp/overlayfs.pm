# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that overlayfs does not mask system files
# Maintainer: Martin Kravec <mkravec@suse.com>
# Tags: poo#17848

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use caasp 'process_reboot';

sub run() {
    assert_script_run "grep 'passwd:.*usrfiles' /etc/nsswitch.conf";

    record_info 'Setup';
    script_run 'transactional-update shell', 0;
    script_run "echo 'ovug:x:1111:1111::/home/ovug:/bin/bash' >> /usr/etc/passwd";
    script_run "echo 'ovug:!:1111:' >> /usr/etc/group";
    send_key 'ctrl-d';
    process_reboot 1;

    record_info 'Check';
    assert_script_run "id ovug";
    assert_script_run "getent passwd ovug";
    assert_script_run "getent group ovug";
}

1;
