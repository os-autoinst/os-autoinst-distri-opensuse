# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic functions for testing vmstat.
# Maintainer: QE Core <qe-core@suse.de>

package console::vmstat_utils;
use base Exporter;
use Exporter;
use base "consoletest";
use testapi;
use strict;
use warnings;
use List::Util qw(sum);
our @EXPORT = qw(read_memory_cpu average);

=head2 read_memory_cpu

 read_memory_cpu("/tmp/file.log")
 Input :  File which contains vmstat output.
 Returns a list with two array references which maps to amount of idle memory and CPU usage from the vmstat output log file.

=cut
sub read_memory_cpu {

    my $file_name = shift;
    my @res_mem   = split '\n', script_output "awk '{print \$4}' $file_name";
    my @mem_num   = map { $_ =~ m/\d+/ } @res_mem;
    my @res_cpu   = split '\n', script_output "awk '{print \$13}' $file_name";
    my @cpu_num   = map { $_ =~ m/\d+/ } @res_cpu;
    return (\@mem_num, \@cpu_num);
}
=head2 average

 average([1,2,4,5])
 Input:  Array of numbers.
 Returns the average of numbers.

=cut
sub average {
    my @a    = @_;
    my $size = @a;
    return sum(@a) / $size;
}

1;
