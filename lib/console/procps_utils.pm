# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic functions for testing vmstat.
# Maintainer: Deepthi Yadabettu Venkatachala<deepthi.venkatachala@suse.de>
#
package console::procps_utils;

use base Exporter;
use Exporter;

use base "consoletest";
use testapi;
use strict;
use warnings;

our @EXPORT = qw(read_memory_cpu average);

=head2 read_memory_cpu

 read_memory_cpu("/tmp/file.log")
 Input :  File which contains vmstat output.
 Returns a list with two array references which maps to amount of idle memory and CPU usage from the vmstat output log file.

=cut
sub read_memory_cpu {

    my $file_name = shift;
    my @res_mem   = split '\n', script_output "awk '{print \$4}' $file_name";
    my (@mem_num, @cpu_num);
    foreach my $elem (@res_mem) {
        if ($elem =~ m/\d+/) {
            push @mem_num, $elem;
        }
    }
    my @res_cpu = split '\n', script_output "awk '{print \$13}' $file_name";
    foreach my $cpu_elem (@res_cpu) {
        if ($cpu_elem =~ m/\d+/) {
            push @cpu_num, $cpu_elem;
        }
    }
    return (\@mem_num, \@cpu_num);
}
=head2 average

 average([1,2,4,5])
 Input:  Array of numbers.
 Returns the average of numbers.

=cut
sub average {
    my @Array_To_Average = shift;
    my $size             = @Array_To_Average;
    my $total            = 0;
    for (@Array_To_Average)
    {
        $total += $_;
    }

    return $total / $size;
}

1;
