# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Update virsh config to boot from HD. Used on svirt.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    my $svirt = console('svirt');
    $svirt->change_domain_element(os => boot => {dev => 'hd'});
}

1;
