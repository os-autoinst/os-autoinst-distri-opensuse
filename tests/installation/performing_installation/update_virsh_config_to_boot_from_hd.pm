# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Update virsh config to boot from HD. Used on svirt.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use testapi;

sub run {
    my $svirt = console('svirt');
    $svirt->change_domain_element(os => boot => {dev => 'hd'});
}

1;
