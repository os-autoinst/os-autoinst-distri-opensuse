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
use testapi;

# Used only in the yast branch of the distri.
# See also console/install_yast_head

sub run() {
    my $self = shift;

    my $repo_url = get_var("VERSION");
    $repo_url = "13.2_Update" if ($repo_url eq "13.2");
    $repo_url = "Factory"     if ($repo_url eq "Tumbleweed");
    $repo_url = "http://download.opensuse.org/repositories/YaST:/Head/openSUSE_$repo_url/";

    select_console 'root-console';
    script_run "zypper ar $repo_url YaST:Head | tee /dev/$serialdev", 0;
    wait_serial("successfully added", 20);
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
