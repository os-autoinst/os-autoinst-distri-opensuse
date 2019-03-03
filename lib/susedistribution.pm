package susedistribution;
use base 'distribution';
use serial_terminal ();
use strict;
use warnings;
use utils qw(
  disable_serial_getty
  ensure_serialdev_permissions
  get_root_console_tty
  get_x11_console_tty
  pkcon_quit
  save_svirt_pty
  type_string_slow
  type_string_very_slow
  zypper_call
);
use version_utils qw(is_hyperv_in_gui is_sle is_leap is_svirt_except_s390x);
use x11utils qw(desktop_runner_hotkey ensure_unlocked_desktop);
use Utils::Backends 'use_ssh_serial_console';

# Base class implementation of distribution class necessary for testapi

# don't import script_run - it will overwrite script_run from distribution and create a recursion
use testapi qw(send_key %cmd assert_screen check_screen check_var get_var save_screenshot
  match_has_tag set_var type_password type_string wait_serial
  mouse_hide send_key_until_needlematch record_info record_soft_failure
  wait_still_screen wait_screen_change get_required_var diag);


sub handle_password_prompt {
    my ($console) = @_;
    $console //= '';

    return if get_var("LIVETEST") || get_var('LIVECD');
    assert_screen "password-prompt";
    if ($console eq 'hyperv-intermediary') {
        type_string get_required_var('VIRSH_GUEST_PASSWORD');
    }
    elsif ($console eq 'svirt') {
        type_string(get_required_var(check_var('VIRSH_VMM_FAMILY', 'hyperv') ? 'HYPERV_PASSWORD' : 'VIRSH_PASSWORD'));
    }
    else {
        type_password;
    }
    send_key('ret');
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
      cancel alt-c
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
      encryptdisk alt-a
      enablelvm alt-e
      resize alt-i
      customsize alt-c
      acceptlicense alt-a
      instdetails alt-d
      rebootnow alt-n
      otherrootpw alt-s
      noautologin alt-a
      change alt-c
      software s
      package p
      bootloader b
      entiredisk alt-e
      guidedsetup alt-d
      rescandevices alt-e
      exp_part_finish alt-f
      size_hotkey alt-s
      sync_interval alt-n
      sync_without_daemon alt-y
      toggle_home alt-p
      raw_volume alt-a
      enable_snapshots alt-n
      system_view alt-s
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

    if (!is_sle('<15') && !is_leap('<15.0')) {
        # SLE15/Leap15 use Chrony instead of ntp
        $testapi::cmd{sync_interval}       = "alt-i";
        $testapi::cmd{sync_without_daemon} = "alt-s";
    }
    ## keyboard cmd vars end
}

sub init_desktop_runner {
    my ($program, $timeout) = @_;
    $timeout //= 30;
    my $hotkey = desktop_runner_hotkey;

    send_key($hotkey);

    mouse_hide(1);
    if (!check_screen('desktop-runner', $timeout)) {
        record_info('workaround', "desktop-runner does not show up on $hotkey, retrying up to three times (see bsc#978027)");
        send_key 'esc';    # To avoid failing needle on missing 'alt' key - poo#20608
        send_key_until_needlematch 'desktop-runner', $hotkey, 3, 10;
    }
    # krunner may use auto-completion which sometimes gets confused by
    # too fast typing or looses characters because of the load caused (also
    # see below), especially in wayland.
    # See https://progress.opensuse.org/issues/18200 as well as
    # https://progress.opensuse.org/issues/35589
    if (check_var('DESKTOP', 'kde')) {
        if (get_var('WAYLAND')) {
            wait_still_screen(2);
            type_string_very_slow substr $program, 0, 1;
            type_string_very_slow substr $program, 1, 1;
            type_string_very_slow substr $program, 2;
        }
        else {
            type_string_slow $program;
        }
    }
    else {
        type_string $program;
    }
}

=head2 x11_start_program

  x11_start_program($program [, timeout => $timeout ] [, no_wait => 0|1 ] [, valid => 0|1 [, target_match => $target_match ] [, match_timeout => $match_timeout ] [, match_no_wait => 0|1 ] [, match_typed => 0|1 ]]);

Start the program C<$program> in an X11 session using the I<desktop-runner>
and looking for a target screen to match.

The timeout for C<check_screen> for I<desktop-runner> can be configured with
optional C<$timeout>. Specify C<no_wait> to skip the C<wait_still_screen>
after the typing of C<$program>. Overwrite C<valid> with a false value to exit
after I<desktop-runner> executed without checking for the result. C<valid=1>
is especially useful when the used I<desktop-runner> has an auto-completion
feature which can cause high load while typing potentially causing the
subsequent C<ret> to fail. By default C<x11_start_program> looks for a screen
tagged with the value of C<$program> with C<assert_screen> after executing the
command to launch C<$program>. The tag(s) can be customized with the parameter
C<$target_match>. C<$match_timeout> can be specified to configure the timeout
on that internal C<assert_screen>. Specify C<match_no_wait> to forward the
C<no_wait> option to the internal C<assert_screen>.
If user wants to assert that command was typed correctly in the I<desktop-runner>
she can pass needle tag using C<match_typed> parameter. This will check typed text
and retry once in case of typos or unexpected results (see poo#25972).

The combination of C<no_wait> with C<valid> and C<target_match> is the
preferred solution for the most efficient approach by saving time within
tests.

In case of KDE plasma krunner provides a suggestion list which can take a bit
of time to be computed therefore the logic is slightly different there, for
example longer waiting time, looking for the computed suggestions list before
accepting and a default timeout for the target match of 90 seconds versus just
using the default of C<assert_screen> itself. For other desktop environments
we keep the old check for the runner border.

This method is overwriting the base method in os-autoinst.

=cut

sub x11_start_program {
    my ($self, $program, %args) = @_;
    my $timeout = $args{timeout};
    # enable valid option as default
    $args{valid}         //= 1;
    $args{target_match}  //= $program;
    $args{match_no_wait} //= 0;
    $args{match_timeout} //= 90 if check_var('DESKTOP', 'kde');

    # Start desktop runner and type command there
    init_desktop_runner($program, $timeout);
    # With match_typed we check typed text and if doesn't match - retrying
    # Is required by firefox test on kde, as typing fails on KDE desktop runnner sometimes
    if ($args{match_typed} && !check_screen($args{match_typed}, 30)) {
        send_key 'esc';
        init_desktop_runner($program, $timeout);
    }
    wait_still_screen(1);
    save_screenshot;
    send_key 'ret';
    # As above especially krunner seems to take some time before disappearing
    # after 'ret' press we should wait in this case nevertheless
    wait_still_screen(3, similarity_level => 45) unless ($args{no_wait} || ($args{valid} && $args{target_match} && !check_var('DESKTOP', 'kde')));
    return unless $args{valid};
    set_var('IN_X11_START_PROGRAM', $program);
    my @target = ref $args{target_match} eq 'ARRAY' ? @{$args{target_match}} : $args{target_match};
    for (1 .. 3) {
        push @target, check_var('DESKTOP', 'kde') ? 'desktop-runner-plasma-suggestions' : 'desktop-runner-border';
        assert_screen([@target], $args{match_timeout}, no_wait => $args{match_no_wait});
        last unless match_has_tag('desktop-runner-border') || match_has_tag('desktop-runner-plasma-suggestions');
        wait_screen_change {
            send_key 'ret';
        };
    }
    set_var('IN_X11_START_PROGRAM', undef);
    # asserting program came up properly
    die "Did not find target needle for tag(s) '@target'" if match_has_tag('desktop-runner-border') || match_has_tag('desktop-runner-plasma-suggestions');
}

sub _ensure_installed_zypper_fallback {
    my ($self, $pkglist) = @_;
    $self->become_root;
    pkcon_quit;
    zypper_call "in $pkglist";
    type_string "exit\n";
}

sub ensure_installed {
    my ($self, $pkgs, %args) = @_;
    my $pkglist = ref $pkgs eq 'ARRAY' ? join ' ', @$pkgs : $pkgs;
    # aarch64 is known to be our slowest architecture in many regards,
    # especially when it is about I/O so be a bit more forgiving here
    $args{timeout} //= check_var('ARCH', 'aarch64') ? 300 : 90;

    testapi::x11_start_program('xterm');
    $self->become_root;
    ensure_serialdev_permissions;

    # make sure packagekit service is available
    testapi::assert_script_run('systemctl is-active -q packagekit || (systemctl unmask -q packagekit ; systemctl start -q packagekit)');
    type_string "exit\n";
    $self->script_run("pkcon install -yp $pkglist; echo pkcon-status-\$? | tee /dev/$testapi::serialdev", 0);
    my @tags = qw(Policykit Policykit-behind-window pkcon-finished);
    while (1) {
        last unless @tags;
        my $ret = check_screen(\@tags, $args{timeout});
        last unless $ret;
        last if (match_has_tag('pkcon-finished'));
        if (match_has_tag('Policykit')) {
            type_password;
            send_key 'ret';
            @tags = grep { $_ ne 'Policykit' } @tags;
            @tags = grep { $_ ne 'Policykit-behind-window' } @tags;
            next;
        }
        if (match_has_tag('Policykit-behind-window')) {
            wait_screen_change { send_key 'alt-tab' };
            next;
        }
    }
    my $ret = wait_serial('pkcon-status-\d+');
    if ($ret =~ /pkcon-status-4/) {
        $self->_ensure_installed_zypper_fallback($pkglist);
        record_soft_failure "boo#1091353 - pkcon doesn't find existing pkg - falling back to zypper";
    }
    elsif ($ret =~ /pkcon-status-5/) {
        record_info 'pkcon failed', 'Return value meaning: "Nothing useful was done", trying fallback to zypper"';
        $self->_ensure_installed_zypper_fallback($pkglist);
        record_soft_failure 'boo#1100134 - pkcon randomly fails to download packages';
    }
    elsif ($ret !~ /pkcon-status-0/) {
        die "pkcon install did not succeed, return code: $ret";
    }
    send_key("alt-f4");    # close xterm
}

sub script_sudo {
    my ($self, $prog, $wait) = @_;

    my $str = time;
    if ($wait > 0) {
        $prog = "$prog; echo $str-\$?- > /dev/$testapi::serialdev";
    }
    type_string "clear\n";    # poo#13710
    type_string "su -c \'$prog\'\n";
    handle_password_prompt unless ($testapi::username eq 'root');
    if ($wait > 0) {
        return wait_serial("$str-\\d+-");
    }
    return;
}

=head2 set_standard_prompt

  set_standard_prompt([$user] [[, os_type] [, skip_set_standard_prompt]])

C<$user> and C<os_type> affect prompt sign. C<skip_set_standard_prompt> options
skip the entire routine.
=cut
sub set_standard_prompt {
    my ($self, $user, %args) = @_;
    return if $args{skip_set_standard_prompt};
    $user ||= $testapi::username;
    my $os_type = $args{os_type} // 'linux';
    my $prompt_sign = $user eq 'root' ? '#' : '$';
    if ($os_type eq 'windows') {
        $prompt_sign = $user eq 'root' ? '# ' : '$$ ';
        type_string "prompt $prompt_sign\n";
        type_string "cls\n";    # clear the screen
    }
    elsif ($os_type eq 'linux') {
        type_string "which tput 2>&1 && PS1=\"\\\[\$(tput bold 2; tput setaf 1)\\\]$prompt_sign\\\[\$(tput sgr0)\\\] \"\n";
    }
}

sub become_root {
    my ($self) = @_;

    $self->script_sudo('bash', 0);
    disable_serial_getty;
    type_string "whoami > /dev/$testapi::serialdev\n";
    wait_serial('root') || die "Root prompt not there";
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
    if (is_svirt_except_s390x) {
        my $hostname = get_var('VIRSH_GUEST');
        my $port     = get_var('VIRSH_INSTANCE', 1) + 5900;

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
        || is_svirt_except_s390x)
    {
        $self->add_console('install-shell',  'tty-console', {tty => 2});
        $self->add_console('installation',   'tty-console', {tty => check_var('VIDEOMODE', 'text') ? 1 : 7});
        $self->add_console('install-shell2', 'tty-console', {tty => 9});
        # On SLE15 X is running on tty2 see bsc#1054782
        $self->add_console('root-console',   'tty-console', {tty => get_root_console_tty});
        $self->add_console('user-console',   'tty-console', {tty => 4});
        $self->add_console('log-console',    'tty-console', {tty => 5});
        $self->add_console('displaymanager', 'tty-console', {tty => 7});
        $self->add_console('x11',            'tty-console', {tty => get_x11_console_tty});
    }

    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        $self->add_console(
            'hyperv-intermediary',
            'ssh-virtsh',
            {
                hostname => get_required_var('VIRSH_GUEST'),
                password => get_var('VIRSH_GUEST_PASSWORD')});
    }

    if (get_var('BACKEND', '') =~ /ikvm|ipmi|spvm/) {
        $self->add_console(
            'root-ssh',
            'ssh-xterm',
            {
                hostname => get_required_var('SUT_IP'),
                password => $testapi::password,
                user     => 'root',
                serial   => 'mkfifo /dev/sshserial; tail -f /dev/sshserial',
                gui      => 1
            });
    }

    if (get_var('BACKEND', '') =~ /ipmi|s390x|spvm/ || get_var('S390_ZKVM')) {
        my $hostname;

        $hostname = get_var('VIRSH_GUEST')     if get_var('S390_ZKVM');
        $hostname = get_required_var('SUT_IP') if get_var('BACKEND', '') =~ /ipmi|spvm/;

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

=head2 hyperv_console_switch

    hyperv_console_switch($console, $nr)

On Hyper-V console switch from one console to another is not possible with the general
'Ctrl-Alt-Fx' binding as the combination is lost somewhere in VNC-to-RDP translation.
For VT-to-VT switch we use 'Alt-Fx' binding, however this is not enough for X11-to-VT
switch, which requires the missing 'Ctrl'. However, in X11 we can use `chvt` command
to do the switch for us.

This is expected to be executed either from activate_console(), or from console_selected(),
test variable C<CONSOLE_JUST_ACTIVATED> works as a mutually exclusive lock.

Requires C<console> name, an actual VT number C<nr> is optional.
=cut
sub hyperv_console_switch {
    my ($self, $console, $nr) = @_;

    return unless check_var('VIRSH_VMM_FAMILY', 'hyperv');
    # If CONSOLE_JUST_ACTIVATED is set, this sub was already executed for current console.
    # If we switch to 'x11', we are already there because, if we switch from VT then 'Alt-Fx'
    # works, if we switch from 'x11' to 'x11' then we don't have to do anything.
    if (get_var('CONSOLE_JUST_ACTIVATED') || $console eq 'x11' || $console eq 'displaymanager') {
        set_var('CONSOLE_JUST_ACTIVATED', 0);
        return;
    }
    die 'hyperv_console_switch: Console was not provided' unless $console;
    diag 'hyperv_console_switch: Console number was not provided' unless $nr;
    # If we are in VT, 'Alt-Fx' switch already worked
    return if check_screen('any-console', 10);
    # We are in X11 and wan't to switch to VT
    testapi::x11_start_program('xterm');
    self->distribution::script_sudo("exec chvt $nr; exit", 0);
}

=head2 console_nr

    console_nr($console)

Return console VT number with regards to it's name.
=cut
sub console_nr {
    my ($console) = @_;
    $console =~ m/^(\w+)-(console|virtio-terminal|ssh|shell)/;
    my ($name) = ($1) || return;
    my $nr = 4;
    $nr = get_root_console_tty if ($name eq 'root');
    $nr = 5 if ($name eq 'log');
    return $nr;
}

=head2 activate_console

  activate_console($console [, [ensure_tty_selected => 0|1, ] [skip_set_standard_prompt => 0|1, ] [skip_setterm => 0|1, ]])

Callback whenever a console is selected for the first time. Accepts arguments
provided to select_console().

C<skip_set_standard_prompt> and C<skip_setterm> arguments skip respective routines,
e.g. if you want select_console() without addition console setup. Then, at some
point, you should set it on your own.

Option C<ensure_tty_selected> ensures TTY is selected.
=cut
sub activate_console {
    my ($self, $console, %args) = @_;

    if ($console eq 'install-shell') {
        if (get_var("LIVECD")) {
            # LIVE CDa do not run inst-consoles as started by inst-linux (it's regular live run, auto-starting yast live installer)
            assert_screen "text-login", 10;
            # login as root, who does not have a password on Live-CDs
            wait_screen_change { type_string "root\n" };
        }
        elsif (get_var('BACKEND', '') =~ /ipmi|spvm/) {
            # Select configure serial and redirect to root-ssh instead
            use_ssh_serial_console;
            return;
        }
        else {
            # on s390x we need to login here by providing a password
            handle_password_prompt if check_var('ARCH', 's390x');
            assert_screen "inst-console";
        }
    }
    elsif ($console =~ m/root-console$/ && check_var('BACKEND', 'spvm')) {
        # Select configure serial and redirect to root-ssh instead
        use_ssh_serial_console;
        return;
    }

    $console =~ m/^(\w+)-(console|virtio-terminal|ssh|shell)/;
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
        if (get_var('BACKEND', '') =~ /ipmi|s390x|spvm/ || get_var('S390_ZKVM')) {
            diag 'backend ipmi || spvm || s390x || zkvm';
            $user ||= 'root';
            handle_password_prompt;
            ensure_user($user);
        }
        else {
            my $nr = console_nr($console);
            $self->hyperv_console_switch($console, $nr);
            my @tags = ("tty$nr-selected", "text-logged-in-$user");
            # s390 zkvm uses a remote ssh session which is root by default so
            # search for that and su to user later if necessary
            push(@tags, 'text-logged-in-root') if get_var('S390_ZKVM');
            # we need to wait more than five seconds here to pass the idle timeout in
            # case the system is still booting (https://bugzilla.novell.com/show_bug.cgi?id=895602)
            # or when using remote consoles which can take some seconds, e.g.
            # just after ssh login
            assert_screen \@tags, 60;
            if (match_has_tag("tty$nr-selected")) {
                type_string "$user\n";
                handle_password_prompt;
            }
            elsif (match_has_tag('text-logged-in-root')) {
                ensure_user($user);
            }
        }
        assert_screen "text-logged-in-$user";
        $self->set_standard_prompt($user, skip_set_standard_prompt => $args{skip_set_standard_prompt});
        assert_screen $console;
    }
    elsif ($type eq 'virtio-terminal') {
        serial_terminal::login($user, $self->{serial_term_prompt});
    }
    elsif ($console eq 'novalink-ssh') {
        assert_screen "password-prompt-novalink";
        type_password get_required_var('NOVALINK_PASSWORD');
        send_key('ret');
        my $user = get_var('NOVALINK_USERNAME', 'root');
        assert_screen("text-logged-in-$user", 60);
        $self->set_standard_prompt($user);
    }
    elsif ($type eq 'ssh') {
        $user ||= 'root';
        handle_password_prompt;
        ensure_user($user);
        assert_screen(["text-logged-in-$user", "text-login"], 60);
        $self->set_standard_prompt($user, skip_set_standard_prompt => $args{skip_set_standard_prompt});
    }
    elsif ($console eq 'svirt' || $console eq 'hyperv-intermediary') {
        my $os_type = (check_var('VIRSH_VMM_FAMILY', 'hyperv') && $console eq 'svirt') ? 'windows' : 'linux';
        handle_password_prompt($console);
        $self->set_standard_prompt('root', os_type => $os_type, skip_set_standard_prompt => $args{skip_set_standard_prompt});
        save_svirt_pty;
    }
    elsif (
        $console eq 'installation'
        && ((get_var('BACKEND', '') =~ /ipmi|s390x|spvm/) || get_var('S390_ZKVM'))
        && (get_var('VIDEOMODE', '') =~ /text|ssh-x/))
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
    # Both consoles and shells should be prevented from blanking
    if ((($type eq 'console') or ($type =~ /shell/)) and (get_var('BACKEND', '') =~ /qemu|svirt/)) {
        # On s390x 'setterm' binary is not present as there's no linux console
        if (!check_var('ARCH', 's390x')) {
            # Disable console screensaver
            $self->script_run('setterm -blank 0') unless $args{skip_setterm};
        }
    }
    set_var('CONSOLE_JUST_ACTIVATED', 1);
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
    $args{ignore}        //= qr{sut|root-virtio-terminal|iucvconn|svirt|root-ssh|hyperv-intermediary};

    if ($args{tags} =~ $args{ignore} || !$args{await_console}) {
        set_var('CONSOLE_JUST_ACTIVATED', 0);
        return;
    }
    $self->hyperv_console_switch($console, console_nr($console));
    set_var('CONSOLE_JUST_ACTIVATED', 0);
    # x11 needs special handling because we can not easily know if screen is
    # locked, display manager is waiting for login, etc.
    return ensure_unlocked_desktop if $args{tags} =~ /x11/;
    assert_screen($args{tags}, no_wait => 1);
}

1;
