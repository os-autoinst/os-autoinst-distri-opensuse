# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: new test that adds configured repositories
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils qw(pkcon_quit zypper_call);

sub run {
    my $val = get_var("ZYPPER_ADD_REPOS");
    return unless $val;

    select_console 'root-console';
    pkcon_quit;
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
