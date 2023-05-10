# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class represents ALP distribution and provides access to
# its features.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Distribution::Alp;
use strict;
use warnings FATAL => 'all';
use parent 'susedistribution';
use Yam::ControlCenterPage;
use Yam::ReleaseNotesPage;

sub get_control_center {
    return Yam::ControlCenterPage->new();
}
sub get_release_notes {
    return Yam::ReleaseNotesPage->new();
}

1;
