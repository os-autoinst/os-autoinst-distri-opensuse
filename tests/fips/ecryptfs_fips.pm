# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: FIPS:ecryptfs
#    Check the ecryptfs-utils with fips enabled
#    Install the ecryptfs-utils and encrypt the directory.
#    Create a new encrypt file and try to write it.
#    Check the file after unmont the encrypt directory
# Tags: tc#1525215
# Maintainer: Jiawei Sun <JiaWei.Sun@suse.com>

use base "consoletest";
use strict;
use testapi;

sub run {
    select_console 'root-console';

    # install ecryptfs-utils
    assert_script_run("zypper -n in ecryptfs-utils");
    assert_script_run("rpm -q ecryptfs-utils");
    assert_script_run("modprobe ecryptfs");

    # mount ecryptfs
    assert_script_run("mkdir .private private");
    validate_script_output("echo -e \"1\n1\n\n\nyes\nno\n\"  | mount -t ecryptfs -o key=passphrase:passphrase_passwd=testpass ./.private ./private",
        sub { m/Mounted eCryptfs/ });

    # touch a new file and try to write with it
    # According to comment 12 of bsc#973318, ecryptfs expects a failure in fips mode
    assert_script_run("cd private && touch testfile ");
    validate_script_output("(echo hello > testfile) 2>&1 || true", sub { m/write error/ });
    validate_script_output("cat testfile 2>&1 || true",            sub { m/^$|No such file or directory/ });

    # unmount and check the encrypt file
    assert_script_run("cd .. && umount -l private");
    validate_script_output("ls private", sub { m/^(?!.*testfile)/ });
}

1;
# vim: set sw=4 et:
