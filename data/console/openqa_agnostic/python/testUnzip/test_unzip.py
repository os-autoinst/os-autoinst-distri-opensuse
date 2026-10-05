# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
"""Functional tests for Info-ZIP unzip.

Ported from tests/console/unzip.pm. The test runs standalone on any system
with Python 3.6+, pytest and the unzip, funzip, unzipsfx and zipinfo binaries
installed, and does not depend on openQA variables. The runtest metadata lists
the individual checks.

testmake.zip is the fixture shipped by the upstream Info-ZIP unix/Makefile
"check" target and is distributed under the Info-ZIP license. encrypted.zip
is a committed ZipCrypto archive with the password "openqa"; to regenerate it
run `zip -P openqa -0 encrypted.zip secret.txt second.txt`. zip64.zip is a
committed zip64 archive with a single payload.txt member; to regenerate it run
`zip -fz zip64.zip payload.txt`.
"""

import os
import re
import shutil
import struct
import subprocess
import zipfile
from datetime import datetime

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
TESTMAKE = os.path.join(HERE, 'testmake.zip')
ENCRYPTED = os.path.join(HERE, 'encrypted.zip')
ZIP64 = os.path.join(HERE, 'zip64.zip')

# testmake.zip's first member; funzip and unzipsfx both return exactly this.
# The bytes are hard-coded so the streaming tests have an independent expected
# value instead of only comparing unzip against itself.
TESTMAKE_FIRST_MEMBER = 'notes'
TESTMAKE_FIRST_MEMBER_DATA = (
    b"This file is part of testmake.zip for UnZip 5.4 and\r\n"
    b"later.  It has DOS/OS2/NT style CR-LF line-endings.\r\n"
    b"It's pretty short.\r\n"
)

# Password and contents of the committed ZipCrypto fixture.
ENCRYPTED_PASSWORD = 'openqa'
ENCRYPTED_MEMBERS = {
    'secret.txt': b'encrypted payload for the unzip agnostic test\n',
    'second.txt': b'another encrypted member\n',
}

# A few hundred KiB member, so extraction has to inflate more than one block
# and make use of the 32 KiB sliding window instead of only tiny members.
LARGE_MEMBER = b''.join(b'unzip agnostic test data %06d\n' % i for i in range(20000))

# A member whose name needs the UTF-8 flag, to cover the charset handling
# distributions patch into unzip.
NONASCII_MEMBER = 'naïve-ünïcödé.txt'
NONASCII_CONTENT = b'non-ascii filename\n'

# Members of the generated sample archive, mapping each name to the exact bytes
# expected after extraction. The names exercise a nested directory, an empty
# file, a filename containing a space and a large deflated member.
SAMPLE_MEMBERS = {
    'hello.txt': b'hello from the unzip agnostic test\n',
    'empty.txt': b'',
    'with space.txt': b'a filename containing a space\n',
    'store.txt': b'stored member, not deflated\n',
    'dir/nested.txt': b'a nested member\n',
    'large.bin': LARGE_MEMBER,
}

# Members stored rather than deflated, so extraction covers both methods.
SAMPLE_STORED = ('store.txt',)

# Fixed timestamp and mode. 0600 is used for the mode assertion because a umask
# can only clear permission bits, never grant them, so the check holds whatever
# umask the test runs under.
SAMPLE_STAMP = (2020, 1, 1, 0, 0, 0)
SAMPLE_MODE = 0o600

# Commands must never be able to block on a prompt or otherwise hang the job.
RUN_TIMEOUT = 60

# Local file header layout (PKWARE APPNOTE 4.3.7). Only the fields needed to
# locate the first member's data are parsed.
LOCAL_HEADER_FMT = '<IHHHHHIIIHH'
LOCAL_HEADER_SIZE = struct.calcsize(LOCAL_HEADER_FMT)
LOCAL_HEADER_SIGNATURE = 0x04034B50


def _run(args, cwd=None, text=False, input=None):
    """Run a command with a timeout, detached from the controlling terminal.

    start_new_session stops unzip from prompting for a password on /dev/tty
    (it reads passwords from the terminal, not stdin), and the timeout turns a
    hang into a test error instead of blocking the whole module.

    :param args list the command and its arguments
    :param cwd str directory to run in, or None to inherit the current one
    :param text bool capture text and merge stderr into stdout, or capture bytes
    :param input bytes or str data to feed on stdin, or None to use /dev/null
    :return subprocess.CompletedProcess the finished process
    """
    kwargs = {
        'cwd': cwd,
        'stdout': subprocess.PIPE,
        'stderr': subprocess.STDOUT if text else subprocess.PIPE,
        'universal_newlines': text,
        'timeout': RUN_TIMEOUT,
        'start_new_session': True,
    }
    if input is None:
        kwargs['stdin'] = subprocess.DEVNULL
    else:
        kwargs['input'] = input
    return subprocess.run(args, **kwargs)


def run_text(args, cwd=None, input=None):
    """Run a command and capture its combined text output.

    stderr is merged into stdout, so the returned .stderr is always None.

    :param args list the command and its arguments
    :param cwd str directory to run in, or None to inherit the current one
    :param input str data to feed on stdin, or None to use /dev/null
    :return subprocess.CompletedProcess the finished process with text output
    """
    return _run(args, cwd=cwd, text=True, input=input)


def run_bytes(args, cwd=None, input=None):
    """Run a command and capture its raw stdout, keeping stderr separate.

    :param args list the command and its arguments
    :param cwd str directory to run in, or None to inherit the current one
    :param input bytes data to feed on stdin, or None to use /dev/null
    :return subprocess.CompletedProcess the finished process with byte output
    """
    return _run(args, cwd=cwd, text=False, input=input)


def read_bytes(path):
    """Return the raw contents of a file.

    :param path str path of the file to read
    :return bytes the file contents
    """
    with open(path, 'rb') as handle:
        return handle.read()


def sample_top_level():
    """Return the sorted top-level names the sample archive extracts to.

    :return list of str top-level file and directory names
    """
    return sorted({name.split('/')[0] for name in SAMPLE_MEMBERS})


def build_sample_zip(path):
    """Create the deterministic sample archive used by the extraction tests.

    :param path str path the archive is written to
    :return str the path of the generated archive
    """
    with zipfile.ZipFile(path, 'w') as archive:
        for name, content in SAMPLE_MEMBERS.items():
            info = zipfile.ZipInfo(name, date_time=SAMPLE_STAMP)
            info.compress_type = zipfile.ZIP_STORED if name in SAMPLE_STORED else zipfile.ZIP_DEFLATED
            info.external_attr = SAMPLE_MODE << 16
            archive.writestr(info, content)
    return path


def member_data_offset(path):
    """Return the offset of the first member's data in a zip archive.

    :param path str path of the zip archive
    :return int offset past the local header, filename and extra field
    """
    with open(path, 'rb') as handle:
        header = handle.read(LOCAL_HEADER_SIZE)
    fields = struct.unpack(LOCAL_HEADER_FMT, header)
    assert fields[0] == LOCAL_HEADER_SIGNATURE, 'not a local file header'
    # The filename and extra-field lengths are the last two header fields.
    return LOCAL_HEADER_SIZE + fields[-2] + fields[-1]


@pytest.fixture(scope='session')
def sample_zip(tmp_path_factory):
    """Return the path of the generated sample archive.

    :param tmp_path_factory pytest.TempPathFactory session-scoped factory
    :return str path of the sample archive
    """
    return build_sample_zip(str(tmp_path_factory.mktemp('unzip-fixtures') / 'sample.zip'))


def test_extract_members(sample_zip, tmp_path):
    """Extracting the sample archive yields exactly the expected members."""
    shutil.copy(sample_zip, os.path.join(tmp_path, 'sample.zip'))
    result = run_text(['unzip', '-q', 'sample.zip'], cwd=tmp_path)
    assert result.returncode == 0, result.stdout
    assert sorted(os.listdir(tmp_path)) == sorted(sample_top_level() + ['sample.zip'])
    for name, content in SAMPLE_MEMBERS.items():
        path = os.path.join(tmp_path, name)
        assert read_bytes(path) == content, name
        # unzip restores the stored mode and timestamp alongside the data.
        mode = os.stat(path).st_mode & 0o777
        assert mode == SAMPLE_MODE, '%s mode %o' % (name, mode)
        mtime = datetime.fromtimestamp(os.stat(path).st_mtime)
        assert mtime == datetime(*SAMPLE_STAMP), '%s mtime %s' % (name, mtime)


def test_extract_to_directory(sample_zip, tmp_path):
    """Extracting with -d places the archive members below the target directory."""
    out = os.path.join(tmp_path, 'extract')
    result = run_text(['unzip', '-q', sample_zip, '-d', out])
    assert result.returncode == 0, result.stdout
    assert sorted(os.listdir(out)) == sample_top_level()
    for name, content in SAMPLE_MEMBERS.items():
        assert read_bytes(os.path.join(out, name)) == content, name


def test_integrity(sample_zip):
    """unzip -t reports the generated archive as intact."""
    result = run_text(['unzip', '-t', sample_zip])
    assert result.returncode == 0, result.stdout
    assert 'No errors detected' in result.stdout


def test_selective_extraction(sample_zip, tmp_path):
    """Only the requested member is written when extracting a single file."""
    out = os.path.join(tmp_path, 'single')
    result = run_text(['unzip', '-q', sample_zip, 'with space.txt', '-d', out])
    assert result.returncode == 0, result.stdout
    assert os.listdir(out) == ['with space.txt']
    assert read_bytes(os.path.join(out, 'with space.txt')) == SAMPLE_MEMBERS['with space.txt']


def test_overwrite_options(tmp_path):
    """-n leaves an existing file alone and -o overwrites it."""
    archive = os.path.join(tmp_path, 'overwrite.zip')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as handle:
        handle.writestr('keep.txt', b'new content\n')
    out = os.path.join(tmp_path, 'out')
    os.makedirs(out)
    target = os.path.join(out, 'keep.txt')
    with open(target, 'wb') as handle:
        handle.write(b'old content\n')

    result = run_text(['unzip', '-n', archive, '-d', out])
    assert result.returncode == 0, result.stdout
    assert read_bytes(target) == b'old content\n', 'unzip -n overwrote the file'

    result = run_text(['unzip', '-o', archive, '-d', out])
    assert result.returncode == 0, result.stdout
    assert read_bytes(target) == b'new content\n', 'unzip -o did not overwrite the file'


def test_nonascii_filename(tmp_path):
    """A member whose name needs the UTF-8 flag is extracted byte-for-byte."""
    archive = os.path.join(tmp_path, 'nonascii.zip')
    with zipfile.ZipFile(archive, 'w') as handle:
        info = zipfile.ZipInfo(NONASCII_MEMBER, date_time=SAMPLE_STAMP)
        info.compress_type = zipfile.ZIP_DEFLATED
        handle.writestr(info, NONASCII_CONTENT)
    out = os.path.join(tmp_path, 'out')
    result = run_text(['unzip', '-q', archive, '-d', out])
    assert result.returncode == 0, result.stdout
    # Compare through bytes paths, so the check does not depend on the locale
    # Python happens to decode the directory listing with.
    out_bytes = os.fsencode(out)
    expected = NONASCII_MEMBER.encode('utf-8')
    assert expected in os.listdir(out_bytes), os.listdir(out_bytes)
    assert read_bytes(os.path.join(out_bytes, expected)) == NONASCII_CONTENT


def test_zipinfo_structure():
    """unzip -Z reports the expected entry count, sizes and compression."""
    # Derive the expected numbers from the archive itself instead of hard
    # coding them, so the test does not depend on zipinfo's summary formatting.
    with zipfile.ZipFile(TESTMAKE) as archive:
        infos = archive.infolist()
        total_uncompressed = sum(info.file_size for info in infos)
        total_compressed = sum(info.compress_size for info in infos)
        deflated = sum(1 for info in infos if info.compress_type == zipfile.ZIP_DEFLATED)

    result = run_text(['unzip', '-Z', TESTMAKE])
    assert result.returncode == 0, result.stdout
    # The digit lookbehind keeps "2 files" from matching inside "12 files".
    assert re.search(r'(?<!\d)%d files' % len(infos), result.stdout), result.stdout
    assert re.search(r'(?<!\d)%d bytes uncompressed' % total_uncompressed, result.stdout), result.stdout
    assert re.search(r'(?<!\d)%d bytes compressed' % total_compressed, result.stdout), result.stdout
    # zipinfo tags each deflated member's method column with defN/defX, so
    # count only the member lines (they start with the permission string such
    # as -rw-a--); the Archive: line carries the path and can contain "def".
    member_lines = [line for line in result.stdout.splitlines() if line.startswith('-')]
    deflated_lines = [line for line in member_lines if re.search(r'\bdef[A-Za-z]*\b', line)]
    assert len(deflated_lines) == deflated, result.stdout

    names = run_text(['unzip', '-Z', '-1', TESTMAKE])
    assert names.returncode == 0, names.stdout
    assert names.stdout.split() == [info.filename for info in infos], names.stdout


def test_funzip_matches_unzip_p():
    """funzip streams the first member identically to unzip -p."""
    funzip = run_bytes(['funzip', TESTMAKE])
    unzip_p = run_bytes(['unzip', '-p', TESTMAKE, TESTMAKE_FIRST_MEMBER])
    assert funzip.returncode == 0, funzip.stderr
    assert unzip_p.returncode == 0, unzip_p.stderr
    assert funzip.stdout == TESTMAKE_FIRST_MEMBER_DATA, funzip.stdout
    assert unzip_p.stdout == TESTMAKE_FIRST_MEMBER_DATA, unzip_p.stdout


def test_funzip_from_stdin():
    """funzip reads the archive from stdin, its documented main use."""
    result = run_bytes(['funzip'], input=read_bytes(TESTMAKE))
    assert result.returncode == 0, result.stderr
    assert result.stdout == TESTMAKE_FIRST_MEMBER_DATA, result.stdout


def test_unzipsfx_self_extracting(tmp_path):
    """A self-extracting archive built with unzipsfx extracts the same data."""
    unzipsfx = shutil.which('unzipsfx')
    assert unzipsfx, 'unzipsfx not found in PATH'
    sfx = os.path.join(tmp_path, 'sfx')
    with open(sfx, 'wb') as out:
        out.write(read_bytes(unzipsfx))
        out.write(read_bytes(TESTMAKE))
    os.chmod(sfx, 0o700)
    result = run_text(['./sfx', '-o', TESTMAKE_FIRST_MEMBER], cwd=tmp_path)
    assert result.returncode == 0, result.stdout
    extracted = read_bytes(os.path.join(tmp_path, TESTMAKE_FIRST_MEMBER))
    assert extracted == TESTMAKE_FIRST_MEMBER_DATA, extracted


def test_zip64(tmp_path):
    """The committed zip64 archive is recognised and extracted correctly."""
    # unzip -Z -v must report both the zip64 version and the PKWARE 64-bit
    # sizes subfield in the central directory, so this really makes unzip parse
    # a zip64 archive instead of silently exercising a plain one.
    listing = run_text(['unzip', '-Z', '-v', ZIP64])
    assert listing.returncode == 0, listing.stdout
    assert re.search(r'minimum software version required to extract:\s+4\.5', listing.stdout), listing.stdout
    assert re.search(r'0x0001 \(PKWARE 64-bit sizes\)', listing.stdout), listing.stdout

    out = os.path.join(tmp_path, 'out')
    result = run_text(['unzip', '-q', ZIP64, '-d', out])
    assert result.returncode == 0, result.stdout
    assert read_bytes(os.path.join(out, 'payload.txt')) == b'zip64 payload\n'


def test_encrypted_zipcrypto(tmp_path):
    """A ZipCrypto archive decrypts with the correct password."""
    out = os.path.join(tmp_path, 'out')
    result = run_text(['unzip', '-o', '-P', ENCRYPTED_PASSWORD, ENCRYPTED, '-d', out])
    assert result.returncode == 0, result.stdout
    assert sorted(os.listdir(out)) == sorted(ENCRYPTED_MEMBERS), os.listdir(out)
    for name, content in ENCRYPTED_MEMBERS.items():
        assert read_bytes(os.path.join(out, name)) == content, name


@pytest.mark.parametrize(
    'password, reason',
    [(None, 'unable to get password'), ('not-the-password', 'incorrect password')],
    ids=['missing', 'wrong'])
def test_encrypted_password_rejected(tmp_path, password, reason):
    """A missing or wrong password extracts nothing and fails for that reason."""
    out = os.path.join(tmp_path, 'rejected')
    args = ['unzip', '-o']
    if password is not None:
        args += ['-P', password]
    result = run_text(args + [ENCRYPTED, '-d', out])
    assert result.returncode != 0, result.stdout
    # Match the reason, not just a non-zero status, so a crash would not pass.
    assert reason in result.stdout.lower(), result.stdout
    for name in ENCRYPTED_MEMBERS:
        assert not os.path.exists(os.path.join(out, name)), name


@pytest.mark.parametrize('member', ['../escape.txt', '/unzip-slip-escape.txt'], ids=['parent', 'absolute'])
def test_path_traversal(tmp_path, member):
    """A member with a leading ../ or / must not escape the extraction directory."""
    archive = os.path.join(tmp_path, 'traversal.zip')
    with zipfile.ZipFile(archive, 'w') as handle:
        info = zipfile.ZipInfo(member, date_time=SAMPLE_STAMP)
        info.compress_type = zipfile.ZIP_DEFLATED
        handle.writestr(info, b'escape attempt\n')
    out = os.path.join(tmp_path, 'sandbox')
    result = run_text(['unzip', '-o', archive, '-d', out])

    # Whatever unzip does with the leading components, the member must not be
    # written outside the extraction directory. Where a naive extractor would
    # put it: out/../escape.txt for the parent form, /unzip-slip-escape.txt for
    # the absolute one (join drops out for an absolute name).
    escape_path = os.path.normpath(os.path.join(out, member))
    escaped = os.path.exists(escape_path)
    if escaped:
        os.unlink(escape_path)
    assert not escaped, 'member escaped the extraction directory: %s' % escape_path

    # unzip strips the unsafe leading components, writes the member inside the
    # target directory and exits 1, which proves it actually processed the
    # entry instead of failing early.
    extracted = os.path.join(out, os.path.basename(member))
    assert read_bytes(extracted) == b'escape attempt\n', extracted
    assert result.returncode == 1, result.stdout
    if member.startswith('../'):
        assert re.search(r'skipped\s+"\.\./"\s+path component', result.stdout), result.stdout
    else:
        assert re.search(r'stripped absolute path spec', result.stdout), result.stdout


def test_corrupted_deflate(tmp_path):
    """unzip -t rejects an archive with a corrupted deflate stream."""
    archive = os.path.join(tmp_path, 'corrupt.zip')
    # zipfile writes raw deflate (no zlib header), and 400 'A's compress to an
    # 8-byte stream, so flipping byte 2 corrupts data inside the stream.
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as handle:
        handle.writestr('data.txt', b'A' * 400)
    raw = bytearray(read_bytes(archive))
    raw[member_data_offset(archive) + 2] ^= 0xFF
    with open(archive, 'wb') as handle:
        handle.write(bytes(raw))
    result = run_text(['unzip', '-t', archive])
    assert result.returncode != 0, result.stdout
    # unzip reports a corrupted deflate stream as one of these. A bare "error"
    # match is not enough, because "No errors detected" contains it too.
    output = result.stdout.lower()
    assert re.search(r'bad crc|invalid compressed data|at least one error was detected', output), result.stdout
