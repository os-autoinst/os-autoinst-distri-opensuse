# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: validate kiwi online build status from buildsystem
# - checks if system is at login screen
# - login using user root and password
# - runs curl on builtsystem url and using a sed ER filter, get the
# builds available and their status (failed, succeeded, etc), results are
# written to a file.
# - file above is parsed line by line for "succeeded". Else, returns error,
# meaning some build failure.
# - upload created file to further reference.
# Maintainer: Ednilson Miura <emiura@suse.com>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils "is_sle";
my $logfile = 'build.log';

sub run {
    my $sle_version  = get_var('VERSION');
    my $install_type = get_var('KIWI_OLD');

    # login in to system
    assert_screen('linux-login', 120);
    type_string("root\n");
    sleep(2);
    type_password("linux\n");

    # validate build
    my $kiwi_version = "kiwi";
    # KIWI_OLD is set as 0 or 1
    if ($install_type == 0) {
        $kiwi_version = $kiwi_version . "-ng";
    }

    script_run("curl -k https://build.suse.de/project/monitor/QA:Maintenance:Images:$sle_version:$kiwi_version-testing | sed -n \"s/.*\\(test-image-[[:alpha:]]\\+\\).*>\\(.*\\)<\\/a><\\/td>/\\1 \\2/p\" > $logfile");
    #script_run("echo -e \"test-image-iso succeeded\\ntest-image-pxe succeeded\\ntest-image-vmx succeeded\\n\" > $logfile");
    my $check_log = script_output("cat $logfile");
    foreach my $line (split(/\n/, $check_log)) {
        if ($line !~ /succeeded/) {
            print $line;
            die "Kiwi build failure";
        }
        else {
            print $line;
        }
    }

    # upload logs anyway
    upload_logs $logfile;
}

# upload in case of failure
sub post_fail_hook {
    my ($self) = @_;
    upload_logs $logfile;
}

1;
