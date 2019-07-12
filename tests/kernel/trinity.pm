# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Trying to stress kernel with fuzz testing using trinity
# Maintainer: Anton Smorodskyi<asmorodskyi@suse.com>

use base "opensusebasetest";
use testapi;
use utils;
use strict;
use warnings;
use upload_system_log;
use repo_tools 'generate_version';
use version_utils 'is_sle';

our $trinity_log;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    $trinity_log = script_output("echo ~$testapi::username/trinity.log");
    my $syscall_cnt = 1000000;

    if (is_sle) {
        my $repo_url = 'http://download.suse.de/ibs/home:/asmorodskyi/' . generate_version() . '/';
        zypper_ar($repo_url, name => 'trinity');
    }
    zypper_call('in trinity');

    assert_script_run("cd  ~$testapi::username");
    assert_script_run("sudo -u $testapi::username trinity -N$syscall_cnt", 2000);
    upload_system_logs();
    upload_logs($trinity_log);
}

sub post_fail_hook {
    my ($self) = shift;
    upload_system_logs();
    upload_logs($trinity_log);
}
1;
