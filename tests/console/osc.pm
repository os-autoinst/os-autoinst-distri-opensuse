# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Maintainer: QE Core <qe-core@suse.de>
# Summary: The main task is to 'co' (checkout) and 'build' locally a
#          'package' from an 'API'/'codestream' using 'osc'. This is
#          achieved by preparing the systems with repositories and/or
#          packages necessary, deploying and modifying the configuration
#          file and running the actual test. In order to talk to the
#          APIs, credentials must be provided as arguments.
#
# Tags: poo#36562

use base "consoletest";
use testapi;
use utils;
use version_utils qw(is_sle get_os_release is_tumbleweed);
use strict;
use warnings;

sub repos_and_pkgs_sle {
    my ($hub_version, $arch) = @_;
    my $repo_version = $hub_version;
    $repo_version =~ s/\./_SP/;
    assert_script_run("SUSEConnect --product PackageHub/" . $hub_version . "/" . $arch);
    zypper_call("ar http://download.suse.de/ibs/SUSE:/CA/SLE_" . $repo_version . "/ suseca");
    zypper_call("in osc obs-service-source_validator ca-certificates-suse");
}

sub prepare_oscrc {
    my ($oscrc_path, $IBSUSER, $SECRET) = @_;
    assert_script_run("wget --quiet " . data_url('oscrc') . " -O " . $oscrc_path, timeout => 30);
    assert_script_run("perl -pi -e 's/TAGIBSUSER/" . $IBSUSER . "/g' " . $oscrc_path);
    assert_script_run("perl -pi -e 's/TAGSECRET/" . $SECRET . "/g' " . $oscrc_path);
}

sub co_and_build {
    my ($codestream, $testpkg) = @_;
    my $api_opensuse = "https://api.opensuse.org";

    if (is_sle) {
        assert_script_run("yes 1 | osc co " . $codestream . " " . $testpkg);
    } else {
        assert_script_run("yes 1 | osc -A " . $api_opensuse . " co " .  $codestream . " " . $testpkg);
    }
    assert_script_run("cd " . $codestream . "/" . $testpkg . "; yes 1 | osc build", timeout => 300);
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    my $IBSUSER = get_var("IBSUSER", "");
    my $SECRET = get_var("SECRET", "");
    my $arch = get_var("ARCH");
    my ($sle_major_version, $sle_sp) = get_os_release;
    my $testpkg = "perl-IO-String";
    my $oscrc_path = "/root/.oscrc";
    my $hub_version = $sle_major_version . "." . $sle_sp;
    my $sle_cs = "SUSE:SLE-" . $sle_major_version . ":Update";

    # 1) Repositories and packages needed
    if (is_sle) {
        repos_and_pkgs_sle($hub_version, $arch);
    } else {
        zypper_call("in osc");
    }

    # 2) Setting osc config file
    prepare_oscrc($oscrc_path, $IBSUSER, $SECRET);

    # 3) Checking-out and building locally
    if (is_sle) {
        co_and_build($sle_cs, $testpkg);
    } else {
        co_and_build("openSUSE:Factory", $testpkg);
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
