# rpmbuild --build-in-place -ba hello.spec

Name:           hello0
Version:        0.1
Release:        0
Summary:        Test pk
License:        GPL-3.0-or-later
Group:          Productivity/Security
URL:            https://no.url/
BuildArch:      noarch

%description
This is a test pkg.

%prep
%setup -q

%build

%install
#cp -v %{SOURCE0} %{buildroot}/%{name}.spec
echo %{name} > %{buildroot}/%{name}

%files
/%{name}

%pre
if [ -e /preinstall_fail ] ; then
    echo "This rpm pre-install script will now exit 1 to test zypp(er) behaviour"
    exit 1
fi
if [ -e /preinstall_wait ] ; then
    echo "This rpm pre-install script will now touch /preinstall_sleeping and wait for 100s to test zypp(er) behaviour"
    touch /preinstall_sleeping
    sleep 100
    rm -f /preinstall_sleeping
fi

%changelog
