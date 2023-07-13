# SUSE's feature tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: feature [ECO] zypper: more advanced $releasever handling
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>
# Tags: tc#1480297, fate#318354

use base "consoletest";
use strict;
use warnings;
use testapi;

sub remove_repo {
    my ($repo) = @_;
    script_run "zypper -n rr $repo";
}

sub run {
    select_console 'root-console';

    my $dist = uc(get_var "DISTRI");
    my $test_repo = 'TEST';
    my $zypper_ar_ok = qr/^Repository .* successfully added/m;
    my $zypper_pk_block = qr/^Tell PackageKit to quit\?/m;

    # Add a test repo with $releasever var being used in its name
    script_run
      "zypper ar -n '${dist}\${releasever_major}\${releasever_minor:+SP\$releasever_minor}' -d dir:/tmp $test_repo 2>&1 | tee /dev/$serialdev",
      0;

    my $out = wait_serial [$zypper_ar_ok, $zypper_pk_block];
    if ($out =~ $zypper_pk_block) {
        enter_cmd "yes";
        wait_serial $zypper_ar_ok || die "Failed to add test repo";
    }

    # Check the repo name is set according to the value of $releasever var
    foreach my $ver (qw(12 12.1)) {
        my $repo_alias = $dist . $ver;
        $repo_alias =~ s/\./SP/;
        my $str = qr/^Name *: *${repo_alias} */m;

        script_run "zypper --releasever=$ver lr $test_repo | tee /dev/$serialdev", 0;
        if (!wait_serial $str) {
            remove_repo $test_repo;
            die "zypper returns incorrect repo name";
        }
    }

    remove_repo $test_repo;
    save_screenshot;
}

1;
