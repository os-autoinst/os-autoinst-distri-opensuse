use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    my $script = 'zypper lr | tee zypper_lr.txt';
    validate_script_output $script, sub { m/nu_novell_com/ };

    type_string "clear\n";
    upload_logs "zypper_lr.txt";
    assert_screen "zypper_lr-log-uploaded";

    # upload y2logs
    script_sudo("save_y2logs /tmp/y2logs.tar.bz2");
    wait_idle(30);
    upload_logs "/tmp/y2logs.tar.bz2";
    save_screenshot;
}

1;
# vim: set sw=4 et:
