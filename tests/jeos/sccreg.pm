use base "opensusebasetest";
use strict;
use testapi;
use ttylogin;

sub run() {
    my $sccmail = get_var("SCC_EMAIL");
    my $scccode = get_var("SCC_REGCODE");

    assert_script_run "SUSEConnect --url=https://scc.suse.com -e $sccmail -r $scccode";
    script_run 'exit'; # leave root
}

sub test_flags() {
    return { 'important' => 1 };
}

1;
# vim: set sw=4 et:
