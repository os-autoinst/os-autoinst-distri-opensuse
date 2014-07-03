use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    become_root;

    type_string "PS1=\"# \"\n";
    script_run("killall gpk-update-icon kpackagekitsmarticon packagekitd");
    sleep 2;
    if ( !$vars{NET} && !$vars{TUMBLEWEED} && !$vars{EVERGREEN} && $vars{SUSEMIRROR} ) {
        # non-NET installs have only milestone repo, which might be incompatible.
        my $repourl = 'http://' . $vars{SUSEMIRROR};
        unless ( $vars{FULLURL} ) {
            $repourl = $repourl . "/repo/oss";
        }
        script_run("zypper ar -c $repourl Factory && echo 'worked' > /dev/$serialdev");
        wait_serial "worked", 10  || die "zypper failed";
    }
    script_run("zypper lr");
    save_screenshot; # take a screenshot after the staging repo added
    if ( $vars{FLAVOR} =~ m/^Staging2?[\-]DVD$/ ) {
        # remove Factory repos
        my $repos_folder = '/etc/zypp/repos.d';
        foreach my $repo_file (<$repos_folder/*.repo>) {
            open(my $fh, '<', $repo_file) or die "Could not open file $repo_file !";
            foreach my $row (<$fh>) {
                unlink $repo_file if $row =~ m/^baseurl=https?:\/\/download\.opensuse\.org/;
            }
        }
        script_run("zypper lr -d");
        save_screenshot; # take a screenshot after Factory repos removed
    }
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
