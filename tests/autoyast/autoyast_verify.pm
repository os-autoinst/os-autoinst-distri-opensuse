# Copyright (C) 2015-2017 SUSE LLC
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
#
# Summary: common framework to run verification scripts for systems
#          installed with autoyast
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use strict;
use warnings;
use base 'basetest';
use testapi;
use lockapi;
use utils "zypper_call";

sub expected_failures {
    # Function is used to sof-fail known issues. As long as we use generic
    # framework here, we need to perform additional checks to identify
    # particular test case based on script url
    my ($script_output) = @_;
    if ($script_output =~ /bsc#1046605/) {
        record_soft_failure('bsc#1046605');
    }
}

sub run {
    my $self = shift;
    $self->result('fail');    # default result
    my $success = 0;
    # make sure that curl has been installed
    zypper_call("in curl", timeout => 180);
    #wait for supportserver if not yet ready
    my $roles_r = get_var_array('SUPPORT_SERVER_ROLES');
    foreach my $role (@$roles_r) {
        #printf("rolemutex=$role\n");#debug
        mutex_lock($role);
        mutex_unlock($role);
    }

    my $verify_url = get_var('AUTOYAST_VERIFY');
    if ($verify_url =~ /^aytests\//) {
        die "aytests-tests package require PXEBOOT" unless get_var("PXEBOOT");
    }
    else {
        $verify_url = 'data/' . $verify_url;
    }
    if (get_var("PXEBOOT")) {
        my $proto = get_var("PROTO") || 'http';
        $verify_url = "$proto://10.0.2.1/" . $verify_url;
    }
    else {
        $verify_url = autoinst_url() . '/' . $verify_url;
    }

    if ($verify_url =~ /\.list$/) {
        # list of tests
        my $verify_url_base = $verify_url;
        $verify_url_base =~ s/\/[^\/]*$//;

        my $res = script_output('
        set +x -e

        curl "' . $verify_url . '" > verify.list
        while read testname || [ -n "$testname" ] ; do
            echo
            echo
            echo "Test script: $testname "
            testname=`echo ${testname%%#*}`
            curl "' . $verify_url_base . '/$testname" > $testname
            chmod 755 $testname
            echo "==========================================================="
            cat $testname
            echo "==========================================================="
            ./$testname 2>&1 |tee ./$testname.output.txt
            if ! grep -q "^AUTOYAST OK" $testname.output.txt ; then
              echo "Test $testname failed."
              exit 1
            fi
        done < verify.list
        echo ALL_TESTS_OK
        ');
        $success = 1 if $res =~ /ALL_TESTS_OK/;
        print $res;
    }
    elsif ($verify_url =~ /\.sh$/) {
        # single sh script
        my $res = script_output('
        set -x -e

        curl "' . $verify_url . '" > verify.sh
        chmod 755 verify.sh
        ./verify.sh
        ');
        $success = 1 if $res =~ /AUTOYAST OK/;
        # Soft-fail known bugs
        expected_failures($res);
    }

    save_screenshot;
    die 'verification script failed' unless $success;
    $self->result('ok');
}

1;

