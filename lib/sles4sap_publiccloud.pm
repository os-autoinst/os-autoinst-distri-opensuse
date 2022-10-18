# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Library used for SLES4SAP publicccloud deployment and tests

use base 'publiccloud::basetest';
package sles4sap_publiccloud;
use strict;
use warnings FATAL => 'all';
use testapi;
use List::MoreUtils qw(uniq);
use Exporter 'import';
use Carp qw(croak);
use hacluster '$crm_mon_cmd';

our @EXPORT = qw(
  run_cmd
  get_promoted_hostname
  get_hana_topology
  wait_for_sync
);

=head2 run_cmd
    run_cmd(cmd => 'command', [runas => 'user', timeout => 60]);

Runs a command C<cmd> via ssh in the given VM and log the output.
All commands are executed through C<sudo>.
If 'runas' defined, command will be executed as specified user,
otherwise it will be executed as root.

=cut

sub run_cmd {
    my ($self, %args) = @_;
    croak('Argument <cmd> missing') unless ($args{cmd});
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 60);
    my $title = $args{title} // $args{cmd};
    $title =~ s/[[:blank:]].+// unless defined $args{title};
    my $cmd = defined($args{runas}) ? "su - $args{runas} -c '$args{cmd}'" : "$args{cmd}";

    # Without cleaning up variables SSH commands get executed under wrong user
    delete($args{cmd});
    delete($args{title});
    delete($args{timeout});
    delete($args{runas});

    my $out = $self->{my_instance}->run_ssh_command(cmd => "sudo $cmd", timeout => $timeout, %args);
    record_info("$title output - $self->{my_instance}->{instance_id}", $out) unless ($timeout == 0 or $args{quiet} or $args{rc_only});
    return $out;
}

=head2 get_promoted_hostname()
    get_promoted_hostname();

Checks and returns hostname of HANA promoted node.
=cut

sub get_promoted_hostname {
    my ($self) = @_;
    my $hana_resource = join("_",
        "msl",
        "SAPHana",
        "HDB",
        get_required_var("INSTANCE_SID") . get_required_var("INSTANCE_ID"));

    my $resource_output = $self->run_cmd(cmd => "crm resource status " . $hana_resource, quiet => 1);
    record_info("crm out", $resource_output);
    my @master = $resource_output =~ /:\s(\S+)\sMaster/g;
    if (scalar @master != 1) {
        diag("Master database not found or command returned abnormal output.\n
        Check 'crm resource status' command output below:\n");
        diag($resource_output);
        die("Master database was not found, check autoinst.log");
    }

    return join("", @master);
}


=head2 wait_for_sync
    wait_for_sync();
    Wait for replica site to sync data with primary.
    Checks "SAPHanaSR-showAttr" output and ensures replica site has "sync_state" "SOK".
=cut

sub wait_for_sync {
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 900);
    my $sok = 0;
    record_info("Sync wait", "Waiting for data sync between nodes");

    # Check sync status periodically until ok or timeout
    my $start_time = time;

    while ($sok == 0) {
        my $topology = $self->get_hana_topology();
        for my $entry (@$topology) {
            my %entry = %$entry;
            next if !exists($entry{sync_state});
            $sok = 1 if $entry{sync_state} eq "SOK";
            last if $sok == 1;
        }

        if (time - $start_time > $timeout) {
            record_info("Cluster status", $self->run_cmd(cmd => $crm_mon_cmd));
            record_info("Sync FAIL", "Host replication status: " . $self->run_cmd(cmd => 'SAPHanaSR-showAttr'));
            die("Replication SYNC did not finish within defined timeout. ($timeout sec).");
        }
        sleep 30;
    }
    record_info("Sync OK", $self->run_cmd(cmd => "SAPHanaSR-showAttr"));
    return 1;
}


=head2 get_hana_topology
    get_hana_topology([hostname => $hostname]);
    Parses  command output, returns list of hashes containing values for each host.
    If hostname defined, returns hash with values only for host specified.
=cut

sub get_hana_topology {
    my ($self, %args) = @_;
    my @topology;
    my $hostname = $args{hostname};
    my $cmd_out = $self->run_cmd(cmd => "SAPHanaSR-showAttr --format=script", quiet => 1);
    record_info("cmd_out", $cmd_out);
    my @all_parameters = map { if (/^Hosts/) { s,Hosts/,,; s,",,g; $_ } else { () } } split("\n", $cmd_out);
    my @all_hosts = uniq map { (split("/", $_))[0] } @all_parameters;

    for my $host (@all_hosts) {
        my %host_parameters = map { my ($node, $parameter, $value) = split(/[\/=]/, $_);
            if ($host eq $node) { ($parameter, $value) } else { () } } @all_parameters;
        push(@topology, \%host_parameters);

        if (defined($hostname) && $hostname eq $host) {
            return \%host_parameters;
        }
    }

    return \@topology;
}

1;
