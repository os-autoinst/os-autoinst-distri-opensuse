# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Download repositores from the internal server
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base 'consoletest';
use registration;
use warnings;
use testapi;
use strict;
use utils;

sub run {
    my ($self, $args) = @_;
    select_console 'tunnel-console';

    assert_script_run("mkdir ~/repos");
    assert_script_run("cd ~/repos");

    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO')) unless get_var('MAINT_TEST_REPO');
    my @repos = split(/,/, get_var('MAINT_TEST_REPO'));
    assert_script_run('touch /tmp/repos.list.txt');

    my $ret = 0;
    for my $maintrepo (@repos) {
        next if $maintrepo !~ m/^http/;
        my ($parent) = $maintrepo =~ 'https?://(.*)$';
        my ($domain) = $parent    =~ '^([a-zA-Z.]*)';
        $ret = script_run "wget --no-clobber -r -R 'robots.txt,*.ico,*.png,*.gif,*.css,*.js,*.htm*' --domains $domain --no-parent $parent $maintrepo", timeout => 600;
        if ($ret !~ /0|8/) {
            die "wget error: The $maintrepo download failed with $ret return code.";
        }
        assert_script_run("echo -en '# $maintrepo:\\n\\n' >> /tmp/repos.list.txt");
        assert_script_run("sed -i \"1 s/\\]/_\$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 4)]/\" $parent*.repo");
        assert_script_run("find $parent >> /tmp/repos.list.txt");
    }

    upload_logs('/tmp/repos.list.txt');
    assert_script_run("cd ~/");
}

sub test_flags {
    return {
        fatal                    => 1,
        milestone                => 1,
        publiccloud_multi_module => 1
    };
}

1;

