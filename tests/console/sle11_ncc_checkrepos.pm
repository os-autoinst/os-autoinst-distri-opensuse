use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    my $script = 'zypper lr | tee zypper_lr.txt';
    validate_script_output $script, sub { m/nu_novell_com/ };    # need a better output validation here

    # upload the output of repos
    type_string "clear\n";
    upload_logs "zypper_lr.txt";
    assert_screen "zypper_lr-log-uploaded";
}

1;
# vim: set sw=4 et:
