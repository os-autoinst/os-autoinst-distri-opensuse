# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Cleanup cloud resources meant to be used with multimodule setup with qe-sap-deployment project.
# https://github.com/SUSE/qe-sap-deployment

use base 'sles4sap_publiccloud_basetest';
use warnings FATAL => 'all';
use testapi;


sub run {
    my ($self, $run_args) = @_;
    # Needed to have ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    if (get_var('QESAP_NO_CLEANUP')) {
        record_info('SKIP CLEANUP',
            "Variable 'QESAP_NO_CLEANUP' set to value " . get_var('QESAP_NO_CLEANUP'));
        return 1;
    }
    eval { $self->cleanup($run_args); } or bmwqemu::fctwarn("self::cleanup(\$run_args) failed -- $@");
    $run_args->{ansible_present} = $self->{ansible_present};
}

1;
