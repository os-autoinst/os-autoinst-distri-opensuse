# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: LVM thin provisioning setup
# Maintainer: Martin Loviska <mloviska@suse.com>

use strict;
use warnings;
use base 'y2logsstep';
use testapi;
use partition_setup qw(create_new_partition_table addpart addlv addvg);
use version_utils 'is_storage_ng';

sub run {
    create_new_partition_table;
    # create boot and 2 lvm partitions
    addpart(role => 'raw', fsid => 'bios-boot', size => 2);
    addpart(role => 'raw', size => 10000);
    addpart(role => 'raw');
    # create volume group for root and swap non thin lvs
    addvg(name => 'vg-no-thin');
    addlv(name => 'lv-swap', role => 'swap', size => 2000);
    addlv(name => 'lv-root', role => 'OS');
    # create volume group for thin lv
    addvg(name => 'vg-thin');
    addlv(name => 'thin_pool', thinpool => 1);
    addlv(name => 'thin_lv_home', role => 'data', thinvolume => 1);
    send_key $cmd{accept};

}

1;
