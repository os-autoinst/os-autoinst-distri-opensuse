package susedistribution;
use base 'distribution';
use serial_terminal ();
use strict;
use utils 'type_string_slow';
use utils 'ensure_unlocked_desktop';

# Base class implementation of distribution class necessary for testapi

# don't import script_run - it will overwrite script_run from distribution and create a recursion
use testapi qw(send_key %cmd assert_screen check_screen check_var get_var save_screenshot
  match_has_tag set_var type_password type_string wait_idle wait_serial
  mouse_hide send_key_until_needlematch record_info
  wait_still_screen wait_screen_change get_required_var diag);


sub handle_password_prompt {
    if (!get_var("LIVETEST") && !get_var('LIVECD')) {
        assert_screen "password-prompt";
        type_password;
        send_key('ret');
    }
}

sub init {
    my ($self) = @_;

    $self->SUPER::init();
    $self->init_cmd();
    $self->init_consoles();
}

sub init_cmd {
    my ($self) = @_;

    ## keyboard cmd vars
    %testapi::cmd = qw(
      next alt-n
      xnext alt-n
      install alt-i
      update alt-u
      finish alt-f
      accept alt-a
      ok alt-o
      continue alt-o
      createpartsetup alt-c
      custompart alt-c
      addpart alt-d
      donotformat alt-d
      addraid alt-i
      add alt-a
      raid0 alt-0
      raid1 alt-1
      raid5 alt-5
      raid6 alt-6
      raid10 alt-i
      mountpoint alt-m
      filesystem alt-s
      expertpartitioner alt-e
      encrypt alt-e
      resize alt-i
      acceptlicense alt-a
      instdetails alt-d
      rebootnow alt-n
      otherrootpw alt-s
      noautologin alt-a
      change alt-c
      software s
      package p
      bootloader b
    );

    if (check_var('INSTLANG', "de_DE")) {
        $testapi::cmd{next}            = "alt-w";
        $testapi::cmd{createpartsetup} = "alt-e";
        $testapi::cmd{custompart}      = "alt-b";
        $testapi::cmd{addpart}         = "alt-h";
        $testapi::cmd{finish}          = "alt-b";
        $testapi::cmd{accept}          = "alt-r";
        $testapi::cmd{donotformat}     = "alt-n";
        $testapi::cmd{add}             = "alt-h";

        #	$testapi::cmd{raid6}="alt-d"; 11.2 only
        $testapi::cmd{raid10}      = "alt-r";
        $testapi::cmd{mountpoint}  = "alt-e";
        $testapi::cmd{rebootnow}   = "alt-j";
        $testapi::cmd{otherrootpw} = "alt-e";
        $testapi::cmd{change}      = "alt-n";
        $testapi::cmd{software}    = "w";
    }
    if (check_var('INSTLANG', "es_ES")) {
        $testapi::cmd{next} = "alt-i";
    }
    if (check_var('INSTLANG', "fr_FR")) {
        $testapi::cmd{next} = "alt-s";
    }
    ## keyboard cmd vars end
}

sub x11_start_program($$$) {
    my ($self, $program, $timeout, $options) = @_;
    # enable valid option as default
    $options->{valid} //= 1;
    die "no desktop-runner available on minimalx" if check_var('DESKTOP', 'minimalx');
    send_key 'alt-f2';
    mouse_hide(1);
    if (!check_screen('desktop-runner', $timeout)) {
        record_info('workaround', 'desktop-runner does not show up on alt-f2, retrying up to three times (see bsc#978027)');
        send_key 'esc';    # To avoid failing needle on missing 'alt' key - poo#20608
        send_key_until_needlematch 'desktop-runner', 'alt-f2', 3, 10;
    }
    # krunner may use auto-completion which sometimes gets confused by
    # too fast typing or looses characters because of the load caused (also
    # see below). See https://progress.opensuse.org/issues/18200
    if (check_var('DESKTOP', 'kde')) {
        type_string_slow $program;
    }
    else {
        type_string $program;
    }
    wait_still_screen(1);
    if ($options->{terminal}) {
        wait_screen_change { send_key 'alt-t' };
    }
    save_screenshot;
    send_key 'ret';
    wait_still_screen unless $options->{no_wait};
    # lrunner has auto-completion feature, sometimes it causes high load while
    # typing and the following 'ret' fails to work
    # make sure desktop runner executed and closed when have had valid value
    # exec x11_start_program( $program, $timeout, { valid => 1 } );
    if ($options->{valid}) {
        for (1 .. 3) {
            last unless check_screen 'desktop-runner-border', 2;
            wait_screen_change {
                send_key 'ret';
            };
        }
    }
}

sub ensure_installed {
    my ($self, $pkgs, %args) = @_;
    my $pkglist = ref $pkgs eq 'ARRAY' ? join ' ', @$pkgs : $pkgs;
    $args{timeout} //= 90;

    testapi::x11_start_program("xterm");
    assert_screen('xterm');
    testapi::assert_script_sudo("chown $testapi::username /dev/$testapi::serialdev");
    my $retries = 5;    # arbitrary

    # make sure packagekit service is available
    testapi::assert_script_sudo('systemctl is-active -q packagekit || (systemctl unmask -q packagekit ; systemctl start -q packagekit)');
    $self->script_run(
"for i in {1..$retries} ; do pkcon install $pkglist && break ; done ; RET=\$?; echo \"\n  pkcon finished\n\"; echo \"pkcon-\${RET}-\" > /dev/$testapi::serialdev",
        0
    );
    my @tags = qw(Policykit Policykit-behind-window pkcon-proceed-prompt pkcon-finished);
    while (1) {
        last unless @tags;
        my $ret = check_screen(\@tags, $args{timeout});
        last unless $ret;
        last if (match_has_tag('pkcon-finished'));
        if (match_has_tag('Policykit')) {
            type_password;
            send_key("ret", 1);
            @tags = grep { $_ ne 'Policykit' } @tags;
            @tags = grep { $_ ne 'Policykit-behind-window' } @tags;
            next;
        }
        if (match_has_tag('Policykit-behind-window')) {
            send_key("alt-tab");
            sleep 3;
            next;
        }
        if (match_has_tag('pkcon-proceed-prompt')) {
            send_key("y");
            send_key("ret");
            @tags = grep { $_ ne 'pkcon-proceed-prompt' } @tags;
            next;
        }
    }
    wait_serial('pkcon-0-', 27) || die "pkcon install did not succeed";
    send_key("alt-f4");    # close xterm
}

sub script_sudo($$) {
    my ($self, $prog, $wait) = @_;

    my $str = time;
    if ($wait > 0) {
        $prog = "$prog; echo $str-\$?- > /dev/$testapi::serialdev";
    }
    type_string "clear\n";    # poo#13710
    type_string "su -c \'$prog\'\n";
    handle_password_prompt;
    if ($wait > 0) {
        return wait_serial("$str-\\d+-");
    }
    return;
}

# simplified but still colored prompt for better readability
sub set_standard_prompt {
    my ($self, $user) = @_;
    $user ||= $testapi::username;
    my $prompt_sign = $user eq 'root' ? '#' : '$';
    type_string "which tput 2>&1 && PS1=\"\\\[\$(tput bold 2; tput setaf 1)\\\]$prompt_sign\\\[\$(tput sgr0)\\\] \"\n";
}

sub become_root {
    my ($self) = @_;

    $self->script_sudo('bash', 0);
    type_string "whoami > /dev/$testapi::serialdev\n";
    wait_serial("root", 10) || die "Root prompt not there";
    type_string "cd /tmp\n";
    $self->set_standard_prompt('root');
    type_string "clear\n";
}

# initialize the consoles needed during our tests
sub init_consoles {
    my ($self) = @_;

    # avoid complex boolean logic by setting interim variables
    if (check_var('BACKEND', 'svirt')) {
        if (check_var('ARCH', 's390x')) {
            set_var('S390_ZKVM',         1);
            set_var('SVIRT_VNC_CONSOLE', 'x11');
        }
    }

    if (check_var('BACKEND', 'qemu')) {
        $self->add_console('root-virtio-terminal', 'virtio-terminal', {});
    }

    # svirt backend, except s390x ARCH
    if (!get_var('S390_ZKVM') and check_var('BACKEND', 'svirt')) {
        my $hostname = get_var('VIRSH_GUEST');
        my $port = get_var('VIRSH_INSTANCE', 1) + 5900;

        $self->add_console(
            'sut',
            'vnc-base',
            {
                hostname => $hostname,
                port     => $port,
                password => $testapi::password
            });
        set_var('SVIRT_VNC_CONSOLE', 'sut');
    }

    if (get_var('BACKEND', '') =~ /qemu|ikvm|generalhw/
        || (check_var('BACKEND', 'svirt') && !get_var('S390_ZKVM')))
    {
        $self->add_console('install-shell',  'tty-console', {tty => 2});
        $self->add_console('installation',   'tty-console', {tty => check_var('VIDEOMODE', 'text') ? 1 : 7});
        $self->add_console('install-shell2', 'tty-console', {tty => 9});
        $self->add_console('root-console',   'tty-console', {tty => 2});
        $self->add_console('user-console',   'tty-console', {tty => 4});
        $self->add_console('log-console',    'tty-console', {tty => 5});
        $self->add_console('x11',            'tty-console', {tty => 7});
    }

    if (check_var('BACKEND', 'ikvm') || check_var('BACKEND', 'ipmi')) {
        $self->add_console(
            'root-ssh',
            'ssh-xterm',
            {
                hostname => get_required_var('SUT_IP'),
                password => $testapi::password,
                user     => 'root',
                serial   => 'mkfifo /dev/sshserial; tail -f /dev/sshserial'
            });
    }

    if (check_var('BACKEND', 'ipmi') || check_var('BACKEND', 's390x') || get_var('S390_ZKVM')) {
        my $hostname;

        $hostname = get_var('VIRSH_GUEST') if get_var('S390_ZKVM');
        $hostname = get_required_var('SUT_IP') if check_var('BACKEND', 'ipmi');

        if (check_var('BACKEND', 's390x')) {

            # expand the S390 params
            my $s390_params = get_var("S390_NETWORK_PARAMS");
            my $s390_host   = get_required_var('S390_HOST');
            $s390_params =~ s,\@S390_HOST\@,$s390_host,g;
            set_var("S390_NETWORK_PARAMS", $s390_params);

            ($hostname) = $s390_params =~ /Hostname=(\S+)/;
        }

        if (check_var("VIDEOMODE", "text")) {    # adds console for text-based installation on s390x
            $self->add_console(
                'installation',
                'ssh-xterm',
                {
                    hostname => $hostname,
                    password => $testapi::password,
                    user     => 'root'
                });
        }
        elsif (check_var("VIDEOMODE", "ssh-x")) {
            $self->add_console(
                'installation',
                'ssh-xterm',
                {
                    hostname => $hostname,
                    password => $testapi::password,
                    user     => 'root',
                    gui      => 1
                });
        }
        else {
            $self->add_console(
                'installation',
                'vnc-base',
                {
                    hostname => $hostname,
                    port     => 5901,
                    password => $testapi::password
                });
        }
        $self->add_console(
            'x11',
            'vnc-base',
            {
                hostname => $hostname,
                port     => 5901,
                password => $testapi::password
            });
        $self->add_console(
            'iucvconn',
            'ssh-iucvconn',
            {
                hostname => $hostname,
                password => $testapi::password
            });

        $self->add_console(
            'install-shell',
            'ssh-xterm',
            {
                hostname => $hostname,
                password => $testapi::password,
                user     => 'root'
            });
        $self->add_console(
            'root-console',
            'ssh-xterm',
            {
                hostname => $hostname,
                password => $testapi::password,
                user     => 'root'
            });
        $self->add_console(
            'user-console',
            'ssh-xterm',
            {
                hostname => $hostname,
                password => $testapi::password,
                user     => $testapi::username
            });
        $self->add_console(
            'log-console',
            'ssh-xterm',
            {
                hostname => $hostname,
                password => $testapi::password,
                user     => 'root'
            });
    }

    return;
}

# Make sure the right user is logged in, e.g. when using remote shells
sub ensure_user {
    my ($user) = @_;
    type_string("su - $user\n") if $user ne 'root';
}

