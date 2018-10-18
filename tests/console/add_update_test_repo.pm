# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add maintenance repositories after installation, is much faster than during installation
# Maintainer: Jozef Pupava <jpupava@suse.com>

use strict;
use base "y2logsstep";
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';

    my @repos = split(/,/, get_var('MAINT_TEST_REPO'));
    while (defined(my $maintrepo = shift @repos)) {
        next if $maintrepo =~ /^\s*$/;
        # create repo name from update ID and product
        $maintrepo =~ /Maintenance:\/(\d+)\/(\S+)\//;
        my $repo_name = "$1_$2";
        zypper_call "ar -f $maintrepo $repo_name";
    }
    zypper_call "lr -u |& tee /dev/$serialdev";
    zypper_call "up |& tee /dev/$serialdev";
}

1;
