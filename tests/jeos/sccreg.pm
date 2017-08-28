# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Register JeOS with SUSEConnect as prerequisite
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $sccmail = get_required_var('SCC_EMAIL');
    my $scccode = get_required_var('SCC_REGCODE');
    my $url     = get_var('SCC_URL', 'https://scc.suse.com');

    assert_script_run "SUSEConnect --url=$url -e $sccmail -r $scccode";
}

1;
# vim: set sw=4 et:
