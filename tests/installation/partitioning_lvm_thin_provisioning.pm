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

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use partition_setup qw(create_new_partition_table addpart addlv addvg addboot);
use version_utils 'is_storage_ng';

sub run {
    create_new_partition_table;
    addboot if is_storage_ng;
    # create boot and 2 lvm partitions
    addpart(role => 'raw', size => 15000);    #rootfs + swap
    addpart(role => 'raw');                   # home on thin lv
                                              # create volume group for root and swap non thin lvs
    addvg(name => 'vg-no-thin');
    addlv(name => 'lv-swap', role => 'swap', vg => 'vg-no-thin', size => 2000);
    addlv(name => 'lv-root', role => 'OS',   vg => 'vg-no-thin');
    # create volume group for thin lv
    addvg(name => 'vg-thin');
    addlv(name => 'thin_pool',    vg   => 'vg-thin', thinpool => 1);
    addlv(name => 'thin_lv_home', role => 'data',    vg       => 'vg-thin', thinvolume => 1);
    save_screenshot;
    send_key $cmd{accept};

}

1;
