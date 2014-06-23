test:
	export PERL5LIB='../..:os-autoinst:lib' ; for f in `find . -name \*.pm` ; do perl -c $$f 2>&1 | grep -v " OK$$" && exit 2; done ; true
