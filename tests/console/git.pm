# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: git-core
# Case 1525281  - FIPS: git
# Summary: To check  whether can be successful via ssh or https protocol by using git
# - Create ssh key and copy to root
# - Create a test repo
# - Clone to a bare git repo
# - Clone repo via ssh
# - Push update via ssh
# - Git clone via https protocol
# - Clean up
# Maintainer: Lemon <leli@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call);

sub run {
    my $username = $testapi::username;
    my $email = "you\@example.com";
    my $self = shift;
    select_serial_terminal;

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
    script_run("git clone ssh://localhost:/root/repos/qa0 qa2 | tee /dev/$serialdev", 0);

    # Push update via ssh
    assert_script_run("cd ~/repos/qa2;echo \"Update\" >> README");
    assert_script_run("git add README;git commit  -m \"Update README\"");
    script_run("git push ssh://localhost:/root/repos/qa0 | tee /dev/$serialdev", 0);

    # git clone via https protocol
    assert_script_run("cd ~;git clone -q https://github.com/os-autoinst/os-autoinst-distri-example");

    # clean up
    assert_script_run("rm -rf ~/repos ~/os-autoinst*");
}

1;
