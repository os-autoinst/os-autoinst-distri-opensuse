# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Deliberate stop point for kubevirt MU verification runs
# Maintainer: qe-virt@suse.de

use Mojo::Base 'opensusebasetest';
use testapi;

sub run {
    die "kubevirt_fake_red is a deliberate stop point (poo#209043): "
      . "this kubevirt MU must not go green and be auto-approved before the rancher team answers. "
      . "Remove this module and its schedule entry once poo#209043 is resolved.";
}

# The red is deliberate: uploading the usual SUT artefacts on failure would
# only add noise nobody reads, so keep the post_fail_hook empty.
sub post_fail_hook { }

1;
