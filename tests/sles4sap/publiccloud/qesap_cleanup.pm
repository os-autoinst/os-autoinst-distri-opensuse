# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Cleanup cloud resources meant to be used with multimodule setup with qe-sap-deployment project.
# https://github.com/SUSE/qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/publiccloud/qesap_cleanup.pm - Cleans up the cloud resources.

=head1 DESCRIPTION

This module is responsible for cleaning up the cloud resources that were deployed
for the test run. It is typically scheduled as the last test in a sequence to
ensure that all resources are properly removed. The cleanup process can be
skipped by setting the B<QESAP_NO_CLEANUP> variable.

=head1 SETTINGS

=over

=item B<QESAP_NO_CLEANUP>

If this variable is set to a true value, the cleanup process will be skipped.
This is useful for debugging or when the deployed infrastructure needs to be
inspected after the test run.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use base 'sles4sap::publiccloud_basetest';
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
