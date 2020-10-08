# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validate that the NFS repository is available.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base "consoletest";
use strict;
use warnings;

use testapi;
use repo_tools "validate_repo_properties";

sub run {
    select_console "root-console";
    my $nfs_repo_uri = get_var("MIRROR_NFS");
    validate_repo_properties({URI => $nfs_repo_uri, Enabled => "Yes"});
}

1;
