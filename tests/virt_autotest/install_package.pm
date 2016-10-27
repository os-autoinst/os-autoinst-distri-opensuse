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
use testapi;
use base "opensusebasetest";

sub install_package() {
    my $qa_server_repo = get_var('QA_HEAD_REPO', '');

    if ($qa_server_repo) {
        script_run "zypper --non-interactive rr server-repo";
        assert_script_run("zypper --non-interactive --no-gpg-check -n ar -f '$qa_server_repo' server-repo");
    }
    else {
        die "There is no qa server repo defined variable QA_HEAD_REPO\n";
    }
    assert_script_run("zypper --non-interactive --gpg-auto-import-keys ref", 180);

    assert_script_run("zypper --non-interactive -n in qa_lib_virtauto", 1800);

    if (get_var("PROXY_VIRT_AUTOTEST")) {
        if (get_var("XEN")) {
            assert_script_run("zypper --non-interactive -n in -t pattern xen_server", 1800);
        }
    }
}

sub run() {
    install_package;
}


sub test_flags {
    return {fatal => 1};
}

1;

