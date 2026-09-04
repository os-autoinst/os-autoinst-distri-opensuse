# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: To a transactional-update dup and reboot the node
# Maintainer: Richard Brown <rbrown@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use transactional;
use utils;

sub run {
    select_console 'root-console';

    zypper_call 'mr --all --disable';

    my $defaultrepo;
    if (get_var('SUSEMIRROR')) {
        $defaultrepo = "http://" . get_var("SUSEMIRROR");
    }
    else {
        die "No SUSEMIRROR variable set";
    }

    my $nr = 1;
    foreach my $r (split(/,/, get_var('ZDUPREPOS', $defaultrepo))) {
        zypper_call("--no-gpg-checks ar \"$r\" repo$nr");
        # Workaround to make zypper behaviour more like if it was download.o.o
        script_run("echo \"gpgkey=$r/repodata/repomd.xml.key\" >> /etc/zypp/repos.d/repo$nr.repo");
        $nr++;
    }

    # Work around that for t-u < 5.5.1, selfupdates break key updates (boo#1239721)
    if (script_output('zypper -t vcmp 5.5.1 $(rpm -q --qf %{version} transactional-update)', proceed_on_failure => 1) !~ /-1/) {
        trup_call '--no-selfupdate run zypper ref -f';
    }

    trup_call '-c dup', timeout => 600;

    check_reboot_changes;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
