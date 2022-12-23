# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-rmt rmt-server
# Summary: Add rmt configuration test and basic configuration via
#    rmt-wizard, test enable/disable products/repo, test rmt sync
#    rmt mirror, test import SMT data to RMT
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use repo_tools;
use utils;

sub run {
    select_console 'root-console';
    record_info('RMT server setup', 'Start to setup a rmt server');
    rmt_wizard();
    # sync from SCC
    rmt_sync;
    # enable all modules of products at one arch
    record_info('Enable all modules', 'Enable all modules and free extensions of a base product');
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
    record_info('Enable multiple products', 'Enable multiple products with product name at the same time in different ways');
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
    record_info('Disable multipule products', 'Disable multiple products with product name at the same time in different ways');
    assert_script_run("rmt-cli product disable SLES/12.3/x86_64 sle-module-live-patching/15/x86_64");
    assert_script_run("rmt-cli product disable SLES/12.5/x86_64,sle-we/15.2/x86_64");
    assert_script_run("rmt-cli product disable 'SLES/12.5/ppc64le sle-module-containers/15.1/s390x'");
    assert_script_run("rmt-cli product disable 'SLES/12.4/aarch64,sle-module-live-patching/15.2/ppc64le'");

    # enable product with product ID 1798-Web and Scripting Module/15.1/x86_64
    # 1973-Web and Scripting Module/15.2/aarch64 1974-Web and Scripting Module/15.2/ppc64le
    record_info('Enable product by id', 'Enable product by product id');
    assert_script_run("rmt-cli product enable 1798 1973 1974");
    assert_script_run("rmt-cli product list | grep 1798");
    assert_script_run("rmt-cli product list | grep 1973");
    assert_script_run("rmt-cli product list | grep 1974");

    # disable product with product ID
    record_info('Disable product by id', 'Disable product by product id');
    assert_script_run("rmt-cli product disable 1798 1973 1974");

    # enable repo with repo ID 3393-SLE-Module-Web-Scripting15-SP1-Pool for sle-15-x86_64
    # 3391-SLE-Module-Web-Scripting15-SP1-Updates for sle-15-x86_64
    record_info('Enable repo by id', 'Enable repo by repo id');
    assert_script_run("rmt-cli repo enable 3393 3391");
    assert_script_run("rmt-cli repo list | grep 3393");
    assert_script_run("rmt-cli repo list | grep 3391");

    # disable repo with repo ID
    record_info('Disable repo by id', 'Disable repo by repo id');
    assert_script_run("rmt-cli repo disable 3393 3391");

    # mirror packages
    record_info('mirror repo', 'Mirror repos from SCC');
    rmt_enable_pro;
    rmt_mirror_repo();
    assert_script_run("rmt-cli product list | grep sle-module-legacy/15/x86_64");

    record_info('Cleanup repo', 'Disable the enabled repos and cleanup the repos locally');
    # disable the mirrored repos
    assert_script_run("rmt-cli products disable sle-module-legacy/15/x86_64");
    # cleanup the downloaded files
    assert_script_run("yes yes | rmt-cli repos clean");
    my $ret = script_run("ls /usr/share/rmt/public/repo/SUSE/Products/SLE-Module-Legacy/15/x86_64 | wc -l");
    if ($ret > 0) {
        die 'cleanup repos failed';
    }

    # rmt server could mirror repos that not provided by SCC. Here we test adding custom repo
    # and attach the repo to a product mirrored from SCC.
    record_info('Add custom repo', 'Add some custom repos');
    my $custom_repo = get_var("CUSTOM_REPO") // 'https://download.opensuse.org/repositories/games:/tools/SLE_15_SP3/x86_64/';
    assert_script_run("rmt-cli repos custom add $custom_repo Games");
    assert_script_run("rmt-cli repos custom list | grep Games");
    # attach the custom repo to a product
    record_info('Attach the custom repo to a product', 'Attach the custom repo to a product');
    my $pro2 = get_var("PRODUCT_ATTACH") // 'sle-module-development-tools/15.3/x86_64';
    assert_script_run("rmt-cli products enable $pro2");
    my @proid2 = split(/\n/, script_output("rmt-cli products list | awk -F '|' '{print \$2}'"));
    for my $id (@proid2) {
        assert_script_run("rmt-cli repos custom attach games $id") if ($id =~ /\d{4}/);
    }
    assert_script_run("rmt-cli repos custom products games");
    assert_script_run("rmt-cli repos custom enable games");
    assert_script_run("rmt-cli repos custom disable games");

    # import smt data
    record_info('Import smt data', 'Import the data saved from a smt server');
    my $datapath = "/rmtdata/";
    my $datafile = get_var("SMT_DATA_FILE");
    my $dataurl = get_var("SMT_DATA_URL");
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
}

sub test_flags {
    return {fatal => 1};
}

1;
