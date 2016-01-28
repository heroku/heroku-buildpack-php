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
	# TODO: compare the two packages.jsons and error
	# s3cmd --ssl get s3://${src_bucket}${src_prefix}packages.json 2>/dev/null || { echo "No packages.json in source repo" >&2; exit 1; }
	# or even
	# $here/mkrepo.sh $src_bucket $src_prefix 2>/dev/null
)
echo "done." >&2

echo -n "Fetching destination's manifests from s3://${dst_bucket}${dst_prefix}... " >&2
(
	cd $dst_tmp
	out=$(s3cmd --ssl get s3://${dst_bucket}${dst_prefix}*.composer.json 2>&1) || { echo -e "failed! Error:\n$out" >&2; exit 1; }
)
echo "done." >&2

diff=$(diff <(cd $src_tmp; ls -1 *.composer.json) <(cd $dst_tmp; ls -1 *.composer.json 2> /dev/null) || true) # diff exits 1 on difference

copy_to_dst=$(echo "$diff" | grep -E "^<" | sed 's/^< //')
remove_from_dst=$(echo "$diff" | grep -E "^>" | sed 's/^> //')

echo "
WARNING: POTENTIALLY DESTRUCTIVE ACTION!

The following manifests & packages will be COPIED
 from s3://${src_bucket}${src_prefix}
   to s3://${dst_bucket}${dst_prefix}:
$(echo "${copy_to_dst:-(none)}" | sed -e 's/^/  - /' -e 's/.composer.json$//')

The following manifests & packages will be REMOVED
 from s3://${dst_bucket}${dst_prefix}:
$(echo "${remove_from_dst:-(none)}" | sed -e 's/^/  - /' -e 's/.composer.json$//')
" >&2

if [[ ! "$copy_to_dst" && ! "$remove_from_dst" ]]; then
	echo "Nothing to do. Aborting." >&2
	exit
fi

read -p "Are you sure you want to sync to destination & regenerate packages.json? [yN] " proceed

[[ ! $proceed =~ [yY](es)* ]] && exit

echo ""

for manifest in $copy_to_dst; do
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
		    json.dump(manifest, open(sys.argv[7], "w"))
		    print(url[2])
		PYTHON) $src_bucket $src_region $src_prefix $dst_bucket $dst_region $dst_prefix ${dst_tmp}/${manifest})
	then
		# the dist URL in the source's manifest points to the source bucket, so we copy the file to the dest bucket
		echo -n "  - copying '$filename'... " >&2
		out=$(s3cmd ${AWS_ACCESS_KEY_ID+"--access_key=$AWS_ACCESS_KEY_ID"} ${AWS_SECRET_ACCESS_KEY+"--secret_key=$AWS_SECRET_ACCESS_KEY"} --ssl --acl-public cp s3://${src_bucket}${src_prefix}${filename} s3://${dst_bucket}${dst_prefix}${filename} 2>&1) || { echo -e "failed! Error:\n$out" >&2; exit 1; }
		echo "done." >&2
	else
		# the dist URL points somewhere else, so we are not touching that
		echo "  - WARNING: not copying '$filename' (in manifest 'dist.url')" >&2
		# just copy over the manifest (in the above branch, the Python script in the if expression already took care of that)
		cp ${src_tmp}/${manifest} ${dst_tmp}/${manifest}
	fi
	echo -n "  - copying manifest file '$manifest'... " >&2
	out=$(s3cmd ${AWS_ACCESS_KEY_ID+"--access_key=$AWS_ACCESS_KEY_ID"} ${AWS_SECRET_ACCESS_KEY+"--secret_key=$AWS_SECRET_ACCESS_KEY"} --ssl --acl-public put ${dst_tmp}/${manifest} s3://${dst_bucket}${dst_prefix}${manifest} 2>&1) || { echo -e "failed! Error:\n$out" >&2; exit 1; }
	echo "done." >&2
done

for manifest in $remove_from_dst; do
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
		PYTHON) $dst_bucket $dst_region $dst_prefix)
	then
		# the dist URL in the destination manifest points to the destination bucket, so we remove that file
		echo -n "  - removing '$filename'... " >&2
		out=$(s3cmd rm ${AWS_ACCESS_KEY_ID+"--access_key=$AWS_ACCESS_KEY_ID"} ${AWS_SECRET_ACCESS_KEY+"--secret_key=$AWS_SECRET_ACCESS_KEY"} --ssl s3://${dst_bucket}${dst_prefix}${filename} 2>&1) || { echo -e "failed! Error:\n$out" >&2; exit 1; }
		echo "done." >&2
	else
		# the dist URL points somewhere else, so we are not touching that
		echo "  - WARNING: not removing '$filename' (in manifest 'dist.url')" >&2
	fi
	echo -n "  - removing manifest file '$manifest'... " >&2
	out=$(s3cmd rm ${AWS_ACCESS_KEY_ID+"--access_key=$AWS_ACCESS_KEY_ID"} ${AWS_SECRET_ACCESS_KEY+"--secret_key=$AWS_SECRET_ACCESS_KEY"} --ssl s3://${dst_bucket}${dst_prefix}${manifest} 2>&1) || { echo -e "failed! Error:\n$out" >&2; exit 1; }
	rm ${dst_tmp}/${manifest} # not really necessary since we're not re-using that directory to generate a manifest, but just in case someone ever debugs this and wonders...
	echo "done." >&2
done

echo ""

echo -n "Generating packages.json... " >&2
out=$($here/mkrepo.sh $dst_bucket $dst_prefix 2>&1 1>${dst_tmp}/packages.json) || { echo -e "failed! Error:\n$out" >&2; exit 1; }
echo "done." >&2

echo -n "Uploading packages.json to s3://${dst_bucket}${dst_prefix}... " >&2
out=$(s3cmd ${AWS_ACCESS_KEY_ID+"--access_key=$AWS_ACCESS_KEY_ID"} ${AWS_SECRET_ACCESS_KEY+"--secret_key=$AWS_SECRET_ACCESS_KEY"} --ssl --acl-public put ${dst_tmp}/packages.json s3://${dst_bucket}${dst_prefix}packages.json 2>&1) || { echo -e "failed! Error:\n$out" >&2; exit 1; }
echo "done!
$(echo "$out" | grep -E '^Public URL' | sed 's/^Public URL of the object is: http:/Public URL of the repository is: https:/')
" >&2
