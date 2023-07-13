# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the NFS repository is available.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
