# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

package sles4sap::console_redirection::redirection_data_tools;
use Mojo::Base -base;
use strict;
use warnings FATAL => 'all';
use testapi;


=head1 SYNOPSIS

Library with helper tools to extract and manipulate data from data structure used in redirection tests.
For more details about structure format and redirection tests check B<tests/sles4sap/redirection_tests/README.md>

B<Usage example:>
C<use sles4sap::console_redirection::redirection_data_tools;>
C<my $redirection = sles4sap::console_redirection::redirection_data_tools->new($run_args->{redirection_data});>
C<my %nw_hosts = %{$redirection->get_nw_hosts};>

=cut

=head2 get_databases

    get_databases();

Returns B<ARRAYREF> containing only HANA database connection data
B<Example:>
{
    hostname_a => {ip_address => '192.168.0.2', ssh_user => 'username'}
    hostname_b => {ip_address => '192.168.0.2', ssh_user => 'username'}
};

=cut

sub get_databases {
    my $self = shift;
    return $self->{db_hana};
}

=head2 get_ensa2_hosts

    get_ensa2_hosts();

Returns B<ARRAYREF> containing only ENSA2 cluster connection data
B<Example:>
{
    hostname_a => {ip_address => '192.168.0.2', ssh_user => 'username'}
    hostname_b => {ip_address => '192.168.0.2', ssh_user => 'username'}
};

=cut

sub get_ensa2_hosts {
    my $self = shift;
    return {map { %{$self->{$_}} } qw(nw_ascs nw_ers)};
}

=head2 get_nw_hosts

    get_nw_hosts();

Returns B<ARRAYREF> containing only ENSA2 cluster connection data
B<Example:>
{
    hostname_a => {ip_address => '192.168.0.2', ssh_user => 'username'}
    hostname_b => {ip_address => '192.168.0.2', ssh_user => 'username'}
};

=cut

sub get_nw_hosts {
    my $self = shift;
    return {map { %{$self->{$_}} } qw(nw_ascs nw_ers nw_pas nw_aas)};
}

=head2 get_pas_host

    get_pas_host();

Returns B<ARRAYREF> containing only ENSA2 pas connection data
B<Example:>
{
    hostname => {ip_address => '192.168.0.1', ssh_user => 'username'}
};

=cut

sub get_pas_host {
    my $self = shift;
    return {map { %{$_} } ($self->{nw_pas})};
}

=head2 get_sap_hosts

    get_sap_hosts();

Returns B<ARRAYREF> containing connection data to all hosts related to SAP suite (Databases, instances, etc...).
B<Example:>
{
    hostname_a => {ip_address => '192.168.0.2', ssh_user => 'username'}
    hostname_b => {ip_address => '192.168.0.2', ssh_user => 'username'}
};

=cut

sub get_sap_hosts {
    my $self = shift;
    return {map { %{$self->{$_}} } qw(nw_ascs nw_ers nw_pas nw_aas db_hana)};
}

1;
