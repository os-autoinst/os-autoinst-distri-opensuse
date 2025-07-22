# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Template used to load when ref machine is working in fully passive mode
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>


use base 'wickedbase';
use testapi;

sub run {
    my ($self) = @_;
}

sub test_flags {
    return {always_rollback => 1};
}

1;
