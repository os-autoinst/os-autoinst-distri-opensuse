# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: iproute2
# Summary: VLAN - Create a VLAN from wicked XML files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use testapi;
use network_utils 'iface';


sub run {
    my ($self) = @_;
    record_info('Info', 'VLAN - Create a VLAN from wicked XML files');
    $self->setup_vlan('vlan');
}

1;
