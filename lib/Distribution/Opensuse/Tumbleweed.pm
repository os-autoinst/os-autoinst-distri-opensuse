# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class represents Tumbleweed distribution and provides access to
# its features.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Distribution::Opensuse::Tumbleweed;
use strict;
use warnings FATAL => 'all';
use parent 'susedistribution';
use Installation::Overview::OverviewController;
use Installation::Partitioner::LibstorageNG::v4_3::SuggestedPartitioningController;
use Installation::Partitioner::LibstorageNG::v4_3::GuidedSetupController;
use Installation::Partitioner::LibstorageNG::GuidedSetupController;
use Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerController;
use YaST::NetworkSettings::v4_3::NetworkSettingsController;
use Installation::SystemRole::SystemRoleController;
use YaST::SystemSettings::SystemSettingsController;
use YaST::Firstboot::FirstbootController;

sub get_partitioner {
    return Installation::Partitioner::LibstorageNG::GuidedSetupController->new();
}

sub get_guided_partitioner {
    return Installation::Partitioner::LibstorageNG::v4_3::GuidedSetupController->new();
}

sub get_expert_partitioner {
    return Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerController->new();
}

sub get_overview_controller {
    return Installation::Overview::OverviewController->new();
}

sub get_network_settings {
    return YaST::NetworkSettings::v4_3::NetworkSettingsController->new();
}

sub get_system_role_controller() {
    return Installation::SystemRole::SystemRoleController->new();
}

sub get_system_settings {
    return YaST::SystemSettings::SystemSettingsController->new();
}

sub get_suggested_partitioning() {
    return Installation::Partitioner::LibstorageNG::v4_3::SuggestedPartitioningController->new();
}

sub get_firstboot {
    return YaST::Firstboot::FirstbootController->new();
}

1;
