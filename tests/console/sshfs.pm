# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Mount and access a directory using sshfs; Test file listing is
#   correct as well as that rpm/zypper can work when called from a remotely
#   mounted directory.
# Maintainer: Oliver Kurz (okurz@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call('in sshfs');
    prepare_ssh_localhost_key_login 'root';
    script_run('cd /var/tmp ; mkdir mnt ; sshfs localhost:/ mnt', 0);
    assert_screen 'accept-ssh-host-key';
    type_string "yes\n";    # trust ssh host key
    assert_screen 'sshfs-accepted';
    assert_script_run('zypper -n in xdelta3', fail_message => 'rpm/zypper calls statfs and might stumble over fuse fs');
    assert_script_run('rpm -e xdelta3');
    assert_script_run('diff <(ls mnt) <(ls /)', fail_message => 'Listings should be the same from real and mounted root');
    script_run('cd -');

    # we need to umount that otherwise root is considered logged in!
    assert_script_run('umount /var/tmp/mnt');
}

1;
