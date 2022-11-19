# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: mpirun helper class to prepare the string for invocation
# Maintainer: Kernel QE <kernel-qa@suse.de>

package hpc::formatter;
use Mojo::Base qw(hpcbase hpc::utils), -signatures;
use testapi qw(get_var get_required_var);
use version_utils qw(is_sle);

has mpirun => sub {
    my ($self) = shift;
    my $mpi = $self->get_mpi();
    $self->mpirun("mpirun");
    my @mpirun_args;
    ## openmpi requires non-root usr to run program or special flag '--allow-run-as-root'
    push @mpirun_args, '--allow-run-as-root ' if $mpi =~ m/openmpi/;
    # avoid openmpi3 warnings since 3.1.6-150500.11.3
    # TODO: map versions with mpi
    push @mpirun_args, '--mca btl_base_warn_component_unused 0 ' if ($mpi == 'openmpi3' && $self->compare_mpi_versions("$mpi-gnu-hpc", undef, '3.1.6-150500.11.3'));
    (@mpirun_args == 0) ? $self->mpirun :
      sprintf "%s %s", $self->mpirun, join(' ', @mpirun_args);
};

has need_interpreter => sub { return (get_var('HPC_LIB') =~ /scipy|numpy/); };

=head2 single_node

 single_node($bin);

Prepares and returns the command to run as string for a single host (localhost).
C<bin> is required. C<need_interpreter> boolean will tell if the C<bin>
is actually a source code where needs invoke _python_ interpreter.

=cut

sub single_node ($self, $bin) {
    #my ($self, $bin) = @_;
    die unless $bin;
    $bin = 'python3 ' . $bin if $self->need_interpreter;
    sprintf "%s %s", $self->mpirun, $bin;
}

=head2 all_nodes

 all_nodes($bin);

Prepares and returns the command to run as string for
 all the nodes in the cluster.
C<bin> is required.
C<need_interpreter> boolean will tell if the C<bin> is actually
a source code where needs invoke _python_ interpreter.
TODO: improve the identification of the C<bin>

=cut

sub all_nodes ($self, $bin) {
    #my ($self, $bin) = @_;
    die unless $bin;
    my @cluster_nodes = $self->cluster_names();
    my $nodes = join(',', @cluster_nodes);
    $bin = 'python3 ' . $bin if $self->need_interpreter;
    sprintf "%s --host %s %s", $self->mpirun, $nodes, $bin;
}

1;
