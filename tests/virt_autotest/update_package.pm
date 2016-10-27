# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
use strict;
use warnings;
use base "opensusebasetest";
use File::Basename;
use testapi;

use base "virt_autotest_base";
use virt_utils;

sub update_package() {
    my $self           = shift;
    my $test_type      = get_var('TEST_TYPE', 'Milestone');
    my $update_pkg_cmd = "source /usr/share/qa/virtautolib/lib/virtlib;update_virt_rpms";
    my $ret;
    if ($test_type eq 'Milestone') {
        $update_pkg_cmd = $update_pkg_cmd . " off on off";
    }
    else {
        $update_pkg_cmd = $update_pkg_cmd . " off off on";
    }

    $update_pkg_cmd = $update_pkg_cmd . " 2>&1 | tee /tmp/update_virt_rpms.log ";
    $ret = $self->execute_script_run($update_pkg_cmd, 7200);
    upload_logs("/tmp/update_virt_rpms.log");
    save_screenshot;
    if ($ret !~ /Need to reboot system to make the rpms work/m) {
        die " Update virt rpms fail, going to terminate following test!";
    }

}

sub run() {
    my $self = shift;
    $self->update_package();
    if (!get_var("PROXY_VIRT_AUTOTEST")) {
        setup_console_in_grub;
        repl_repo_in_sourcefile();
    }
}


sub test_flags {
    return {fatal => 1};
}

1;

