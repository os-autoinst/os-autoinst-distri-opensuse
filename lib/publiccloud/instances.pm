# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base class for the public cloud namespace
#
# Maintainer: qa-c team <qa-c@suse.de>

package publiccloud::instances;
use testapi;
use strict;
use warnings;

our @instances;    # Package variable containing all instantiated instances for global access without RunArgs

sub set_instances {
    @instances = @_;
}

sub get_instance {
    die "no instances defined" if (scalar @instances) < 1;
    return $instances[0];
}

1;
