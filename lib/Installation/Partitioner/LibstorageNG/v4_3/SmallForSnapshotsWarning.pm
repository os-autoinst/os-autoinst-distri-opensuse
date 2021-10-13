# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods in Expert Partitioner to handle
# a confirmation warning when root device is very small for snapshots.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::SmallForSnapshotsWarning;
use strict;
use warnings;
use parent 'Installation::Popups::YesNoPopup';

1;
