# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: new test that adds configured repositories
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "consoletest";
use testapi;
use utils qw(quit_packagekit zypper_call);

sub run {
    my $val = get_var("ZYPPER_ADD_REPOS");
    return unless $val;

    select_console 'root-console';
    quit_packagekit;
    my $prefix = get_var("ZYPPER_ADD_REPO_PREFIX", 'openqa');

    my $i = 0;
    # do not check gpg if the repo is untrusted
    my $untrusted = $prefix eq 'untrusted' ? '-G' : '';
    for my $url (split(/,/, $val)) {
        zypper_call("ar $untrusted -c -f $url $prefix$i");
        ++$i;
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
