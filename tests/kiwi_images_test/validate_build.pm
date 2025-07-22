# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: curl
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
use testapi;
use utils;
my $logfile = 'build.log';

sub run {
    my $sle_version = get_var('VERSION');
    my $install_type = get_var('KIWI_OLD');

    # login in to system
    assert_screen('linux-login', 120);
    enter_cmd("root");
    sleep(2);
    type_password("linux\n");

    # validate build
    my $kiwi_version = "kiwi";
    # KIWI_OLD is set as 0 or 1
    if ($install_type == 0) {
        $kiwi_version = $kiwi_version . "-ng";
    }
    # new page layout contains a hash inside tbody, became too complex to run using assert_script
    assert_script_run("curl -v -o /tmp/validate_kiwi.sh " . data_url("qam/validate_kiwi.sh"));
    assert_script_run("chmod +x /tmp/validate_kiwi.sh");
    assert_script_run("/tmp/validate_kiwi.sh $sle_version $kiwi_version-testing $logfile");
    # upload logs anyway
    upload_logs $logfile;
}

# upload in case of failure
sub post_fail_hook {
    my ($self) = @_;
    upload_logs $logfile;
}

1;
