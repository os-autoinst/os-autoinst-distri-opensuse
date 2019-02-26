# SUSE's openssh tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add openssh test cases for FIPS testing
#    Test Case 1525228: FIPS: openssh
#
#    Involve the existing openssh test case: sshd.pm
#
#    Create new case ssh_pubkey.pm to test public key
#
#    Create new case openssh_fips.pm to verify that
#    openssh will refuse to work with any non-approved
#    algorithm in fips mode, just like blowfish cipher
#    or MD5 hash.
# Maintainer: Qingming Su <qingming.su@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;

# check if sshd works with public key
sub run {
    select_console 'user-console';

    # Assume user "sshboy" has been created in sshd.pm test script
    my $ssh_testman        = "sshboy";
    my $ssh_testman_passwd = "let3me2in1";

    # Remove existing public keys and create new one
    script_run("rm -f ~/.ssh/id_*; ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ''", 0);
    assert_screen "ssh-keygen-ok", 60;

    # Copy public key to target user's ~/.ssh/authorized_keys
    script_run("ssh-keygen -R localhost; ssh-copy-id -i ~/.ssh/id_rsa.pub $ssh_testman\@localhost", 0);
    assert_screen "ssh-login", 60;
    type_string "yes\n";
    assert_screen 'password-prompt';
    type_string "$ssh_testman_passwd\n";

    # Verify ssh without password
    script_run("ssh -v $ssh_testman\@localhost -t echo LOGIN_SUCCESSFUL", 0);
    assert_screen "ssh-login-ok";
}

1;
