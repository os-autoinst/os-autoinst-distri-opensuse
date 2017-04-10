# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: First commit of JeOS firstrun, diskusage, sccreg, and imgsize tests
# G-Maintainer: Richard Brown <rbrownccb@opensuse.org>

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $sccmail = get_var("SCC_EMAIL");
    my $scccode = get_var("SCC_REGCODE");
    my $url     = get_var('SCC_URL', 'https://scc.suse.com');

    assert_script_run "SUSEConnect --url=$url -e $sccmail -r $scccode";
}

1;
# vim: set sw=4 et:
