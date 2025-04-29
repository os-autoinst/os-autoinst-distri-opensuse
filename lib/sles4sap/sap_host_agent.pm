# SUSE's openQA tests
#
# Copyright 2017-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions for SAP tests
# Maintainer: QE-SAP <qe-sap@suse.de>

package sles4sap::sap_host_agent;
use strict;
use warnings;
use testapi;
use Carp qw(croak);
use Exporter qw(import);

our @EXPORT = qw(
  saphostctrl_list_databases
  parse_instance_name
  saphostctrl_list_instances
);

my $saphostctrl = '/usr/sap/hostctrl/exe/saphostctrl';

=head1 SYNOPSIS

Package with functions related to interaction with SAP Host Agent (Command B<saphostctrl>). Those can be used for collecting
data about instances and performing various operations. Keep in mind that command needs to be executed using either
B<root> or B<sidadm>.

=cut

=head2 saphostctrl_list_databases

    saphostctrl_list_databases([as_root=>1]);

Uses C<saphostctrl> to get list of all databases residing on host. Returns parsed output as B<ARRAYREF>.
Data for each DB is contained in a B<HASH>
Example:
$VAR1 = {
          'Hostname' => 'qesdhdb01l029',
          'Release' => '2.00.075.00.1702888292',
          'Vendor' => 'HDB', # HDB = SAP hana database (not SID)
          'Type' => 'hdb', # type of hana DB - hdb, mdc (multitenant), systemdb
          'Instance name' => 'PRD00'
        };
$VAR2 = {
          'Hostname' => 'qesdhdb01l029',
          'Type' => 'hdb',
          'Release' => '2.00.075.00.1702888292',
          'Instance name' => 'QAS01',
          'Vendor' => 'HDB'
        };

=over

=item * B<as_root>: Execute command using sudo. Default: false

=back
=cut

sub saphostctrl_list_databases {
    my (%args) = @_;
    assert_script_run("[ -f $saphostctrl ]");

    # command returns data for each DB in new line = one array entry for each DB
    my $sudo = $args{as_root} ? 'sudo' : '';
    my $cmd = join(' ', $sudo, $saphostctrl, '-function', 'ListDatabases', '| grep Instance');
    my @output = split("\n", script_output($cmd, timeout => 180));

    # create hash with data from each array entry
    @output = map { { split(/,\s|:\s/, $_) } } @output;

    my @result;
    # change hash keys to lower case and replace spaces with underscore
    for my $entry (@output) {
        push(@result, {map { lc($_ =~ s/\s/_/gr) => $entry->{$_} } keys %$entry});
    }
    return (\@result);
}

=head2 parse_instance_name

    parse_instance_name($instance_name);

Splits instance name into B<SID> and B<instance ID>. Example: DBH01 -> sid=DBH, id=01

=over

=item * B<$instance_name>: Instance name

=back

=cut

sub parse_instance_name {
    my ($instance_name) = @_;
    croak("Invalid instance name: $instance_name\nInstance name is a combination of SID and instance ID.") if
      length($instance_name) != 5 or grep(/\s|[a-z]|\W/, $instance_name);
    my @result = $instance_name =~ /(.{3})(.{2})/s;
    return (\@result);
}

=head2 saphostctrl_list_instances

    saphostctrl_list_instances([as_root=>1]);

Lists all locally installed instances.
Executes command 'saphostctrl -function ListInstances' and returns parsed result in HASHREF.

=over

=item * B<as_root>: Execute command using sudo. Default: false

=back

=cut

sub saphostctrl_list_instances {
    my (%args) = @_;
    my @instances;
    # command returns data for each DB in new line = one array entry for each DB
    my $sudo = $args{as_root} ? 'sudo' : '';
    my $cmd = join(' ', $sudo, $saphostctrl, '-function', 'ListInstances', "| grep 'Inst Info'");
    for my $instance (split("\n", script_output($cmd))) {
        my @instance_data = split(/\s:\s|\s-\s/, $instance);
        push(@instances, {
                sap_sid => $instance_data[1],
                instance_id => $instance_data[2],
                hostname => $instance_data[3],
                nw_release => $instance_data[4]
        });
    }
    return \@instances;
}
