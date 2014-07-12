use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    become_root;

    type_string "PS1=\"# \"\n";
    script_run("killall gpk-update-icon kpackagekitsmarticon packagekitd");
    script_run("zypper lr -d");
    save_screenshot; # take a screenshot before any changes
    send_key "ctrl-l";
    if ( $vars{FLAVOR} =~ m/^Staging2?[\-]DVD$/ && $vars{SUSEMIRROR} ) {
        # remove Factory repos
        my $repos_folder = '/etc/zypp/repos.d';
        script_run("find $repos_folder/*.repo -type f -exec grep -q 'baseurl=http://download.opensuse.org/' {} \\; -delete", 5);
        script_run("zypper lr -d");
        save_screenshot; # take a screenshot after repos removed
    }
    if ( !$vars{NET} && !$vars{TUMBLEWEED} && !$vars{EVERGREEN} && $vars{SUSEMIRROR} && !$vars{FLAVOR} =~ m/^Staging2?[\-]DVD$/ ) {
        # non-NET installs have only milestone repo, which might be incompatible.
        my $repourl = 'http://' . $vars{SUSEMIRROR};
        unless ( $vars{FULLURL} ) {
            $repourl = $repourl . "/repo/oss";
        }
        script_run("zypper ar -c $repourl Factory && echo 'worked' > /dev/$serialdev");
        wait_serial "worked", 10  || die "zypper failed";
        script_run("zypper lr -d");
        save_screenshot; # take a screenshot after the repo added
    }
    # kill packagekit again before refresh repos
    script_run("killall gpk-update-icon kpackagekitsmarticon packagekitd");
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
