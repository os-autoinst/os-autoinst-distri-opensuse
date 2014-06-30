use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    become_root;

    type_string "PS1=\"# \"\n";
    script_run("killall gpk-update-icon kpackagekitsmarticon packagekitd");
    sleep 2;
    script_run("zypper lr");
    script_run("zypper ref");
    script_run('echo $?');
    assert_screen("zypper_ref");
    type_string "exit\n";
}

sub test_flags() {
    return { 'important' => 1, 'milestone' => 1, };
}

1;
# vim: set sw=4 et:
