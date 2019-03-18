# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: validate kiwi online build status from buildsystem
# Maintainer: Ednilson Miura <emiura@suse.com>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils "is_sle";
my $sle_version = get_var('VERSION');
my @files_list  = ('build.log');

# check kiwi build status
sub check_status {
    my @builds = ("test-image-docker", "test-image-iso", "test-image-oem", "test-image-pxe", "test-image-vmx");
    script_run("curl -k https://build.suse.de/project/monitor/QA:Maintenance:Images:$sle_version:kiwi-ng-testing > kiwi_out.html");
    # sle12sp3 has 2 different builds
    if (is_sle('<=12-SP3')) {
        script_run("curl -k https://build.suse.de/project/monitor/QA:Maintenance:Images:$sle_version:kiwi-testing > kiwi_out2.html");
        push @files_list, 'build2.log';
    }
    # parse build.log
    foreach my $kiwi_build (@builds) {
        script_run("(grep $kiwi_build kiwi_out.html | grep -q succeeded && echo \"SLE-$sle_version $kiwi_build PASSED\" || 
        echo \"SLE-$sle_version $kiwi_build FAILED\") >> build.log");
    }

    # check run if old kiwi
    if (is_sle('<=12-SP3')) {
        script_run("(grep test-image-oem kiwi_out2.html | grep -q succeeded && echo \"SLE-$sle_version test-image-oem PASSED\" || 
        echo \"SLE-$sle_version test-image-oem FAILED\") >> build2.log");
        # show contents before check
        script_run("cat build2.log");
    }
    # show contents before check
    script_run("cat build.log");

    # reverse grep output (exit 1 if errors found)
    foreach my $fname (@files_list) {
        if (script_run("grep -q FAILED $fname")) {
            assert_script_run '$(exit 0)';
        }
        else {
            assert_script_run '$(exit 1)';
        }
    }
}

sub run {
    assert_screen('kiwi_login', 120);
    type_string("root\n");
    sleep(2);
    type_password("linux\n");
    # validate build
    check_status();
    # upload logs anyway
    foreach my $l (@files_list) {
        upload_logs $l;
    }
}

sub post_fail_hook {
    my ($self) = @_;
    foreach my $l (@files_list) {
        upload_logs $l;
    }
}

1;
