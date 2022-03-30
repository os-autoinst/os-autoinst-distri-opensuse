# Copyright 2021-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: SUSEConnect
# Summary: Verify milestone version and display some info.
# Check product info before and after migration
# Maintainer: Yutao Wang <yuwang@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use utils;
use version_utils;
use registration;
use List::MoreUtils 'uniq';

sub check_milestone_version {
    assert_script_run('cat /etc/issue');
    if (get_var('MILESTONE_VERSION')) {
        my $milestone_version = get_var('MILESTONE_VERSION');
        assert_script_run("grep -w $milestone_version /etc/issue");
    }
}

sub check_addons {
    my ($myaddons) = @_;
    $myaddons //= get_var('SCC_ADDONS');
    my @addons = grep { $_ =~ /\w/ } split(/,/, $myaddons);
    my @unique_addons = uniq @addons;
    foreach my $addon (@unique_addons) {
        my $name = get_addon_fullname($addon);
        record_info("$addon module fullname: ", $name);
        $name = "sle-product-we" if (($name =~ /sle-we/) && !get_var("MEDIA_UPGRADE") && is_sle('15+'));
        $name = "SLE-Module-DevTools" if (($name =~ /development/) && !get_var("MEDIA_UPGRADE"));
        my $out = script_output("zypper lr | grep -i $name", 200, proceed_on_failure => 1);
        die "zypper lr command output does not include $name" if ($out eq '');
    }
}

sub check_product {
    my ($status) = @_;
    $status //= "before";
    my $myver = get_var('VERSION');
    my %proname = (
        HPC => 'SLE-Product-HPC-' . $myver,
        SLES => 'SLES' . $myver,
        SLED => 'SLED' . $myver,
        SLE_HPC => 'SLE-Product-HPC-' . $myver,
        leap => "openSUSE-Leap",
        Media_HPC => $myver . '-HPC',
    );
    my $mypro = uc get_var('SLE_PRODUCT', '');
    my $product = '';
    if ($status eq 'before') {
        if ((get_var("HDDVERSION") =~ /leap/)) {
            $product = $proname{leap};
        } elsif ($mypro eq "SLE_HPC") {
            $product = $proname{SLES};
        } else {
            $product = $proname{$mypro};
        }
    } else {
        if (($mypro eq "HPC") && get_var("MEDIA_UPGRADE")) {
            $product = $proname{Media_HPC};
        } else {
            $product = $proname{$mypro};
        }
    }
    my $out = script_output("zypper lr | grep -i $product", 200, proceed_on_failure => 1);
    die "zypper lr command output does not include $product" if ($out eq '');
}

sub check_buildid {
    # Checked to get expected buildID with proxy scc upgrade
    if ((get_var('SCC_URL', "") =~ /proxy/) && !get_var("MEDIA_UPGRADE") && get_var("BUILD_SLE") && !get_var("ONLINE_MIGRATION")) {
        my $build_id = get_var("BUILD_SLE");
        my $build = script_output("zypper lr --url | grep -i $build_id", 200, proceed_on_failure => 1);
        die "System does not upgrade to expected build ID: $build_id" if ($build eq '');
    }
}

# SLE-21916: change bzr to breezy
# check in the upgraded sysetem that bzr was repalced by breezy
# test steps:
# 1) install the bzr as usaual
# 2) check the bzr version as usual to make sure it has breezy
# 3) cleanup by removing the package
sub check_bzr_to_breezy {
    record_info('SLE-21916', 'Check bzr to breezy');
    zypper_call('in bzr');

    assert_script_run('bzr --version');
    assert_script_run('bzr --version | grep breezy');
    zypper_call('--no-refresh info breezy');

    zypper_call("rm bzr", exitcode => [0]);
}

# SLE-20176 QA: Drop Python 2 (15 SP4)
# check in the upgraded system to ensure Python2 dropped
sub check_python2_dropped {
    my $out = script_output('zypper se python2 | grep python2', proceed_on_failure => 1);
    record_info('python2 dropped but still can be searched', 'Bug 1196533 - Python2 package still can be searched after migration to SLES15SP4', result => 'fail') if $out;
}

# SLE-23610: Python3 module
# test steps:
# 1) activate the python3 module
# 2) install the python310 package
# 3) check python3.10's version which should be 3.10.X
# 4) check python3's version
# 5) check python310's lifecycle
sub check_python3_module {
    record_info('SLE-23610', 'Check Python3 Module');
    my $OS_VERSION = script_output("grep VERSION_ID /etc/os-release | cut -c13- | head -c -2");
    my $ARCH = get_required_var('ARCH');
    assert_script_run("SUSEConnect -p sle-module-python3/$OS_VERSION/$ARCH");
    zypper_call("se python310");
    zypper_call("in python310");
    assert_script_run("python3.10 --version | grep Python | grep 3.10.");
    assert_script_run("python3 --version | grep Python | grep 3.6.");
    assert_script_run("zypper lifecycle python310");
}

# function to check all the features after migration
sub check_feature {
    if (!get_var('MEDIA_UPGRADE')) {
        check_bzr_to_breezy;
        check_python3_module;
    }
    check_python2_dropped;
}

sub run {
    select_console('root-console');
    assert_script_run('setterm -blank 0') unless (is_s390x);

    script_run('zypper lr | tee /tmp/zypperlr.txt', 200);

    # Need make sure the system is registered then check modules
    my $output = script_output('SUSEConnect -s', timeout => 180);
    # Check the expected addons before migration
    if (check_var('VERSION', get_required_var('ORIGIN_SYSTEM_VERSION')) && ($output !~ /Not Registered/)) {
        my $addons = get_var('SCC_ADDONS', "");
        $addons =~ s/ltss,?//g;
        check_addons($addons);
        check_product("before");
    }

    # Check the expected information after migration
    if (check_var('VERSION', get_required_var('UPGRADE_TARGET_VERSION'))) {
        check_milestone_version;
        my $myaddons = get_var('SCC_ADDONS', "");
        $myaddons .= ",base,serverapp" if (is_sle('15+') && check_var('SLE_PRODUCT', 'sles'));
        $myaddons .= ",base,desktop,we" if (is_sle('15+') && check_var('SLE_PRODUCT', 'sled'));
        $myaddons .= ",base,serverapp,desktop,dev,lgm,wsm" if (is_sle('<15', get_var('ORIGIN_SYSTEM_VERSION')) && is_sle('15+'));
        $myaddons .= ",base,serverapp,desktop,dev,lgm,wsm,phub" if (is_leap_migration);

        # For hpc, system doesn't include legacy module
        $myaddons =~ s/lgm,?//g if (get_var("SCC_ADDONS", "") =~ /hpcm/);
        check_addons($myaddons);
        check_product("after");
        check_buildid;
        check_feature if (is_sle(">=15-SP4") && check_var('INSTALLONLY', '1'));
    }
}

sub post_fail_hook {
    my $self = shift;
    upload_logs '/tmp/zypperlr.txt';
    $self->SUPER::post_fail_hook;
}

1;
