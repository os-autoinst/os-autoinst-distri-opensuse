#!/usr/bin/python3
"""
Functional tests for the virtual console font.

Verifies that the console font is configured, that the configured font
file is present, and that systemd applies it without errors:

- /etc/vconsole.conf exists and defines FONT and KEYMAP
- the file named by FONT exists in the kbd consolefonts directory
- localectl status runs (it reports the keymaps, not the font)
- systemd-vconsole-setup.service is loaded and not failed
- running systemd-vconsole-setup (re)applies the font successfully

The rendered glyphs are intentionally not compared here: that needs a
VGA screen and a needle and only covers one adapter. The historic
goal of the check was to catch a font that was not applied at boot
(systemd 210/228 race); on current systemd the useful signal is the
configuration plus the setup service.

Inspired by:
    systemd          test/units/TEST-74-AUX-UTILS.vconsole-setup.sh
    os-autoinst-distri-opensuse  lib/utils.pm check_console_font

Usage:
    sudo python3 -m pytest test_console_font.py -v

References:
    boo#1205518  autovt@tty2 competes with gdm (neighbouring workaround)
    bsc#1205290  systemd-vconsole-setup restart on 12-SP5 migration
    bsc#1249902  systemd-vconsole-setup.service failed to load
"""

import os
import subprocess
from subprocess import PIPE

import pytest


# ---------------------------------------------------------------------------
# constants
# ---------------------------------------------------------------------------

VCONSOLE_CONF = "/etc/vconsole.conf"
VCONSOLE_SETUP = "/usr/lib/systemd/systemd-vconsole-setup"
VCONSOLE_SERVICE = "systemd-vconsole-setup.service"

FONT_DIRS = [
    "/usr/share/kbd/consolefonts",
    "/usr/share/consolefonts",
    "/usr/lib/kbd/consolefonts",
    "/lib/kbd/consolefonts",
]


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def run(cmd, check=False, timeout=30):
    """Run a command and return the CompletedProcess."""
    return subprocess.run(
        cmd, stdout=PIPE, stderr=PIPE,
        universal_newlines=True, check=check, timeout=timeout,
    )


def parse_vconsole_conf(path=VCONSOLE_CONF):
    """Return the key=value pairs of a vconsole.conf file."""
    settings = {}
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            # systemd accepts single or double quotes around values
            settings[key.strip()] = value.strip().strip("\"'")
    return settings


def font_candidates(font_value):
    """Return the plausible file names for a FONT= value, in order.

    The value may be 'eurlatgr' (Tumbleweed) or 'eurlatgr.psfu'
    (SLE 15); both name /usr/share/kbd/consolefonts/eurlatgr.psfu[.gz].
    """
    name = font_value.split()[0] if font_value else ""
    if not name:
        return []
    base = name
    for suffix in (".psfu.gz", ".psf.gz", ".psfu", ".psf", ".gz"):
        if base.endswith(suffix):
            base = base[:-len(suffix)]
            break
    candidates = []
    for suffix in ("", ".psfu", ".psf", ".gz", ".psfu.gz", ".psf.gz"):
        candidate = base + suffix
        if candidate not in candidates:
            candidates.append(candidate)
    return candidates


def find_font_file(font_value):
    """Return the path of the configured font, or None.

    Looks in the usual consolefonts directories first and falls back to
    the file list of the kbd package, so an unusual layout is reported
    as present rather than as a false failure.
    """
    names = font_candidates(font_value)
    for name in names:
        for directory in FONT_DIRS:
            path = os.path.join(directory, name)
            if os.path.isfile(path):
                return path
    result = run(["rpm", "-ql", "kbd"], timeout=30)
    if result.returncode == 0:
        for line in result.stdout.splitlines():
            if os.path.basename(line) in names and os.path.isfile(line):
                return line
    return None


# ---------------------------------------------------------------------------
# fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def vconsole():
    """The parsed /etc/vconsole.conf, or an empty dict when missing."""
    if not os.path.isfile(VCONSOLE_CONF):
        return {}
    return parse_vconsole_conf()


# ---------------------------------------------------------------------------
# tests
# ---------------------------------------------------------------------------

class TestVconsoleConfiguration:
    """Verify the console font configuration in /etc/vconsole.conf."""

    def test_vconsole_conf_present(self):
        """The systemd console configuration file exists and is not empty."""
        assert os.path.isfile(VCONSOLE_CONF), \
            "%s is missing" % VCONSOLE_CONF
        assert os.path.getsize(VCONSOLE_CONF) > 0, \
            "%s is empty" % VCONSOLE_CONF

    def test_font_configured(self, vconsole):
        """FONT is set in vconsole.conf.

        Textmode products set FONT during installation (TW and SLE 15+
        use eurlatgr). An image provisioned without systemd-firstboot,
        YaST or Agama can legitimately have no font configured and use
        the kernel default, so this skips rather than fails.
        """
        font = vconsole.get("FONT", "")
        if not font:
            pytest.skip("FONT is not set in %s" % VCONSOLE_CONF)

    def test_font_file_exists(self, vconsole):
        """The font named by FONT exists in the consolefonts directory."""
        font = vconsole.get("FONT", "")
        if not font:
            pytest.skip("FONT is not set in %s" % VCONSOLE_CONF)
        resolved = find_font_file(font)
        assert resolved is not None, \
            "font %r not found in %s" % (font, ", ".join(FONT_DIRS))

    def test_keymap_configured(self, vconsole):
        """KEYMAP is set in vconsole.conf."""
        keymap = vconsole.get("KEYMAP", "")
        assert keymap, \
            "KEYMAP is not set in %s: %r" % (VCONSOLE_CONF, vconsole)


class TestLocalectl:
    """Verify localectl status runs.

    localectl status prints the system locale and the VC/X11 keymaps,
    not the console font (systemd src/locale/localectl.c has no font
    field), so it cannot be used to check the font. Its VC Keymap is
    systemd-localed's parse of the same /etc/vconsole.conf that the
    tests above read, so comparing the two would compare the file with
    itself. The font is checked from the file above instead.
    """

    def test_localectl_status_runs(self):
        """localectl status exits successfully."""
        result = run(["localectl", "status"])
        assert result.returncode == 0, \
            "localectl status failed: %s" % result.stderr


class TestVconsoleSetupService:
    """Verify systemd-vconsole-setup can apply the font."""

    def test_vconsole_setup_binary_present(self):
        """The setup helper exists."""
        assert os.path.isfile(VCONSOLE_SETUP), \
            "%s is missing" % VCONSOLE_SETUP

    def test_vconsole_setup_unit_loaded(self):
        """The setup unit is loaded (not 'not-found' / 'bad-setting')."""
        result = run(["systemctl", "show", VCONSOLE_SERVICE,
                      "-p", "LoadState", "--value"])
        assert result.returncode == 0, \
            "systemctl show failed: %s" % result.stderr
        state = result.stdout.strip()
        assert state == "loaded", \
            "%s LoadState=%r (bsc#1249902)" % (VCONSOLE_SERVICE, state)

    def test_vconsole_setup_service_not_failed(self):
        """The setup service is not in the failed state."""
        result = run(["systemctl", "is-failed", VCONSOLE_SERVICE])
        state = result.stdout.strip()
        assert state != "failed", \
            "%s is in the failed state" % VCONSOLE_SERVICE

    def test_apply_font_succeeds(self):
        """Re-applying the console font exits successfully.

        This verifies that the helper runs to completion, not that the
        font is correct; the configuration is checked by the tests
        above. It does apply the configured font to the virtual
        consoles (and may touch /sys/module/vt/parameters/default_utf8),
        so it also repairs a font that was not applied at boot; the
        tests above are what report that configuration state.
        """
        result = run([VCONSOLE_SETUP], timeout=60)
        assert result.returncode == 0, \
            "%s failed: %s" % (VCONSOLE_SETUP, result.stderr)
