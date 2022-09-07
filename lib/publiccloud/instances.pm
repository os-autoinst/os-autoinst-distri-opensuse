# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base class for the public cloud namespace
#
# Maintainer: qa-c team <qa-c@suse.de>

package publiccloud::instances;

our @instances;    # Package variable containing all instanciated instances for global access without RunArgs

sub set_instances {
    @instances = @_;
}

sub get_instance {
    return undef if (scalar @instances) < 1;
    return $instances[0];
}

1;
