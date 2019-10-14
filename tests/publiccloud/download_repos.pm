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

    my $domain = '';
    my @repos  = split(/,/, get_var('INCIDENT_REPO'));
    assert_script_run("mkdir ~/repos");
    assert_script_run("cd ~/repos");
    for my $maintrepo (@repos) {
        my ($parent) = $maintrepo =~ 'https?://(.*)$';
        my ($domain) = $parent =~ '^([a-zA-Z.]*)';
        assert_script_run("wget --no-clobber -r -R 'robots.txt,*.ico,*.png,*.gif,*.css,*.js,*.htm*' --domains $domain --no-parent $parent $maintrepo", timeout => 600);
        assert_script_run("echo -en '# $maintrepo:\\n\\n' >> /tmp/repos.list.txt");
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

