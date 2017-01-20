# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check diskusage on JeOS
# Maintainer: Richard Brown <rbrownccb@opensuse.org>

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $self    = shift;
    my $result  = 'ok';
    my $datamax = get_var("BTRFS_MAXDATASIZE");

    # spit out only the part of the btrfs filesystem size we're interested in
    script_run
      "echo btrfs-data=\$(btrfs filesystem df -b / | grep Data | sed -n -e 's/^.*used=//p') | tee -a /dev/$serialdev",
      0;
    my $datasize = wait_serial('btrfs-data=\d+\S+');    # https://xkcd.com/208/
                                                        # shouldn't ever happen, bet just incase it does
    die "failed to get btrfs-data size" unless (defined $datasize);
    $datasize = substr $datasize, 11;

    if ($datasize > $datamax) {
        $result = 'fail';
    }
    $self->result($result);
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
