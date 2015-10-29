use base "consoletest";
use testapi;

sub run() {
    my $val = get_var("ZYPPER_ADD_REPOS");
    return unless $val;

    become_root();

    my $prefix = get_var("ZYPPER_ADD_REPO_PREFIX") || 'openqa';

    my $i = 0;
    for my $url (split(/,/, $val)) {
        assert_script_run("zypper -n ar -c -f $url $prefix$i");
        ++$i;
    }

    script_run('exit');
}

sub test_flags() {
    return {fatal => 1,};
}

1;
# vim: set sw=4 et:
