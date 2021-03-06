#!/bin/sh
set -e

[ -z "$SOURCE_DATE_EPOCH" ] || {
	PYTHONHASHSEED="$SOURCE_DATE_EPOCH"
	export PYTHONHASHSEED
}

process_filespec() {
	local src_dir="$1"
	local dst_dir="$2"
	local filespec="$3"
	echo "$filespec" | (
	IFS='|'
	while read fop fspec fperm; do
		local fop=`echo "$fop" | tr -d ' \t\n'`
		if [ "$fop" = "+" ]; then
			if [ ! -e "${src_dir}${fspec}" ]; then
				echo "File not found '${src_dir}${fspec}'"
				exit 1
			fi
			dpath=`dirname "$fspec"`
			if [ -z "$fperm" ]; then
				dperm=`stat -c "%a" ${src_dir}${dpath}`
			fi
			mkdir -p -m$dperm ${dst_dir}${dpath}
			echo "copying: '$fspec'"
			cp -fpR ${src_dir}${fspec} ${dst_dir}${dpath}/
			if [ -n "$fperm" ]; then
				chmod -R $fperm ${dst_dir}${fspec}
			fi
		elif [ "$fop" = "-" ]; then
			echo "removing: '$fspec'"
			rm -fR ${dst_dir}${fspec}
		elif [ "$fop" = "=" ]; then
			echo "setting permissions: '$fperm' on '$fspec'"
			chmod -R $fperm ${dst_dir}${fspec}
		fi
	done
	)
}

ver="$1"
src_dir="$2"
dst_dir="$3"
python="$4"
mode="$5"
filespec="$6"

process_filespec "$src_dir" "$dst_dir" "$filespec" || {
	echo "process filespec error-ed"
	exit 1
}

if [ "$mode" == "sources" ] ; then
	# Copy only python source files
	find $dst_dir -not -type d -not -name "*\.py" | xargs rm -f

	# Delete empty folders (if the case)
	if [ -d "$dst_dir/usr" ] ; then
		find $dst_dir/usr -type d | xargs rmdir --ignore-fail-on-non-empty
		rmdir --ignore-fail-on-non-empty $dst_dir/usr
	fi
	exit 0
fi

legacy=
[ "$ver" == "3" ] && legacy="-b"

# XXX [So that you won't goof as I did]
# Note: Yes, I tried to use the -O & -OO flags here.
#       However the generated byte-codes were not portable.
#       So, we just stuck to un-optimized byte-codes,
#       which is still way better/faster than running
#       Python sources all the time.
$python -m compileall $legacy -d '/' $dst_dir || {
	echo "python -m compileall err-ed"
	exit 1
}

# Delete source files and pyc [ un-optimized bytecode files ]
# We may want to make this optimization thing configurable later, but not sure atm
find $dst_dir -type f -name "*\.py" | xargs rm -f

# Delete empty folders (if the case)
if [ -d "$dst_dir/usr" ] ; then
	find $dst_dir/usr -type d | xargs rmdir --ignore-fail-on-non-empty
	rmdir --ignore-fail-on-non-empty $dst_dir/usr
fi

exit 0
