# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check disk usage on JeOS
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub run {
    my $self   = shift;
    my $result = 'ok';

    # spit out only the part of the btrfs filesystem size we're interested in
    script_run "echo btrfs-data=\$(btrfs filesystem df -b / | grep Data | sed -n -e 's/^.*used=//p') | tee -a /dev/$serialdev", 0;
    my $datasize = wait_serial('btrfs-data=\d+\S+') || die "failed to get btrfs-data size";
    $datasize = substr $datasize, 11;
    chomp($datasize);

    my $btrfs_maxdatasize = get_required_var('BTRFS_MAXDATASIZE');
    die "Data used by JeOS ($datasize) exceeded expected OS installation size ($btrfs_maxdatasize)" if $datasize > $btrfs_maxdatasize;
}

1;
