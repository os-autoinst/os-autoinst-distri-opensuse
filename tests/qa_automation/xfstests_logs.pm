# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package xfstests_logs;
# Summary:  Log upload and analysis related base class for xfstests_run
# Maintainer: Yong Sun <yosun@suse.com>

use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use utils;
use testapi qw(is_serial_terminal :DEFAULT);

# Upload all log tarballs in ./results/
sub log_upload() {
    my $self = shift;
    my $tarball = "/tmp/qaset-xfstests-results.tar.bz2";
    assert_script_run("tar jcvf " . $tarball . " ./results/");
    upload_logs($tarball);
}

1;
