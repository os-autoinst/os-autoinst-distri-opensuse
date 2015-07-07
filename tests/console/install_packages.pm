use base "consoletest";
use testapi;

sub run() {
    become_root();

    my $packages = get_var("INSTALL_PACKAGES");

    assert_script_run("zypper -n in -l $packages");
    assert_script_run("rpm -q $packages | tee /dev/$serialdev");

    script_run('exit');
}

sub test_flags() {
    return { 'fatal' => 1, };
}

1;
# vim: set sw=4 et:
