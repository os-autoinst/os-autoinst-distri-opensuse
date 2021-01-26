# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: yast2-rmt rmt-server
# Summary: Add rmt configuration test and basic configuration via
#    rmt-wizard, test enable/disable products/repo, test rmt sync
#    rmt mirror, test import SMT data to RMT
# Maintainer: Yutao wang <yuwang@suse.com>

use strict;
use warnings;
use testapi;
use base 'x11test';
use repo_tools;
use utils;
use x11utils 'turn_off_gnome_screensaver';

sub run {
    x11_start_program('xterm -geometry 150x35+5+5', target_match => 'xterm');
    # Avoid blank screen since smt sync needs time
    turn_off_gnome_screensaver;
    become_root;
    rmt_wizard();
    # sync from SCC
    rmt_sync;
    # enable all modules of products at one arch
    my $pro = get_var("PRODUCT_ALLM");
    assert_script_run("rmt-cli p e $pro --all-modules");
    assert_script_run("rmt-cli product list | grep $pro");
    # enable all modules of products at four arch
    my $pro1 = get_var("PRODUCT_ALLMA");
    assert_script_run("rmt-cli products enable --all-modules $pro1");
    assert_script_run("rmt-cli product list | grep " . $pro1 . "/aarch64");
    assert_script_run("rmt-cli product list | grep " . $pro1 . "/ppc64le");
    assert_script_run("rmt-cli product list | grep " . $pro1 . "/s390x");
    assert_script_run("rmt-cli product list | grep " . $pro1 . "/x86_64");
    my @proid = split(/\n/, script_output("rmt-cli products list | awk -F '|' '{print \$2}'"));
    foreach my $i (@proid) {
        assert_script_run("rmt-cli products disable $i") if ($i =~ /\d{4}/);
    }

    # enable multiple products with product name at the same time in different way
    assert_script_run("rmt-cli product enable SLES/12.3/x86_64 sle-module-live-patching/15/x86_64");
    assert_script_run("rmt-cli product list | grep SLES/12.3/x86_64");
    assert_script_run("rmt-cli product list | grep sle-module-live-patching/15/x86_64");
    assert_script_run("rmt-cli product enable SLES/12.5/x86_64,sle-we/15.2/x86_64");
    assert_script_run("rmt-cli product list | grep SLES/12.5/x86_64");
    assert_script_run("rmt-cli product list | grep sle-we/15.2/x86_64");
    assert_script_run("rmt-cli product enable 'SLES/12.5/ppc64le sle-module-containers/15.1/s390x'");
    assert_script_run("rmt-cli product list | grep SLES/12.5/ppc64le");
    assert_script_run("rmt-cli product list | grep sle-module-containers/15.1/s390x");
    assert_script_run("rmt-cli product enable 'SLES/12.4/aarch64,sle-module-live-patching/15.2/ppc64le'");
    assert_script_run("rmt-cli product list | grep SLES/12.4/aarch64");
    assert_script_run("rmt-cli product list | grep sle-module-live-patching/15.2/ppc64le");

    # disable the products enabled above in different way
    assert_script_run("rmt-cli product disable SLES/12.3/x86_64 sle-module-live-patching/15/x86_64");
    assert_script_run("rmt-cli product disable SLES/12.5/x86_64,sle-we/15.2/x86_64");
    assert_script_run("rmt-cli product disable 'SLES/12.5/ppc64le sle-module-containers/15.1/s390x'");
    assert_script_run("rmt-cli product disable 'SLES/12.4/aarch64,sle-module-live-patching/15.2/ppc64le'");

    # enable product with product ID 1798-Web and Scripting Module/15.1/x86_64
    # 1973-Web and Scripting Module/15.2/aarch64 1974-Web and Scripting Module/15.2/ppc64le
    assert_script_run("rmt-cli product enable 1798 1973 1974");
    assert_script_run("rmt-cli product list | grep 1798");
    assert_script_run("rmt-cli product list | grep 1973");
    assert_script_run("rmt-cli product list | grep 1974");

    # disable product with product ID
    assert_script_run("rmt-cli product disable 1798 1973 1974");

    # enable repo with repo ID 3393-SLE-Module-Web-Scripting15-SP1-Pool for sle-15-x86_64
    # 3391-SLE-Module-Web-Scripting15-SP1-Updates for sle-15-x86_64
    assert_script_run("rmt-cli repo enable 3393 3391");
    assert_script_run("rmt-cli repo list | grep 3393");
    assert_script_run("rmt-cli repo list | grep 3391");

    # disable repo with repo ID
    assert_script_run("rmt-cli repo disable 3393 3391");

    # mirror packages
    rmt_enable_pro;
    rmt_mirror_repo();
    assert_script_run("rmt-cli product list | grep sle-module-legacy/15/x86_64");

    # import smt data
    my $datapath = "/rmtdata/";
    my $datafile = get_var("SMT_DATA_FILE");
    my $dataurl  = get_var("SMT_DATA_URL");
    assert_script_run("mkdir -p $datapath");
    assert_script_run("cd $datapath");
    assert_script_run("wget -q " . $dataurl . $datafile);
    assert_script_run("tar -xzvf $datafile -C $datapath");
    assert_script_run("chown -R _rmt:nginx $datapath");
    assert_script_run("sudo rmt-data-import -d /rmtdata/smt-data-export/");

    # check imported data 4205-SLE-Module-Live-Patching15-SP2-Source-Pool for sle-15-x86_64
    # 4203-SLE-Module-Live-Patching15-SP2-Pool for sle-15-x86_64
    assert_script_run("rmt-cli repo enable 4205 4203");
    assert_script_run("rmt-cli repo list");
    assert_script_run("rmt-cli repo list | grep 4205");
    assert_script_run("rmt-cli repo list | grep 4203");


    type_string "killall xterm\n";
}

sub test_flags {
    return {fatal => 1};
}

1;
