use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    become_root;

    type_string "PS1=\"# \"\n";
    # remove Factory repos
    my $repos_folder = '/etc/zypp/repos.d';
    script_run("find $repos_folder/*.repo -type f -exec grep -q 'baseurl=http://download.opensuse.org/' {} \\; -delete && echo 'unneed_repos_removed' > /dev/$serialdev", 5);
    wait_serial("unneed_repos_removed", 10) || die "remove unneed repos failed";
    script_run("zypper lr -d");
    save_screenshot; # take a screenshot after repos removed

    type_string "exit\n";
}

sub test_flags() {
    return { important => 1, };
}

1;
# vim: set sw=4 et:
