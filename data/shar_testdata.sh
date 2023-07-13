#!/bin/sh
# This is a shell archive (produced by GNU sharutils 4.15.2).
# To extract the files from this archive, save it to some FILE, remove
# everything before the '#!/bin/sh' line above, then type 'sh FILE'.
#
lock_dir=_sh05593
# Made on 2020-07-21 11:38 CEST by <root@kazhua>.
# Source directory was '/var/lib/openqa/share/tests/opensuse/data'.
#
# Existing files will *not* be overwritten, unless '-c' is specified.
#
# This shar contains:
# length mode       name
# ------ ---------- ------------------------------------------
#   5647 -rw-r--r-- shar_testdata/suse.png
#     92 -rw-r--r-- shar_testdata/hallo.txt
#
MD5SUM=${MD5SUM-md5sum}
f=`${MD5SUM} --version | grep -E '^md5sum .*(core|text)utils'`
test -n "${f}" && md5check=true || md5check=false
${md5check} || \
  echo 'Note: not verifying md5sums.  Consider installing GNU coreutils.'
if test "X$1" = "X-c"
then keep_file=''
else keep_file=true
fi
echo=echo
save_IFS="${IFS}"
IFS="${IFS}:"
gettext_dir=
locale_dir=
set_echo=false

for dir in $PATH
do
  if test -f $dir/gettext \
     && ($dir/gettext --version >/dev/null 2>&1)
  then
    case `$dir/gettext --version 2>&1 | sed 1q` in
      *GNU*) gettext_dir=$dir
      set_echo=true
      break ;;
    esac
  fi
done

if ${set_echo}
then
  set_echo=false
  for dir in $PATH
  do
    if test -f $dir/shar \
       && ($dir/shar --print-text-domain-dir >/dev/null 2>&1)
    then
      locale_dir=`$dir/shar --print-text-domain-dir`
      set_echo=true
      break
    fi
  done

  if ${set_echo}
  then
    TEXTDOMAINDIR=$locale_dir
    export TEXTDOMAINDIR
    TEXTDOMAIN=sharutils
    export TEXTDOMAIN
    echo="$gettext_dir/gettext -s"
  fi
fi
IFS="$save_IFS"
if (echo "testing\c"; echo 1,2,3) | grep c >/dev/null
then if (echo -n test; echo 1,2,3) | grep n >/dev/null
     then shar_n= shar_c='
'
     else shar_n=-n shar_c= ; fi
else shar_n= shar_c='\c' ; fi
f=shar-touch.$$
st1=200112312359.59
st2=123123592001.59
st2tr=123123592001.5 # old SysV 14-char limit
st3=1231235901

if   touch -am -t ${st1} ${f} >/dev/null 2>&1 && \
     test ! -f ${st1} && test -f ${f}; then
  shar_touch='touch -am -t $1$2$3$4$5$6.$7 "$8"'

elif touch -am ${st2} ${f} >/dev/null 2>&1 && \
     test ! -f ${st2} && test ! -f ${st2tr} && test -f ${f}; then
  shar_touch='touch -am $3$4$5$6$1$2.$7 "$8"'

elif touch -am ${st3} ${f} >/dev/null 2>&1 && \
     test ! -f ${st3} && test -f ${f}; then
  shar_touch='touch -am $3$4$5$6$2 "$8"'

else
  shar_touch=:
  echo
  ${echo} 'WARNING: not restoring timestamps.  Consider getting and
installing GNU '\''touch'\'', distributed in GNU coreutils...'
  echo
fi
rm -f ${st1} ${st2} ${st2tr} ${st3} ${f}
#
if test ! -d ${lock_dir} ; then :
else ${echo} "lock directory ${lock_dir} exists"
     exit 1
fi
if mkdir ${lock_dir}
then ${echo} "x - created lock directory ${lock_dir}."
else ${echo} "x - failed to create lock directory ${lock_dir}."
     exit 1
fi
# ============= shar_testdata/suse.png ==============
if test ! -d 'shar_testdata'; then
  mkdir 'shar_testdata'
if test $? -eq 0
then ${echo} "x - created directory shar_testdata."
else ${echo} "x - failed to create directory shar_testdata."
     exit 1
fi
fi
if test -n "${keep_file}" && test -f 'shar_testdata/suse.png'
then
${echo} "x - SKIPPING shar_testdata/suse.png (file already exists)"

else
${echo} "x - extracting shar_testdata/suse.png (Text)"
  sed 's/^X//' << 'SHAR_EOF' | uudecode &&
begin 600 shar_testdata/suse.png
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
MJJJJJJJJJK0'AP0`````@OZ_=H,=````````````````````````````````
6@"T&2%@[T&@]E@````!)14Y$KD)@@@``
`
end
SHAR_EOF
  (set 20 20 05 13 12 04 42 'shar_testdata/suse.png'
   eval "${shar_touch}") && \
  chmod 0644 'shar_testdata/suse.png'
if test $? -ne 0
then ${echo} "restore of shar_testdata/suse.png failed"
fi
  if ${md5check}
  then (
       ${MD5SUM} -c >/dev/null 2>&1 || ${echo} 'shar_testdata/suse.png': 'MD5 check failed'
       ) << \SHAR_EOF
67767362e1e234bd9f469bee1fd55b84  shar_testdata/suse.png
SHAR_EOF

else
test `LC_ALL=C wc -c < 'shar_testdata/suse.png'` -ne 5647 && \
  ${echo} "restoration warning:  size of 'shar_testdata/suse.png' is not 5647"
  fi
fi
# ============= shar_testdata/hallo.txt ==============
if test ! -d 'shar_testdata'; then
  mkdir 'shar_testdata'
if test $? -eq 0
then ${echo} "x - created directory shar_testdata."
else ${echo} "x - failed to create directory shar_testdata."
     exit 1
fi
fi
if test -n "${keep_file}" && test -f 'shar_testdata/hallo.txt'
then
${echo} "x - SKIPPING shar_testdata/hallo.txt (file already exists)"

else
${echo} "x - extracting shar_testdata/hallo.txt (Text)"
  sed 's/^X//' << 'SHAR_EOF' | uudecode &&
begin 600 shar_testdata/hallo.txt
M2&%L;&\@5V5L=`I$:65S(&ES="!E:6X@5&5S=`I(96QL;R!7;W)L9`I4:&ES
M(&ES(&$@5&5S=`K0G]&`T+C0LM"UT8(@T+S0N-&`"M&-T8+0OB#1@M"UT8'1
"@@IS
`
end
SHAR_EOF
  (set 20 20 07 21 11 37 51 'shar_testdata/hallo.txt'
   eval "${shar_touch}") && \
  chmod 0644 'shar_testdata/hallo.txt'
if test $? -ne 0
then ${echo} "restore of shar_testdata/hallo.txt failed"
fi
  if ${md5check}
  then (
       ${MD5SUM} -c >/dev/null 2>&1 || ${echo} 'shar_testdata/hallo.txt': 'MD5 check failed'
       ) << \SHAR_EOF
9f05b26393e8d10e5a7b2214e45145f8  shar_testdata/hallo.txt
SHAR_EOF

else
test `LC_ALL=C wc -c < 'shar_testdata/hallo.txt'` -ne 92 && \
  ${echo} "restoration warning:  size of 'shar_testdata/hallo.txt' is not 92"
  fi
fi
if rm -fr ${lock_dir}
then ${echo} "x - removed lock directory ${lock_dir}."
else ${echo} "x - failed to remove lock directory ${lock_dir}."
     exit 1
fi
exit 0
