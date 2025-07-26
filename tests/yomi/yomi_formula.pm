# Yomi's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install and configure yomi-formula
# Maintainer: Alberto Planas <aplanas@suse.de>

use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';

    # Install yomi-formula, and salt-master as a requirement
    my $repo = 'https://download.opensuse.org/repositories/systemsmanagement:/yomi/openSUSE_Tumbleweed/systemsmanagement:yomi.repo';
    zypper_call "ar -C -G -f '$repo'";
    zypper_call '--gpg-auto-import-keys ref';
    zypper_call 'in yomi-formula';

    # Configure salt-master
    assert_script_run 'cp -a /usr/share/yomi/pillar.conf /etc/salt/master.d/';
    assert_script_run 'cp -a /usr/share/yomi/autosign.conf /etc/salt/master.d/';
    assert_script_run 'echo -e "base:\n  \'*\':\n    - yomi.installer" > /srv/salt/top.sls';
    assert_script_run 'systemctl restart salt-master.service';
}

sub test_flags {
    return {fatal => 1};
}

1;
