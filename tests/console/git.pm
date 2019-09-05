# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case 1525281  - FIPS: git
# Summary: To check  whether can be successful via ssh or https protocol by using git
# - Create ssh key and copy to root
# - Create a test repo
# - Clone to a bare git repo
# - Clone repo via ssh
# - Push update via ssh
# - Git clone via https protocol
# - Clean up
# Maintainer: Dehai Kong <dhkong@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {

    my $username = $testapi::username;
    my $email    = "you\@example.com";
    select_console "root-console";

    prepare_ssh_localhost_key_login 'root';

    # Create a test repo
    zypper_call("in git-core");
    assert_script_run("mkdir -p repos/qa1;cd repos/qa1");
    assert_script_run("git init");
    assert_script_run("echo \"SUSE Test\" > README");
    assert_script_run("git config --global user.email \"$email\"");
    assert_script_run("git config --global user.name \"$username\"");
    assert_script_run("git add README;git commit -m \"Initial commit\"");

    # Clone to a bare git repo
    assert_script_run("cd ~/repos;git clone --bare qa1 qa0");

    # Clone repo via ssh
    type_string("clear\n");
    script_run("git clone ssh://localhost:/root/repos/qa0 qa2 | tee /dev/$serialdev", 0);
    assert_screen("input-yes");
    type_string("yes\n");
    assert_screen 'root-console';

    # Push update via ssh
    assert_script_run("cd ~/repos/qa2;echo \"Update\" >> README");
    assert_script_run("git add README;git commit  -m \"Update README\"");
    type_string("clear\n");
    script_run("git push ssh://localhost:/root/repos/qa0 | tee /dev/$serialdev", 0);
    assert_screen 'root-console';

    # git clone via https protocol
    assert_script_run("cd ~;git clone -q https://github.com/os-autoinst/os-autoinst-distri-example");

    # clean up
    assert_script_run("rm -rf ~/repos ~/os-autoinst*");
}

1;
