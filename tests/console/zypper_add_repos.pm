use base "consoletest";
use testapi;

sub run() {
    become_root();

    my $val = get_var("ZYPPER_ADD_REPOS");
    return unless $val;

    my $i = 0;
    for my $url (split(/,/, $val)) {
        assert_script_run("zypper -n ar -c -f $url openqa$i");
        ++$i;
    }

    script_run('exit');
}

sub test_flags() {
    return { 'fatal' => 1, };
}

1;
# vim: set sw=4 et:
