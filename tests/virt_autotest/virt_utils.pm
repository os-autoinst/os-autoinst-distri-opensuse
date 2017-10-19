# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package virt_utils;
# Summary: virt_utils: The initial version of virtualization automation test in openqa.
#          This file provides fundamental utilities.
# Maintainer: alice <xlai@suse.com>

use base Exporter;
use Exporter;
use strict;
use warnings;
use File::Basename;
use testapi;
use Data::Dumper;
use XML::Writer;
use IO::File;
use proxymode;
use virt_autotest_base;

our @EXPORT = qw(repl_repo_in_sourcefile);

sub get_version_for_daily_build_guest {
    my $version = '';
    if (get_var('REPO_0_TO_INSTALL', '')) {
        $version = get_var('TARGET_DEVELOPING_VERSION', '');
    }
    else {
        $version = get_var("VERSION", '');
    }
    $version = lc($version);
    if ($version !~ /sp/m) {
        $version = $version . "-fcs";
    }
    return $version;
}

sub repl_repo_in_sourcefile {
    # Replace the daily build repo as guest installation resource in source file (like source.cn; source.de ..)
    my $veritem = "source.http.sles-" . get_version_for_daily_build_guest . "-64";
    if (get_var("REPO_0")) {
        my $location = &virt_autotest_base::execute_script_run("", "perl /usr/share/qa/tools/location_detect_impl.pl", 60);
        $location =~ s/[\r\n]+$//;
        my $soucefile = "/usr/share/qa/virtautolib/data/" . "sources." . "$location";
        my $newrepo   = "http://openqa.suse.de/assets/repo/" . get_var("REPO_0");
        my $shell_cmd
          = "if grep $veritem $soucefile >> /dev/null;then sed -i \"s#$veritem=.*#$veritem=$newrepo#\" $soucefile;else echo \"$veritem=$newrepo\" >> $soucefile;fi";
        assert_script_run($shell_cmd);
        assert_script_run("grep \"$veritem\" $soucefile");
    }
    else {
        print "Do not need to change resource for $veritem item\n";
    }
}

1;

