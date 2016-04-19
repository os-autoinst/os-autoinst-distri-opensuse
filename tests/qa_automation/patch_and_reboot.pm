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

    script_run("zypper -n patch --with-interactive -l; echo 'worked-patch-\$?' > /dev/$serialdev", 0);

    my $ret = wait_serial "worked-patch-\?-", 700;
    $ret =~ /worked-patch-(\d+)/;
    die "zypper failed with code $1" unless $1 == 0 || $1 == 102 || $1 == 103;

    script_run("zypper -n patch --with-interactive -l; echo 'worked-2-patch-\$?-' > /dev/$serialdev", 0);    # first one might only have installed "update-test-affects-package-manager"
    $ret = wait_serial "worked-2-patch-\?-", 1500;
    $ret =~ /worked-2-patch-(\d+)/;
    die "zypper failed with code $1" unless $1 == 0 || $1 == 102;

    set_var('SYSTEM_IS_PATCHED', 1);
    type_string "reboot\n";
}

sub test_flags {
    return {fatal => 1};
}

1;
