# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install SES and deepsea-qa from repo as stable or git as latest unstable code
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    my $git_deepsea        = get_var('GIT_DEEPSEA', 'SUSE/DeepSea.git');
    my $git_deepsea_branch = get_var('GIT_DEEPSEA_BRANCH');
    $git_deepsea_branch ||= is_sle('<15') ? 'SES5' : 'master';
    # SES6 latest packages
    my $arch = get_var('ARCH');
    zypper_call "ar http://download.suse.de/ibs/SUSE:/SLE-15-SP1:/Update:/Products:/SES6/images/repo/SUSE-Enterprise-Storage-6-POOL-$arch-Media1/ SES6"
      if is_sle('>=15');
    # install SES packages, chrony and git
    zypper_call 'in chrony git-core deepsea ceph';
    # deepsea testsuite from repo is stable, not changing every day and better for QAM testing
    if (get_var('DEEPSEA_TESTSUITE_STABLE')) {
        my $deepsea_qa
          = is_sle('>=15') ?
          'http://download.suse.de/ibs/SUSE:/SLE-15-SP1:/Update:/Products:/SES6/standard/SUSE:SLE-15-SP1:Update:Products:SES6.repo'
          : 'http://download.suse.de/ibs/SUSE:/SLE-12-SP3:/Update:/Products:/SES5:/Update/standard/SUSE:SLE-12-SP3:Update:Products:SES5:Update.repo';
        zypper_call "ar $deepsea_qa";
        zypper_call 'in deepsea-qa';
        assert_script_run 'rpm -q deepsea-qa';
    }
    else {
        assert_script_run "git clone https://github.com/$git_deepsea";
        assert_script_run 'cd DeepSea';
        assert_script_run "git checkout $git_deepsea_branch";
        assert_script_run 'make install';
        assert_script_run 'git log|head -n 45';
    }
    # install mandatory fping on SLE15+
    zypper_call 'in fping' if is_sle('>=15');
    zypper_call 'up -l';
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
