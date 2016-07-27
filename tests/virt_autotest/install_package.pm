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
use File::Basename;
use base "virt_autotest_base";
use testapi;
use virt_utils;

sub install_package() {
    my $qa_server_repo = get_var('QA_HEAD_REPO', '');
    if ($qa_server_repo) {
        type_string "zypper --non-interactive rr server-repo\n";
        assert_script_run("zypper --non-interactive --no-gpg-check -n ar -f '$qa_server_repo' server-repo");
    }
    else {
        die "There is no qa server repo defined variable QA_HEAD_REPO\n";
    }

    assert_script_run("zypper --non-interactive --gpg-auto-import-keys ref", 90);
    assert_script_run("zypper --non-interactive -n in qa_lib_virtauto",      1800);
}

sub update_package() {
    my $self           = shift;
    my $test_type      = get_var('TEST_TYPE', 'Milestone');
    my $update_pkg_cmd = "source /usr/share/qa/virtautolib/lib/virtlib;update_virt_rpms";
    if ($test_type eq 'Milestone') {
        $update_pkg_cmd = $update_pkg_cmd . " off on off";
    }
    else {
        $update_pkg_cmd = $update_pkg_cmd . " off off on";
    }

    $update_pkg_cmd = $update_pkg_cmd . " 2>&1 | tee /tmp/update_virt_rpms.log ";

    my $ret = $self->execute_script_run($update_pkg_cmd, 7200);
    save_screenshot;

    upload_logs("/tmp/update_virt_rpms.log");

    if ($ret !~ /Need to reboot system to make the rpms work/m) {
        die " Update virt rpms fail, going to terminate following test!";
    }

}


sub run() {
    my $self = shift;

    install_package;

    $self->update_package();

    setup_console_in_grub;
}


sub test_flags {
    return {important => 1};
}

1;

