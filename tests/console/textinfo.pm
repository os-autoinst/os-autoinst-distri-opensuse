use base "consoletest";
use strict;
use testapi;

# have various useful general info included in videos
sub run() {
    my $self = shift;
    script_sudo("~/data/textinfo 2>&1 | tee ~/info.txt");
    wait_serial('textinfo_done', 35) || die "textinfo test failed";
    upload_logs("info.txt");
    upload_logs("/tmp/logs.tar.bz2");
    assert_screen "texinfo-logs-uploaded";
}

1;
# vim: set sw=4 et:
