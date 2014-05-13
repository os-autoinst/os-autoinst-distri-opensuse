use base "basetest";
use bmwqemu;

sub is_applicable() {
    return $envs->{DVD};
}

sub run() {
    my $self = shift;

    become_root();
    script_run("grep -l cd:/// /etc/zypp/repos.d/* | xargs rm -v");
    assert_screen "cdreporemoved";
    script_run('exit');
}

sub test_flags() {
    return { 'milestone' => 1 };
}

1;
# vim: set sw=4 et:
