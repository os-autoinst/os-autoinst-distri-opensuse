#!/bin/bash -e

if [[ "$(whoami)" == "root" ]] ; then
	buildpath="/usr/src/packages"
else
	buildpath="${HOME}/rpmbuild"
fi

rpmbuild --build-in-place -ba hello0.spec
cp -v ${buildpath}/RPMS/noarch/hello0-0.1-0.noarch.rpm hello0.rpm

for i in {1..9} ; do
	sed "s/hello0/hello${i}/g" hello0.spec > hello${i}.spec
	ls -l hello${i}.spec
	rpmbuild --build-in-place -ba hello${i}.spec
	cp -v ${buildpath}/RPMS/noarch/hello${i}-0.1-0.noarch.rpm hello${i}.rpm
	rm hello${i}.spec
done

