# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#

# inherit qa_run, but overwrite run
use base "qa_run";
use strict;
use warnings;
use utils;
use testapi;

sub run {
    my $self = shift;
    $self->system_login();

    script_run("while pgrep packagekitd; do pkcon quit; sleep 1; done");

    for my $var (qw(OS_TEST_REPO SDK_TEST_REPO)) {
        my $repo = get_var($var);
        next unless $repo;
        assert_script_run("zypper --no-gpg-check -n ar -f '$repo' test-repo-$var");
    }

    my $ret = zypper_call("patch --with-interactive -l");
    die "zypper failed with code $ret" unless grep { $_ == $ret } (0, 102, 103);

    $ret = zypper_call("patch --with-interactive -l", 2000);    # first one might only have installed "update-test-affects-package-manager"
    die "zypper failed with code $ret" unless grep { $_ == $ret } (0, 102);

    set_var('SYSTEM_IS_PATCHED', 1);
    type_string "reboot\n";
}

sub test_flags {
    return {fatal => 1};
}

1;
