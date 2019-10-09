=head1 s390base

Helper functions for s390 console tests

=cut
# SUSE’s openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: helper functions for s390 console tests

package s390base;
use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;

=head2 copy_testsuite

 copy_testsuite($tc);

Fetch the testcase and common libraries from openQA server.
The parameter C<$tc> is the name of testcase and common library. 
It is the part of script path '$script_path'.

=cut
sub copy_testsuite {
    my ($self, $tc) = @_;
    select_console 'root-console';


    # fetch the testcase and common libraries from openQA server
    my $path        = data_url("s390x");
    my $script_path = "$path/$tc/$tc.tgz";
    assert_script_run "mkdir -p ./$tc/ && cd ./$tc/ && rm -f $tc.tgz";
    assert_script_run "wget $script_path";
    assert_script_run "tar -xf $tc.tgz";
    my $commonsh_path = "$path/lib/common.tgz";
    assert_script_run "mkdir -p lib && cd lib && rm -f common.tgz";
    assert_script_run "wget $commonsh_path";
    assert_script_run "tar -xf common.tgz";
    assert_script_run "cd ..";
    assert_script_run "chmod +x ./*.sh";
    save_screenshot;
}

=head2 execute_script

 execute_script($script, $scriptargs, $timeout);

Execute C<$script> with arguments C<$scriptargs> and upload STDERR and STDOUT as script logs.
The maximum execution time of the script is defined by C<$timeout>.
=cut
sub execute_script {
    my ($self, $script, $scriptargs, $timeout) = @_;
    assert_script_run("./$script $scriptargs  >> $script.log 2>&1", timeout => $timeout);
    save_screenshot;
    upload_logs "$script.log";
}

=head2 cleanup_testsuite

 cleanup_testsuite();

Currently it just returns value 1. 
It should be able to remove files saved at ./tmp

See https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/8634

=cut
sub cleanup_testsuite {
    return 1;
    # FIXME assert_script_run 'cd / && rm -rf ./tmp';
}


1;
# vim: set sw=4 et:
