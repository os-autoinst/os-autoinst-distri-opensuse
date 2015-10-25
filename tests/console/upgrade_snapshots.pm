use base 'consoletest';
use testapi;

# fate#317900: Create snapshot before starting Upgrade

sub run() {
    become_root();

    script_run("snapper list | tee /dev/$serialdev");
    # Check if the snapshot called 'before update' is there
    wait_serial('pre\s*(\|[^|]*){4}\s*\|\s*number\s*\|\s*before update\s*\|\s*important=yes', 5) || die 'upgrade snapshots test failed';

    script_run("snapper list | tee /dev/$serialdev");
    # Check if the snapshot called 'after update' is there
    wait_serial('post\s*(\|[^|]*){4}\s*\|\s*number\s*\|\s*after update\s*\|\s*important=yes', 5) || die 'upgrade snapshots test failed';

    script_run('exit');
    send_key 'ctrl-l';
}

sub test_flags() {
    return { important => 1 };
}

1;
# vim: set sw=4 et:
