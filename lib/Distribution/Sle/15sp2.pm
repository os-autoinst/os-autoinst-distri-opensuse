# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class represents SLE 15 SP2 distribution and provides access to
# its features.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Distribution::Sle::15sp2;
use strict;
use warnings FATAL => 'all';
use parent 'susedistribution';
use Installation::Partitioner::LibstorageNG::GuidedSetupController;
use Installation::Partitioner::LibstorageNG::v4::ExpertPartitionerController;
use YaST::NetworkSettings::v4::NetworkSettingsController;
use YaST::SystemSettings::SystemSettingsController;

sub get_partitioner {
    return Installation::Partitioner::LibstorageNG::GuidedSetupController->new();
}

sub get_expert_partitioner {
    return Installation::Partitioner::LibstorageNG::v4::ExpertPartitionerController->new();
}

sub get_network_settings {
    return YaST::NetworkSettings::v4::NetworkSettingsController->new();
}

sub get_system_settings {
    return YaST::SystemSettings::SystemSettingsController->new();
}

1;
