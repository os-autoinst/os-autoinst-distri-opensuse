use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    become_root;

    type_string "PS1=\"# \"\n";
    type_string "yast scc; echo yast-scc-done-\$? > /dev/$serialdev\n";
    assert_screen( "scc-registration", 30 );

    $self->registering_scc;

    wait_serial("yast-scc-done-0") || die "yast scc failed";
    type_string "zypper lr\n";
    assert_screen "scc-repos-listed";

    type_string "exit\n";
}

sub test_flags() {
    return { 'important' => 1, };
}

1;
# vim: set sw=4 et:
