use base "opensusebasetest";
use testapi;

# for https://bugzilla.novell.com/show_bug.cgi?id=679459

sub run() {
    my $self = shift;
    script_run("cd /tmp ; wget -q openqa.opensuse.org/opensuse/qatests/qa_syslinux.sh");
    send_key "ctrl-l";
    script_sudo("sh -x qa_syslinux.sh");
    assert_screen 'test-syslinux-1', 3;
}

1;
# vim: set sw=4 et:
