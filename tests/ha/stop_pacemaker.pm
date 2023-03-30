# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ha-cluster-bootstrap
# Summary: stop pacemaker
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use Utils::Systemd qw(systemctl);

sub run {
    select_console("root-console");
    systemctl 'stop pacemaker';
}

1;
