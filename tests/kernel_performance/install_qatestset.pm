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
    my $ver_cfg           = get_required_var('VER_CFG');
    my $ver_path          = "/root";

    assert_script_run("wget -N -P $ver_path $ver_cfg 2>&1");
    if (get_var("HANA_PERF")) {
        my $rel_ver = get_var('VERSION');
        assert_script_run("if [ ! -f /root/.product_version_cfg ]; then cp /root/.product_version_cfg.$rel_ver /root/.product_version_cfg; fi");
        assert_script_run("/usr/share/qa/qaset/bin/deploy_hana_perf.sh $runid $mitigation_switch");
        assert_script_run("ls /root/qaset/deploy_hana_perf_env.done");
        if (my $qaset_config = get_var("QASET_CONFIG")) {
            my @fields = split(/;/, $qaset_config);
            if (scalar @fields > 0) {
                foreach my $qaset_config (@fields) {
                    assert_script_run("echo ${qaset_config} >> /root/qaset/config");
                }
            }
        }
    } else {
        assert_script_run(
            "/usr/share/qa/qaset/bin/deploy_performance.sh $runid $mitigation_switch"
        );
        assert_script_run("cat /root/qaset/qaset-setup.log");
    }
}

sub os_update {
    my $update_repo_url  = shift;
    my $zypper_repo_path = "/etc/zypp/repos.d";

    assert_script_run("wget -N -P $zypper_repo_path $update_repo_url 2>&1");
    zypper_call("--gpg-auto-import-keys ref");
    zypper_call("dup");
}


sub run {
    if (my $hana_perf_os_update = get_var("HANA_PERF_OS_UPDATE")) {
        os_update($hana_perf_os_update);
    }
    install_pkg;
    setup_environment;
    if (check_var('ARCH', 'ppc64le')) {
        power_action('reboot', keepconsole => 1, textmode => 1);
    } else {
        power_action('poweroff', keepconsole => 1, textmode => 1);
    }
}

sub post_fail_hook {
    my ($self) = @_;
}

sub test_flags {
    return {fatal => 1};
}

1;
