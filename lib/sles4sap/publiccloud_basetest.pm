# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Base test providing cleanup, post fail and post run hooks for tests using qe-sap-deployment project.
# https://github.com/SUSE/qe-sap-deployment

package sles4sap::publiccloud_basetest;

use Mojo::Base 'publiccloud::basetest';
use strict;
use warnings FATAL => 'all';
use Exporter 'import';
use Carp qw(croak);
use testapi;
use sles4sap::qesap::qesapdeployment;
use sles4sap::publiccloud;
use publiccloud::utils qw(get_ssh_private_key_path);

our @EXPORT = qw(cleanup import_context);

=head1 DESCRIPTION

    Basetest class for SLES for SAP Applications tests in Public Cloud.

=head2 cleanup

    $self->cleanup(%args)

Cleanup method intended to be called at the end of tests or in C<post_fail_hook>.
Mostly a wrapper around C<sles4sap::publiccloud::deployment_cleanup> which will:

=over

=item *

Remove network peerings

=item *

Run ansible de-registration playbooks

=item *

Run C<terraform destroy>

=back

Unless any of these has been executed previously.

=cut

sub cleanup {
    my ($self, $args) = @_;

    my $res = deployment_cleanup(
        $self,
        cleanup_called => $self->{cleanup_called},
        ansible_present => $self->{ansible_present}
    );

    if ($res eq 0) {
        $self->{cleanup_called} = 1;
        $self->{ansible_present} = 0;
    }

    $args->{my_provider}->terraform_applied(0)
      if ((defined $args)
        && (ref($args->{my_provider}) =~ /^publiccloud::(azure|ec2|gce)/)
        && (defined $self->{result})
        && ($self->{result} ne 'fail'));
}

=head2 import_context

    $self->import_context(%run_args)

Import into C<$self> the class instances context passed via C<%run_args>, and
record the information in the test results.

=cut

sub import_context {
    my ($self, $run_args) = @_;
    $self->{instances} = $run_args->{instances};
    $self->{ansible_present} = 1 if ($run_args->{ansible_present});
    record_info('CONTEXT LOG', join(' ',
            'cleanup_called:', $self->{cleanup_called} // 'undefined',
            'instances:', $self->{instances} // 'undefined',
            'ansible_present:', $self->{ansible_present} // 'undefined')
    );
}

=head2 set_cli_ssh_opts

    $self->set_cli_ssh_opts();
    $self->set_cli_ssh_opts('');
    $self->set_cli_ssh_opts("-4 -o LogLevel=ERROR -E $logfile");

Set command line SSH options in the instance stored in C<$self-E<gt>{my_instance}>. It takes
as an argument a string with the options in a manner that would be understood by B<ssh>, and
if no argument is provided, uses the following defaults:

=over

=item *

C<-E /var/tmp/ssh_sut.log>: save logging to B</var/tmp/ssh_sut.log>.

=back

B<Note>: if the method receives an empty string, no SSH options will be set.

=cut

sub set_cli_ssh_opts {
    my ($self, $ssh_opts) = @_;
    croak("Expected \$self->{my_instance} is not defined. Check module Description for details")
      unless $self->{my_instance};
    $ssh_opts //= join(' ', '-E', '/var/tmp/ssh_sut.log');
    $self->{my_instance}->ssh_opts($ssh_opts);
}

sub post_fail_hook {
    my ($self) = @_;
    if (get_var('QESAP_NO_CLEANUP_ON_FAILURE')) {
        diag('Skip post fail', "Variable 'QESAP_NO_CLEANUP_ON_FAILURE' defined.");
        return;
    }
    eval { $self->cleanup(); } or bmwqemu::fctwarn("self::cleanup() failed -- $@");
}

sub post_run_hook {
    diag('Skip post run', "Skipping post run hook. \n but also avoid to call the PC one");
}

1;
