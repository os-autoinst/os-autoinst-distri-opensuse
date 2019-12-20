# Copyright © 2019-2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package main_pods;
use base 'Exporter';
use Exporter;
use testapi 'get_var';
use autotest;
use LTP::TestInfo 'testinfo';
use main_common qw(boot_hdd_image load_shutdown_tests);
use Mojo::File 'path';
use strict;
use warnings;

our @EXPORT = qw(parse_pod_list is_pod_test load_pod_tests);

sub loadtest_pod {
    my ($test, %args) = @_;
    autotest::loadtest("tests/qa_automation/$test.pm", %args);
}

sub parse_pod_list {
    my $run_pods = get_var('TEST_POD_LIST');
    my @pod_list;

    if ($run_pods eq '*') {
        my $path = get_var('CASEDIR') . '/tests/test_pods';

        for my $file (@{path($path)->list}) {
            push @pod_list, $file->basename if -x $file->stat;
        }
    }
    else {
        @pod_list = split /,/, $run_pods;
    }

    return \@pod_list;
}

sub is_pod_test {
    return get_var('TEST_POD_LIST');
}

sub load_pod_tests {
    my $pod_list = parse_pod_list;

    boot_hdd_image;
    my $tinfo = testinfo({}, test => $pod_list);
    loadtest_pod('deploy_pods', run_args => $tinfo);

    for my $pod (@$pod_list) {
        $tinfo = testinfo({}, test => $pod);
        my $title = $pod =~ s/\./_/gr;
        loadtest_pod('run_pod', name => $title, run_args => $tinfo);
    }

    load_shutdown_tests;
}

1;
