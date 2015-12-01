use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    become_root;
    # non-NET installs have only milestone repo, which might be incompatible.
    my $repourl = 'http://' . get_var("SUSEMIRROR");
    unless (get_var("FULLURL")) {
        $repourl = $repourl . "/repo/oss";
    }
    type_string "zypper ar -c $repourl Factory; echo zypper-ar-done-\$? > /dev/$serialdev\n";
    wait_serial("zypper-ar-done-0") || die "zypper ar failed";
    type_string "zypper lr\n";
    assert_screen "addn-repos-listed";

    type_string "exit\n";
}

sub test_flags() {
    return {important => 1,};
}

1;
# vim: set sw=4 et:
