# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
#
# Summary: setup performance run environment 
# Maintainer: Joyce Na <jna@suse.de>



package install_qatestset;
use base "y2logsstep";
use strict;
use warnings;
use testapi;


sub install_pkg {
    my $qa_server_repo = get_var('QA_REPO'); 
    my $runid = get_var('QASET_RUNID');
    assert_script_run("hostname > /etc/hostname");
    assert_script_run("zypper --non-interactive rr qa-ibs");
    assert_script_run("zypper --non-interactive --no-gpg-check -n ar -f '$qa_server_repo' qa-ibs");
    assert_script_run("zypper -n --no-gpg-check ref");
    assert_script_run("zypper -n install qa_testset_automation");
    assert_script_run('echo "_QASET_RUNID=$runid" > /root/qaset/config');
}

sub meltdown{
    my $mitigation_switch = get_var('MITIGATION_SWITCH');
    my $grub_kernel_opts = "GRUB_CMDLINE_LINUX_DEFAULT";
    my $grub_default = "/etc/default/grub";
    my $grub_cfg = "/boot/grub2/grub.cfg";
    my $grub_cfg_bak = "/boot/grub2/grub.cfg.bak";
   
    assert_script_run("cp $grub_cfg $grub_cfg_bak");
    if (!script_run("grep -q '$grub_kernel_opts=.*$mitigation_switch' $grub_default")) {
       assert_script_run("sed -i 's/^\($grub_kernel_opts.*\)\"/\1 $mitigation_switch\"/' $grub_default");
    }
    assert_script_run("grub2-mkconfig > $grub_cfg");
}

sub run {
    if (check_var("DISABLE_MELTDOWN", 1)) {
        meltdown;
    }
    install_pkg;
}

sub test_flags {
    return {fatal => 1};
}

1;

