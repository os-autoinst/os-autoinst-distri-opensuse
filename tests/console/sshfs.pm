# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: sshfs rpm diffutils
# Summary: Mount and access a directory using sshfs; Test file listing is
#   correct as well as that rpm/zypper can work when called from a remotely
#   mounted directory.
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my $self = shift;
    select_serial_terminal;

    zypper_call('in sshfs');
    script_run('cd /var/tmp ; mkdir mnt ; sshfs localhost:/ mnt', 0);
    assert_script_run('zypper -n in xdelta3', fail_message => 'rpm/zypper calls statfs and might stumble over fuse fs');
    assert_script_run('rpm -e xdelta3');
    assert_script_run('diff <(ls mnt) <(ls /)', fail_message => 'Listings should be the same from real and mounted root');
    script_run('cd -');

    # we need to umount that otherwise root is considered logged in!
    assert_script_run('umount /var/tmp/mnt');
}

1;
