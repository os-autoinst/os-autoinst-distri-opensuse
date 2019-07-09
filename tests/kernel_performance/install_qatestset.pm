# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: setup performance run environment
# Maintainer: Joyce Na <jna@suse.de>

package install_qatestset;
use base 'y2_installbase';
use power_action_utils 'power_action';
use strict;
use warnings;
use utils;
use testapi;
use repo_tools 'add_qa_head_repo';

sub install_pkg {
    add_qa_head_repo;
    zypper_call("install qa_testset_automation");
}

sub setup_environment {
    my $runid             = get_required_var('QASET_RUNID');
    my $mitigation_switch = get_required_var('MITIGATION_SWITCH');
    assert_script_run(
        "/usr/share/qa/qaset/bin/deploy_performance.sh $runid $mitigation_switch"
    );
    assert_script_run("cat /root/qaset/qaset-setup.log");
}

sub run {
    install_pkg;
    setup_environment;
    power_action('poweroff', keepconsole => 1, textmode => 1);
}

sub post_fail_hook {
    my ($self) = @_;
}

sub test_flags {
    return {fatal => 1};
}

1;