# callback whenever a console is selected for the first time
sub activate_console {
    my ($self, $console) = @_;

    if ($console eq 'install-shell') {
        if (get_var("LIVECD")) {
            # LIVE CDa do not run inst-consoles as started by inst-linux (it's regular live run, auto-starting yast live installer)
            assert_screen "text-login", 10;
            # login as root, who does not have a password on Live-CDs
            type_string "root\n";
            sleep 1;
        }
        else {
            # on s390x we need to login here by providing a password
            handle_password_prompt if (check_var('ARCH', 's390x') || check_var('BACKEND', 'ipmi'));
            assert_screen "inst-console";
        }
    }

    $console =~ m/^(\w+)-(console|virtio-terminal|ssh)/;
    my ($name, $user, $type) = ($1, $1, $2);
    $name = $user //= '';
    $type //= '';
    if ($name eq 'user') {
        $user = $testapi::username;
    }
    elsif ($name eq 'log') {
        $user = 'root';
    }

    diag "activate_console, console: $console, type: $type";
    if ($type eq 'console') {
        # different handling for ssh consoles on s390x zVM
        if (check_var('BACKEND', 's390x') || get_var('S390_ZKVM')) {
            diag "backend s390x || zkvm";
            handle_password_prompt;
            ensure_user($user);
        }
        else {
            my $nr = 4;
            $nr = 2 if ($name eq 'root');
            $nr = 5 if ($name eq 'log');
            my @tags = ("tty$nr-selected", "text-logged-in-$user", "text-login");
            # s390 zkvm uses a remote ssh session which is root by default so
            # search for that and su to user later if necessary
            push(@tags, 'text-logged-in-root') if get_var('S390_ZKVM');
            # we need to wait more than five seconds here to pass the idle timeout in
            # case the system is still booting (https://bugzilla.novell.com/show_bug.cgi?id=895602)
            # or when using remote consoles which can take some seconds, e.g.
            # just after ssh login
            assert_screen \@tags, 60;
            if (match_has_tag("tty$nr-selected") or match_has_tag("text-login")) {
                type_string "$user\n";
                handle_password_prompt;
            }
            elsif (match_has_tag('text-logged-in-root')) {
                ensure_user($user);
            }
        }
        assert_screen "text-logged-in-$user";
        $self->set_standard_prompt($user);
        assert_screen $console;

        # On s390x 'setterm' binary is not present as there's no linux console
        if (!check_var('ARCH', 's390x')) {
            # Disable console screensaver
            $self->script_run("setterm -blank 0");
        }
    }
    elsif ($type eq 'virtio-terminal') {
        serial_terminal::login($user, $self->{serial_term_prompt});
    }
    elsif ($type eq 'ssh') {
        $user ||= 'root';
        handle_password_prompt;
        ensure_user($user);
        assert_screen(["text-logged-in-$user", "text-login"], 60);
        $self->set_standard_prompt($user);
    }
    elsif ($console eq 'svirt') {
        $self->set_standard_prompt('root');
    }
    elsif (
        $console eq 'installation'
        && (   ((check_var('BACKEND', 's390x') || check_var('BACKEND', 'ipmi') || get_var('S390_ZKVM')))
            && (check_var('VIDEOMODE', 'text') || check_var('VIDEOMODE', 'ssh-x'))))
    {
        diag 'activate_console called with installation for ssh based consoles';
        $user ||= 'root';
        handle_password_prompt;
        ensure_user($user);
        assert_screen "text-logged-in-$user", 60;
    }
    else {
        diag 'activate_console called with generic type, no action';
    }
}

=head2 console_selected

    console_selected($console [, await_console => $await_console] [, tags => $tags ] [, ignore => $ignore ]);

Overrides C<select_console> callback from C<testapi>. Waits for console by
calling assert_screen on C<tags>, by default the name of the selected console.

C<await_console> is set to 1 by default. Can be set to 0 to skip the check for
the console. Call for example
C<select_console('root-console', await_console => 0)> if there should be no
checking for the console to be shown. Useful when the check should or must be
test module specific.

C<ignore> can be overridden to not check on certain consoles. By default the
known uncheckable consoles are already ignored.

=cut

sub console_selected {
    my ($self, $console, %args) = @_;
    $args{await_console} //= 1;
    $args{tags}          //= $console;
    $args{ignore}        //= qr{sut|root-virtio-terminal|iucvconn|svirt|root-ssh};
    return unless $args{await_console};
    return if $args{tags} =~ $args{ignore};
    # x11 needs special handling because we can not easily know if screen is
    # locked, display manager is waiting for login, etc.
    return ensure_unlocked_desktop if $args{tags} =~ /x11/;
    assert_screen($args{tags}, no_wait => 1);
}

1;
# vim: set sw=4 et:
