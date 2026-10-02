# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
"""Functional tests for Info-ZIP unzip.

Ported from tests/console/unzip.pm. The test runs standalone on any system
with unzip, funzip, unzipsfx and zipinfo installed and does not depend on
openQA variables.

Coverage:
  - extraction of a deterministic sample archive with deflated and stored
    members, a nested directory, an empty file and a filename with a space
  - extraction into a new directory with -d
  - archive integrity check with unzip -t
  - selective extraction of a single member
  - structural validation of unzip -Z (zipinfo) output on testmake.zip
  - funzip streaming compared against unzip -p
  - unzipsfx self-extracting archive compared against unzip -p

testmake.zip is the fixture shipped by the upstream Info-ZIP unix/Makefile
"check" target and is distributed under the Info-ZIP license.
"""

import os
import shutil
import subprocess
import tempfile
import zipfile

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
TESTMAKE = os.path.join(HERE, 'testmake.zip')

# Members of the generated sample archive. The values are the exact bytes
# expected after extraction; the names exercise a nested directory, an empty
# file and a filename containing a space.
SAMPLE_MEMBERS = {
    'hello.txt': b'hello from the unzip agnostic test\n',
    'empty.txt': b'',
    'with space.txt': b'a filename containing a space\n',
    'store.txt': b'stored member, not deflated\n',
    'dir/nested.txt': b'a nested member\n',
}

# Fixed timestamp so the generated archive is reproducible.
SAMPLE_STAMP = (2020, 1, 1, 0, 0, 0)


def run(args, cwd=None):
    """Run a command and capture its text output.

    :param args list the command and its arguments
    :param cwd str directory to run in, or None to inherit the current one
    :return subprocess.CompletedProcess the finished process with text output
    """
    return subprocess.run(
        args,
        cwd=cwd,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        universal_newlines=True,
    )


def run_bytes(args, cwd=None):
    """Run a command and capture its raw stdout as bytes.

    :param args list the command and its arguments
    :param cwd str directory to run in, or None to inherit the current one
    :return subprocess.CompletedProcess the finished process with byte output
    """
    return subprocess.run(
        args,
        cwd=cwd,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def read_bytes(path):
    """Return the raw contents of a file.

    :param path str path of the file to read
    :return bytes the file contents
    """
    with open(path, 'rb') as handle:
        return handle.read()


def build_sample_zip(path):
    """Create the deterministic sample archive used by the extraction tests.

    :param path str path the archive is written to
    :return str the path of the generated archive
    """
    deflated = ('hello.txt', 'empty.txt', 'with space.txt', 'dir/nested.txt')
    with zipfile.ZipFile(path, 'w') as archive:
        for name in deflated:
            info = zipfile.ZipInfo(name, date_time=SAMPLE_STAMP)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, SAMPLE_MEMBERS[name])
        info = zipfile.ZipInfo('store.txt', date_time=SAMPLE_STAMP)
        info.compress_type = zipfile.ZIP_STORED
        info.external_attr = 0o644 << 16
        archive.writestr(info, SAMPLE_MEMBERS['store.txt'])
    return path


@pytest.fixture(scope='session')
def fixture_dir():
    """Provide a shared temporary directory for generated fixtures.

    :return str path of the fixture directory, removed at session end
    """
    path = tempfile.mkdtemp(prefix='unzip-fixtures-')
    yield path
    shutil.rmtree(path, ignore_errors=True)


@pytest.fixture(scope='session')
def sample_zip(fixture_dir):
    """Return the path of the generated sample archive.

    :param fixture_dir str shared fixture directory
    :return str path of the sample archive
    """
    return build_sample_zip(os.path.join(fixture_dir, 'sample.zip'))


@pytest.fixture
def workdir():
    """Provide a clean per-test working directory.

    :return str path of the working directory, removed at test end
    """
    path = tempfile.mkdtemp(prefix='unzip-work-')
    yield path
    shutil.rmtree(path, ignore_errors=True)


def test_extract_members(sample_zip, workdir):
    """Extracting the sample archive yields exactly the expected members."""
    shutil.copy(sample_zip, os.path.join(workdir, 'sample.zip'))
    result = run(['unzip', '-q', 'sample.zip'], cwd=workdir)
    assert result.returncode == 0, result.stdout
    assert sorted(os.listdir(workdir)) == sorted(
        ['sample.zip', 'dir', 'empty.txt', 'hello.txt', 'store.txt', 'with space.txt'])
    for name, content in SAMPLE_MEMBERS.items():
        assert read_bytes(os.path.join(workdir, name)) == content, name


def test_extract_to_directory(sample_zip, workdir):
    """Extracting with -d writes only the archive members below the target."""
    out = os.path.join(workdir, 'extract')
    result = run(['unzip', '-q', sample_zip, '-d', out])
    assert result.returncode == 0, result.stdout
    assert sorted(os.listdir(out)) == sorted(
        ['dir', 'empty.txt', 'hello.txt', 'store.txt', 'with space.txt'])
    for name, content in SAMPLE_MEMBERS.items():
        assert read_bytes(os.path.join(out, name)) == content, name


def test_integrity(sample_zip):
    """unzip -t reports the generated archive as intact."""
    result = run(['unzip', '-t', sample_zip])
    assert result.returncode == 0, result.stdout
    assert 'No errors detected' in result.stdout


def test_selective_extraction(sample_zip, workdir):
    """Only the requested member is written when extracting a single file."""
    out = os.path.join(workdir, 'single')
    result = run(['unzip', '-q', sample_zip, 'with space.txt', '-d', out])
    assert result.returncode == 0, result.stdout
    assert os.listdir(out) == ['with space.txt']
    assert read_bytes(os.path.join(out, 'with space.txt')) == SAMPLE_MEMBERS['with space.txt']


def test_zipinfo_structure():
    """unzip -Z reports the expected entry count, sizes and compression."""
    result = run(['unzip', '-Z', TESTMAKE])
    assert result.returncode == 0, result.stdout
    assert '2 files' in result.stdout
    assert '362 bytes uncompressed' in result.stdout
    assert '259 bytes compressed' in result.stdout
    assert '28.5%' in result.stdout
    # both members are deflated, zipinfo marks them as such
    assert result.stdout.count('defX') == 2
    names = run(['unzip', '-Z', '-1', TESTMAKE])
    assert names.returncode == 0, names.stdout
    assert names.stdout.split() == ['notes', 'testmake.zipinfo']


def test_funzip_matches_unzip_p():
    """funzip streams the first member identically to unzip -p."""
    funzip = run_bytes(['funzip', TESTMAKE])
    unzip_p = run_bytes(['unzip', '-p', TESTMAKE, 'notes'])
    assert funzip.returncode == 0, funzip.stderr
    assert unzip_p.returncode == 0, unzip_p.stderr
    assert funzip.stdout == unzip_p.stdout


def test_unzipsfx_self_extracting(workdir):
    """A self-extracting archive built with unzipsfx extracts the same data."""
    expected = run_bytes(['unzip', '-p', TESTMAKE, 'notes'])
    assert expected.returncode == 0, expected.stderr
    sfx = os.path.join(workdir, 'sfx')
    with open(sfx, 'wb') as out:
        out.write(read_bytes(shutil.which('unzipsfx')))
        out.write(read_bytes(TESTMAKE))
    os.chmod(sfx, 0o700)
    result = run(['./sfx', '-o', 'notes'], cwd=workdir)
    assert result.returncode == 0, result.stdout
    assert read_bytes(os.path.join(workdir, 'notes')) == expected.stdout
