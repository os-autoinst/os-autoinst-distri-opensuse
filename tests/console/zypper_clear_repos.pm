# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;

sub run() {
    my $self = shift;
    select_console 'root-console';

    # remove Factory repos
    my $repos_folder = '/etc/zypp/repos.d';
    assert_script_run("find $repos_folder/*.repo -type f -exec grep -q 'baseurl=http://download.opensuse.org/' {} \\; -delete && echo 'unneed_repos_removed' > /dev/$serialdev", 15);
    script_run("zypper lr -d");
    save_screenshot;    # take a screenshot after repos removed
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
