#!/usr/bin/env bash

set -eu

if [[ $# -lt "2" || $# -gt "6" ]]; then
	echo "Usage: $(basename $0) DEST_BUCKET DEST_PREFIX [DEST_REGION [SOURCE_BUCKET SOURCE_PREFIX [SOURCE_REGION]]]" >&2
	echo "  DEST_BUCKET:   destination S3 bucket name." >&2
	echo "  DEST_REGION:   destination bucket region, e.g. us-west-1; default: 's3'." >&2
	echo "  DEST_PREFIX:   destination prefix, e.g. '/' or '/dist-stable/'." >&2
	echo "  SOURCE_BUCKET: source S3 bucket name; default: '\$S3_BUCKET'." >&2
	echo "  SOURCE_REGION: source bucket region; default: '\$S3_REGION' or 's3'." >&2
	echo "  SOURCE_PREFIX: source prefix; default: '/\${S3_PREFIX}/'." >&2
	exit 2
fi

dst_bucket=$1; shift
dst_prefix=$1; shift
if [[ $# -gt 2 ]]; then
	# region name given
	dst_region=$1; shift
else
	dst_region="s3"
fi
src_bucket=${1:-$S3_BUCKET}; shift
src_prefix=${1:-/$S3_PREFIX/}; shift
if [[ $# == "1" ]]; then
	# region name given
	src_region=$1; shift
else
	src_region=${S3_REGION:-"s3"}
fi

src_tmp=$(mktemp -d -t "src-repo.XXXXX")
dst_tmp=$(mktemp -d -t "dst-repo.XXXXX")
here=$(cd $(dirname $0); pwd)

# clean up at the end
trap 'rm -rf $src_tmp $dst_tmp;' EXIT

echo -n "Fetching source's manifests from s3://${src_bucket}${src_prefix}... " >&2
(
	cd $src_tmp
	out=$(s3cmd --ssl get s3://${src_bucket}${src_prefix}*.composer.json 2>&1) || { echo -e "failed! Error:\n$out" >&2; exit 1; }
	ls *.composer.json 2>/dev/null 1>&2 || { echo "failed; no manifests found!" >&2; exit 1; }
	out=$(s3cmd --ssl get s3://${src_bucket}${src_prefix}packages.json 2>&1) || { echo -e "No packages.json in source repo:\n$out" >&2; exit 1; }
)
echo "done." >&2

# this mkrepo.sh call won't actually download, but use the given *.composer.json, and echo a generated packages.json
# we use this to compare to the downloaded packages.json
$here/mkrepo.sh $src_bucket $src_prefix ${src_tmp}/*.composer.json 2>/dev/null | python -c 'import sys, json; sys.exit(abs(cmp(json.load(open(sys.argv[1])), json.load(sys.stdin))))' ${src_tmp}/packages.json || {
	echo "WARNING: packages.json from source does not match its list of manifests!" >&2
	echo " You should run 'mkrepo.sh' to update, or ask the bucket maintainers to do so." >&2
	read -p "Would you like to abort this operation? [Yn] " proceed
	[[ ! $proceed =~ [nN]o* ]] && exit 1 # yes is the default so doing yes | sync.sh won't do something stupid
}

echo -n "Fetching destination's manifests from s3://${dst_bucket}${dst_prefix}... " >&2
(
	cd $dst_tmp
	out=$(s3cmd --ssl get s3://${dst_bucket}${dst_prefix}*.composer.json 2>&1) || { echo -e "failed! Error:\n$out" >&2; exit 1; }
)
echo "done." >&2

comm=$(comm <(cd $src_tmp; ls -1 *.composer.json) <(cd $dst_tmp; ls -1 *.composer.json 2> /dev/null)) # comm produces three columns of output: entries only in left file, entries only in right file, entries in both
add_manifests=$(echo "$comm" | grep '^\S' || true) # no tabs means output in col 1 = files only in src
remove_manifests=$(echo "$comm" | grep '^\s\S' | cut -c2- || true) # one tab means output in col 2 = files only in dst
common=$(echo "$comm" | grep '^\s\s' | cut -c3- || true) # two tabs means output in col 3 = files in both
update_manifests=()
ignore_manifests=()
for filename in $common; do
	result=0
	python <(cat <<-'PYTHON' # beware of single quotes in body
		import sys, json, os, datetime;
		src_manifest = json.load(open(sys.argv[1]))
		dst_manifest = json.load(open(sys.argv[2]))
		# remove URLs so they don't interfere with comparison
		src_manifest.get("dist", {}).pop("url", None)
		dst_manifest.get("dist", {}).pop("url", None)
		# same for times, but we'll look at them
		try:
		    src_time = datetime.datetime.strptime(src_manifest.pop("time"), "%Y-%m-%d %H:%M:%S") # UTC
		except KeyError, ValueError:
		    src_time = datetime.datetime.utcfromtimestamp(os.path.getmtime(sys.argv[1]))
		    print >> sys.stderr, "WARNING: source manifest "+os.path.basename(sys.argv[1])+" has invalid time entry, using mtime: "+src_time.isoformat()
		try:
		    dst_time = datetime.datetime.strptime(dst_manifest.pop("time"), "%Y-%m-%d %H:%M:%S") # UTC
		except KeyError, ValueError:
		    dst_time = datetime.datetime.utcfromtimestamp(os.path.getmtime(sys.argv[2]))
		    print >> sys.stderr, "WARNING: destination manifest "+os.path.basename(sys.argv[2])+" has invalid time entry, using mtime: "+dst_time.isoformat()
		# a newer source time means we will copy
		if src_time > dst_time:
		    sys.exit(0)
		else:
		    # 1 = content identical, src_time = dst_time (up to date)
		    # 3 = content different, src_time = dst_time (weird)
		    # 5 = content identical, src_time < dst_time (probably needs sync the other way)
		    # 7 = content different, src_time < dst_time (probably needs sync the other way)
		    ret = 1
		    ret = ret | abs(cmp(src_manifest, dst_manifest))<<1
		    ret = ret | (src_time < dst_time)<<2
		    sys.exit(ret)
		PYTHON
	) $src_tmp/$filename $dst_tmp/$filename || result=$?
	if [[ $result -eq 0 ]]; then
		update_manifests+=($filename)
	elif [[ $result != "1" ]]; then
		case $result in
			3)
				ignore_manifests+=("$filename (contents differ, time fields identical!?)")
				;;
			5)
				ignore_manifests+=("$filename (contents match, destination manifest newer)")
				;;
			7)
				ignore_manifests+=("$filename (contents differ, destination manifest newer)")
				;;
		esac
	fi
done

echo "
WARNING: POTENTIALLY DESTRUCTIVE ACTION!

The following packages will be IGNORED:
$(IFS=$'\n'; echo "${ignore_manifests[*]:-(none)}" | sed -e 's/^/  - /' -e 's/.composer.json$//')

The following packages will be ADDED
 from s3://${src_bucket}${src_prefix}
   to s3://${dst_bucket}${dst_prefix}:
$(echo "${add_manifests:-(none)}" | sed -e 's/^/  - /' -e 's/.composer.json$//')

The following packages will be UPDATED (source manifest is newer)
 from s3://${src_bucket}${src_prefix}
   to s3://${dst_bucket}${dst_prefix}:
$(IFS=$'\n'; echo "${update_manifests[*]:-(none)}" | sed -e 's/^/  - /' -e 's/.composer.json$//')

The following packages will be REMOVED
 from s3://${dst_bucket}${dst_prefix}:
$(echo "${remove_manifests:-(none)}" | sed -e 's/^/  - /' -e 's/.composer.json$//')
" >&2

if [[ ! "$add_manifests" && ! "$remove_manifests" && "${#update_manifests[@]}" -eq 0 ]]; then
	echo "Nothing to do. Aborting." >&2
	exit
fi

read -p "Are you sure you want to sync to destination & regenerate packages.json? [yN] " proceed

[[ ! $proceed =~ [yY](es)* ]] && exit

echo ""

copied_files=()
for manifest in $add_manifests ${update_manifests[@]:-}; do
	echo "Copying ${manifest%.composer.json}:" >&2
	if filename=$(cat ${src_tmp}/${manifest} | python <(cat <<-'PYTHON' # beware of single quotes in body
		import sys, json;
		manifest=json.load(sys.stdin)
		url=manifest.get("dist",{}).get("url","").partition("https://"+sys.argv[1]+"."+sys.argv[2]+".amazonaws.com"+sys.argv[3])
		if url[0]:
		    # dist URL does not match https://${src_bucket}.${src_region}.amazonaws.com${src_prefix}
		    print(url[0])
		    sys.exit(1)
		else:
		    # rewrite dist URL in manifest to destination bucket
		    manifest["dist"]["url"] = "https://"+sys.argv[4]+"."+sys.argv[5]+".amazonaws.com"+sys.argv[6]+url[2]
		    json.dump(manifest, open(sys.argv[7], "w"), sort_keys=True)
		    print(url[2])
		PYTHON
	) $src_bucket $src_region $src_prefix $dst_bucket $dst_region $dst_prefix ${dst_tmp}/${manifest})
	then
		# the dist URL in the source's manifest points to the source bucket, so we copy the file to the dest bucket
		echo -n "  - copying '$filename'... " >&2
		out=$(s3cmd ${AWS_ACCESS_KEY_ID+"--access_key=$AWS_ACCESS_KEY_ID"} ${AWS_SECRET_ACCESS_KEY+"--secret_key=$AWS_SECRET_ACCESS_KEY"} --ssl --acl-public cp s3://${src_bucket}${src_prefix}${filename} s3://${dst_bucket}${dst_prefix}${filename} 2>&1) || { echo -e "failed! Error:\n$out" >&2; exit 1; }
		copied_files+=("$filename")
		echo "done." >&2
	else
		# the dist URL points somewhere else, so we are not touching that
		echo "  - WARNING: not copying '$filename' (in manifest 'dist.url')!" >&2
		# just copy over the manifest (in the above branch, the Python script in the if expression already took care of that)
		cp ${src_tmp}/${manifest} ${dst_tmp}/${manifest}
	fi
	echo -n "  - copying manifest file '$manifest'... " >&2
	out=$(s3cmd ${AWS_ACCESS_KEY_ID+"--access_key=$AWS_ACCESS_KEY_ID"} ${AWS_SECRET_ACCESS_KEY+"--secret_key=$AWS_SECRET_ACCESS_KEY"} --ssl --acl-public put ${dst_tmp}/${manifest} s3://${dst_bucket}${dst_prefix}${manifest} 2>&1) || { echo -e "failed! Error:\n$out" >&2; exit 1; }
	echo "done." >&2
done

remove_files=()
for manifest in $remove_manifests; do
	echo "Removing ${manifest%.composer.json}:" >&2
	if filename=$(cat ${dst_tmp}/${manifest} | python <(cat <<-'PYTHON' # beware of single quotes in body
		import sys, json;
		manifest=json.load(sys.stdin)
		url=manifest.get("dist",{}).get("url","").partition("https://"+sys.argv[1]+"."+sys.argv[2]+".amazonaws.com"+sys.argv[3])
		if url[0]:
		    # dist URL does not match https://${dst_bucket}.${dst_region}.amazonaws.com${dst_prefix}
		    print(url[0])
		    sys.exit(1)
		else:
		    print(url[2])
		PYTHON
	) $dst_bucket $dst_region $dst_prefix)
	then
		# the dist URL in the destination manifest points to the destination bucket, so we remove that file at the end of the script...
		if [[ " ${copied_files[@]:-} " =~ " $filename " ]]; then
			# ...unless it was copied earlier (may happen if a new/updated manifest points to the same file name that this to-be-removed one is using)
			echo "  - NOTICE: keeping newly copied '$filename'!" >&2
		else
			echo "  - queued '$filename' for removal." >&2
			remove_files+=("$filename")
		fi
	else
		# the dist URL points somewhere else, so we are not touching that
		echo "  - WARNING: not removing '$filename' (in manifest 'dist.url')!" >&2
	fi
	echo -n "  - removing manifest file '$manifest'... " >&2
	out=$(s3cmd rm ${AWS_ACCESS_KEY_ID+"--access_key=$AWS_ACCESS_KEY_ID"} ${AWS_SECRET_ACCESS_KEY+"--secret_key=$AWS_SECRET_ACCESS_KEY"} --ssl s3://${dst_bucket}${dst_prefix}${manifest} 2>&1) || { echo -e "failed! Error:\n$out" >&2; exit 1; }
	rm ${dst_tmp}/${manifest}
	echo "done." >&2
done

echo ""

echo -n "Generating and uploading packages.json... " >&2
out=$(cd $dst_tmp; $here/mkrepo.sh --upload $dst_bucket $dst_prefix *.composer.json 2>&1) || { echo -e "failed! Error:\n$out" >&2; exit 1; }
echo "done!
$(echo "$out" | grep -E '^Public URL' | sed 's/^Public URL of the object is: http:/Public URL of the repository is: https:/')
" >&2

if [[ "${#remove_files[@]}" != "0" ]]; then
	echo "Removing files queued for deletion from destination:" >&2
	for filename in "${remove_files[@]}"; do
		echo -n "  - removing '$filename'... " >&2
		out=$(s3cmd rm ${AWS_ACCESS_KEY_ID+"--access_key=$AWS_ACCESS_KEY_ID"} ${AWS_SECRET_ACCESS_KEY+"--secret_key=$AWS_SECRET_ACCESS_KEY"} --ssl s3://${dst_bucket}${dst_prefix}${filename} 2>&1) && echo "done." >&2 || echo -e "failed! Error:\n$out" >&2
	done
	echo ""
fi

echo "Sync complete.
"
