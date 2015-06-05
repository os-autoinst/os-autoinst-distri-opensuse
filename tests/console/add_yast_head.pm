use base "consoletest";
use testapi;

# Used only in the yast branch of the distri.
# See also console/install_yast_head

sub run() {
    my $self = shift;

    my $repo_url = get_var("VERSION");
    $repo_url = "13.2_Update" if ($repo_url eq "13.2");
    $repo_url = "Factory" if ($repo_url eq "Tumbleweed");
    $repo_url = "http://download.opensuse.org/repositories/YaST:/Head/openSUSE_$repo_url/";

    become_root;
    script_run "zypper ar $repo_url YaST:Head | tee /dev/$serialdev";
    wait_serial("successfully added", 20);
}

sub test_flags() {
    return { 'important' => 1, 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
