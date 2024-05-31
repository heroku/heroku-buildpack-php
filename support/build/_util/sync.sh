#!/usr/bin/env bash

set -eu
set -o pipefail

# some s5cmd behavior notes
# `s5cmd run` with one succeeding and one failing cp or ls returns 1
# progress infos (e.g. lines from cp) go to stdout, also for --json
# errors go to stderr, also for --json :(
# when using --progress, no output goes to stdout, but errors are mixed with progress info
S5CMD_OPTIONS=(${S5CMD_NO_SIGN_REQUEST:+--no-sign-request} ${S5CMD_PROFILE:+--profile "${S5CMD_PROFILE}"} --log error)

localsrc=
localdst=

remove=true

# process flags
optstring=":-:d:s:"
while getopts "$optstring" opt; do
	case $opt in
		d)
			localdst=$OPTARG
			;;
		s)
			localsrc=$OPTARG
			;;
		-)
			case "$OPTARG" in
				no-remove)
					remove=false
					;;
				*)
					echo "Invalid option: --$OPTARG" >&2
					exit 2
					;;
			esac
	esac
done
# clear processed arguments
shift $((OPTIND-1))

if [[ $# -lt "2" || $# -gt "6" ]]; then
	cat >&2 <<-EOF
		Usage: $(basename "$0") [--no-remove] [-d DEST_DIR] [-s SRC_DIR] DEST_BUCKET DEST_PREFIX [DEST_REGION [SOURCE_BUCKET SOURCE_PREFIX [SOURCE_REGION]]]
		  DEST_BUCKET:   destination S3 bucket name.
		  DEST_PREFIX:   destination prefix, e.g. '' or 'dist-stable/'.
		  DEST_REGION:   destination bucket region, e.g. 'us-west-1'; auto-detected if not given.
		  SOURCE_BUCKET: source S3 bucket name; default: '\$S3_BUCKET'.
		  SOURCE_PREFIX: source prefix; default: '\$S3_PREFIX'.
		  SOURCE_REGION: source bucket region; default: '\$S3_REGION'; auto-detected if not given.
		  -d DEST_DIR:   use local directory <DEST_DIR> as destination instead of fetching from S3,
		                 this will then not perform any operations, only print a summary.
		  -s SOURCE_DIR: use local directory <SOURCE_DIR> as source instead of fetching from S3.
		  --no-remove:   no removal of destination packages that are not in source bucket.
	EOF
	exit 2
fi

dst_bucket=$1; shift
dst_prefix=$1; shift
if [[ $# -gt 2 ]]; then
	# region name given
	dst_region=$1; shift
else
	# grep out the region (it's there even on 403 responses), and trim whitespace via xargs - important to use grep -o and discard trailing whitespace, otherwise we'll end up with a carriage return at the end of the value
	dst_region=$(set -o pipefail; curl -sI "https://${dst_bucket}.s3.amazonaws.com/" | grep -E -o -i "^x-amz-bucket-region:\s*\S+" | cut -d: -f2 | xargs || { echo >&2 "Failed to determine region for S3 bucket '$dst_bucket'"; exit 1; })
fi

src_bucket=${1:-$S3_BUCKET}; shift || true
src_prefix=${1:-$S3_PREFIX}; shift || true
if [[ $# == "1" ]]; then
	# region name given
	src_region=$1; shift
else
	# grep out the region (it's there even on 403 responses), and trim whitespace via xargs - important to use grep -o and discard trailing whitespace, otherwise we'll end up with a carriage return at the end of the value
	src_region=${S3_REGION:-$(set -o pipefail; curl -sI "https://${src_bucket}.s3.amazonaws.com/" | grep -E -o -i "^x-amz-bucket-region:\s*\S+" | cut -d: -f2 | xargs || { echo >&2 "Failed to determine region for S3 bucket '$src_bucket'"; exit 1; })}
fi

if [[ "$src_region" != "$dst_region" ]]; then
	echo "CAUTION: Source and destination regions differ. Sync may run into rate limits." >&2
	echo "" >&2
fi

here=$(cd "$(dirname "$0")"; pwd)

downloads=()

if [[ $localsrc && $localdst ]]; then
	src_tmp=$localsrc
	dst_tmp=$localdst
elif [[ $localsrc ]]; then
	# clean up at the end
	trap 'rm -rf "$dst_tmp";' EXIT
	
	src_tmp=$localsrc
	dst_tmp=$(mktemp -d -t "dst-repo.XXXXX")
elif [[ $localdst ]]; then
	# clean up at the end
	trap 'rm -rf "$src_tmp";' EXIT
	
	src_tmp=$(mktemp -d -t "src-repo.XXXXX")
	dst_tmp=$localdst
else
	# clean up at the end
	trap 'rm -rf "$src_tmp" "$dst_tmp";' EXIT
	
	src_tmp=$(mktemp -d -t "src-repo.XXXXX")
	dst_tmp=$(mktemp -d -t "dst-repo.XXXXX")
fi

if [[ ! $localsrc ]]; then
	cat >&2 <<-EOF
		Fetching source repository
		  from s3://${src_bucket}/${src_prefix}...
	EOF
	s5cmd "${S5CMD_OPTIONS[@]}" cp --source-region "$src_region" "s3://${src_bucket}/${src_prefix}packages.json" "$src_tmp" || { echo -e "\nFailed to fetch repository! See message above for errors." >&2; exit 1; }
	
	src_manifests="s3://${src_bucket}/${src_prefix}*.composer.json"
	
	# this is for an 's5cmd run' later, so we're generating quoted arguments
	downloads+=("cp --source-region ${src_region@Q} ${src_manifests@Q} ${src_tmp@Q}")
fi

if [[ ! $localdst ]]; then
	dst_manifests="s3://${dst_bucket}/${dst_prefix}*.composer.json"
	
	cat >&2 <<-EOF
		Checking destination bucket
		  s3://${dst_bucket}/${dst_prefix}...
	EOF
	dst_ls_json=$(AWS_REGION=$dst_region s5cmd "${S5CMD_OPTIONS[@]}" --json ls "${dst_manifests}" 2>&1) && {
		# this is for an 's5cmd run' later, so we're generating quoted arguments
		downloads+=("cp --source-region ${dst_region@Q} ${dst_manifests@Q} ${dst_tmp@Q}")
	} || {
		# if we're using a local source, but there is no dest... something is wrong, bail out
		[[ $localsrc ]] && { echo -e "\nDestination bucket access failed. Error info:\n${dst_ls_json}" >&2; exit 1; }
		# we encountered an error; let's look at the error output - if it's just a "no object found", then we can proceed
		jq -e '.error == "no object found"' >/dev/null <<<"$dst_ls_json" || { echo -e "\nDestination bucket access failed. Error info:\n${dst_ls_json}" >&2; exit 1; }
		echo "Destination is empty; proceeding." >&2
	}
fi

if (( ${#downloads[@]} )); then
	echo "Fetching manifests... " >&2
	printf "%s\n" "${downloads[@]}" | s5cmd "${S5CMD_OPTIONS[@]}" run || { echo -e "\nFailed to fetch manifests! See message above for errors." >&2; exit 1; }
fi

echo "" >&2

# this mkrepo.sh call won't actually download, but use the given *.composer.json, and echo a generated packages.json
# we use this to compare to the downloaded packages.json
# unless we're using a local source dir, because that can be used for easy removals
[[ $localsrc ]] || S3_BUCKET=$src_bucket S3_PREFIX=$src_prefix S3_REGION=$src_region "$here/mkrepo.sh" "${src_tmp}"/*.composer.json 2>/dev/null | python -c 'import sys, json; sys.exit(json.load(open(sys.argv[1])) != json.load(sys.stdin))' "${src_tmp}"/packages.json || {
	cat >&2 <<-EOF
		WARNING: packages.json from source does not match its list of manifests!
		 You should run 'mkrepo.sh' to update, or ask the bucket maintainers to do so.
	EOF
	read -rp "Would you like to abort this operation? [Yn] " proceed
	[[ ! $proceed =~ [nN]o* ]] && exit 1 # yes is the default so doing yes | sync.sh won't do something stupid
	echo "" >&2
}

# from the given src and dst, figure out the necessary operations
# if the destination is a local dir (e.g. for testing purposes), --dry-run will prevent sync.py from mutating the to-be-changed manifests in place (or removing removals)
# TODO corner cases:
# - package update changes dist URL (then dst dist needs removal and src dist needs copy)
# - package removal has same dist URL as addition or update (then removal must be skipped due to the overwrite)
ops=$(python "$here/include/sync.py" ${localdst:+--dry-run} "$src_region" "$src_bucket" "$src_prefix" "$src_tmp" "$dst_region" "$dst_bucket" "$dst_prefix" "$dst_tmp")

lookup_ignored_dists='([.[] | select(.kind == "dist" and (.skip // false) == true) | {(.package): (.source // .destination) }] | add) as $lookup'
human_manifest_message='(if $lookup[.package] then " (manifest only, dist is external)" else "" end) as $dist_note | "\(.package)\($dist_note)"'

readarray -t run_dists_cp < <(jq -r '.[] | select((.skip // false) == false) | select(.op == "add" or .op == "update") | select(.kind == "dist") | @sh "cp --source-region \(."source-region") --destination-region \(."destination-region") \(.source) \(.destination)"' <<<"$ops")
# echo "Dist copies:"
# printf -- "- %s\n" "${run_dists_cp[@]}"

manifests_cp_filter='.[] | select((.skip // false) == false) | select(.op == "add" or .op == "update") | select(.kind == "manifest")'
readarray -t run_manifests_cp < <(jq -r "$manifests_cp_filter"' | @sh "cp --destination-region \(."destination-region") \(.source) \(.destination)"' <<<"$ops")
readarray -t human_manifests_add < <(jq -r "$lookup_ignored_dists | $manifests_cp_filter"' | select(.op == "add") | '"$human_manifest_message" <<<"$ops" | sort --version-sort)
readarray -t human_manifests_upd < <(jq -r "$lookup_ignored_dists | $manifests_cp_filter"' | select(.op == "update") |'"$human_manifest_message" <<<"$ops" | sort --version-sort)
# echo "Manifest copies:"
# printf -- "- %s\n" "${run_manifests_cp[@]}"

manifests_rm_filter='.[] | select((.skip // false) == false) | select(.op == "remove") | select(.kind == "manifest")'
readarray -t run_manifests_rm < <(jq -r "$manifests_rm_filter"' | @sh "rm \(.destination)"' <<<"$ops")
readarray -t human_manifests_rm < <(jq -r "$lookup_ignored_dists | $manifests_rm_filter"' | '"$human_manifest_message" <<<"$ops" | sort --version-sort)
# echo "Manifest removals:"
# printf -- "- %s\n" "${run_manifests_rm[@]}"

dists_rm_filter='.[] | select((.skip // false) == false) | select(.op == "remove") | select(.kind == "dist")'
readarray -t run_dists_rm < <(jq -r "$dists_rm_filter"' | @sh "rm \(.destination)"' <<<"$ops")
# echo "Dist removals:"
# printf -- "- %s\n" "${run_dists_rm[@]}"

readarray -t ign_dists_cp < <(jq -r '.[] | select((.skip // false) == true) | select(.op == "add" or .op == "update") | select(.kind == "dist") | @sh "cp \(.source)"' <<<"$ops")
# echo "Dist copy ignores:"
# printf -- "- %s\n" "${ign_dists_cp[@]}"

manifests_cp_ign_filter='.[] | select((.skip // false) == true) | select(.op == "add" or .op == "update") | select(.kind == "manifest")'
readarray -t ign_manifests_cp < <(jq -r "$manifests_cp_ign_filter"' | @sh "cp \(.source)"' <<<"$ops")
readarray -t human_manifests_ign < <(jq -r "$manifests_cp_ign_filter"' | "\(.package) (\(.reason))"' <<<"$ops" | sort --version-sort)
# echo "Manifest copy ignores:"
# printf -- "- %s\n" "${ign_manifests_cp[@]}"

readarray -t ign_manifests_rm < <(jq -r '.[] | select((.skip // false) == true) | select(.op == "remove") | select(.kind == "manifest") | @sh "rm \(.destination)"' <<<"$ops")
# echo "Manifest removal ignores:"
# printf -- "- %s\n" "${ign_manifests_rm[@]}"

readarray -t ign_dists_rm < <(jq -r '.[] | select((.skip // false) == true) | select(.op == "remove") | select(.kind == "dist") | @sh "rm \(.destination)"' <<<"$ops")
# echo "Dist removal ignores:"
# printf -- "- %s\n" "${ign_dists_rm[@]}"

# we print a summary for folks to confirm the operations

(( ${#human_manifests_ign[@]} )) && cat >&2 <<-EOF
	The following packages will be IGNORED:
	$(printf -- "  - %s\n" "${human_manifests_ign[@]:-(none)}")

EOF
(( ${#human_manifests_add[@]} )) && cat >&2 <<-EOF
	The following packages will be ADDED
	 from s3://${src_bucket}/${src_prefix}
	   to s3://${dst_bucket}/${dst_prefix}:
	$(printf -- "  - %s\n" "${human_manifests_add[@]:-(none)}")

EOF
(( ${#human_manifests_upd[@]} )) && cat >&2 <<-EOF
	The following packages will be UPDATED (source manifest is newer)
	 from s3://${src_bucket}/${src_prefix}
	   to s3://${dst_bucket}/${dst_prefix}:
	$(printf -- "  - %s\n" "${human_manifests_upd[@]:-(none)}")

EOF
(( ${#human_manifests_rm[@]} )) && cat >&2 <<-EOF
	The following packages will $($remove || echo -n "NOT ")be REMOVED
	 from s3://${dst_bucket}/${dst_prefix}$($remove && echo -n ":")$($remove || echo -ne "\n because '--no-remove' was given:")
	$(printf -- "  - %s\n" "${human_manifests_rm[@]:-(none)}")

EOF
# clear removal jobs if --no-remove given
$remove || {
	run_manifests_rm=()
	run_dists_rm=()
}

if [[ $localdst ]] || (( !${#run_manifests_cp[@]} && !${#run_manifests_rm[@]} )); then
	echo "Nothing to do" ${localdst:+"with local dir as destination"} "- aborting." >&2
	exit
fi

(cd "$dst_tmp"; shopt -s nullglob; manifests=( *.composer.json ); (( ${#manifests[@]} < 1 )) ) && {
	wipe=true
	prompt="Are you sure you want to remove all packages from destination?"
	cat >&2 <<-EOF
		THE REMOVALS ABOVE WILL DELETE THIS REPOSITORY IN ITS ENTIRETY!
		THE RESULTING EMPTY packages.json WILL BE REMOVED AS WELL!
		
	EOF
} || {
	wipe=false
	prompt="Are you sure you want to sync to destination & re-generate packages.json?"
}

cat >&2 <<-EOF
	WARNING: POTENTIALLY DESTRUCTIVE ACTION!
	
EOF

read -p "${prompt} [yN] " proceed

[[ ! $proceed =~ [yY](es)* ]] && { echo -e "Sync aborted.\n" >&2; exit; }

echo "" >&2

# we perform our operations in three consecutive groups (each group runs all its tasks in parallel via s5cmd):
# 1) copy all dists files from src bucket to dst bucket
# 2) upload all new/changed manifests to dst bucket and remove all removed manifests from dst bucket
# 3) remove all removed dists from dst bucket
# the purpose of this is to ensure we do not get into a broken state when e.g. the network is interrupted, process dies, etc
# if anything goes wrong during 1), the dists will all be copied again when we perform the operation again
# if anything goes wrong during 2), all the new/changed dists for which manifests were copied are already there from 1), and for removed manifests, no dists are gone yet
# if anything goes wrong during 3), worst case we'll end up with a few stray dist files that should not be there, but won't be used since their manifests are already gone

if (( ${#run_dists_cp[@]} )); then
	echo "Copying ${#run_dists_cp[@]} new or updated dists to destination..." >&2
	printf -- "%s\n" "${run_dists_cp[@]}" | s5cmd "${S5CMD_OPTIONS[@]}" run || { echo -e "\nOne or more operation(s) failed. In case of transient errors, it is safe to re-run the sync." >&2; exit 1; }
	echo "" >&2
fi

if (( ${#run_manifests_cp[@]} || ${#run_manifests_rm[@]} )); then
	echo "Copying ${#run_manifests_cp[@]} new or updated manifests to, and removing ${#run_manifests_rm[@]} manifests from, destination..." >&2
	printf -- "%s\n" "${run_manifests_cp[@]}" "${run_manifests_rm[@]}" | s5cmd "${S5CMD_OPTIONS[@]}" run || { echo -e "\nOne or more operation(s) failed. In case of transient errors, it is safe to re-run the sync." >&2; exit 1; }
	echo "" >&2
fi

if $wipe; then
	echo "Removing packages.json..." >&2
	AWS_REGION=$dst_region s5cmd "${S5CMD_OPTIONS[@]}" rm "s3://${dst_bucket}/${dst_prefix}packages.json" || { echo -e "\nFailed to remove repository! See message above for errors." >&2; exit 1; }
else
	echo "Generating and uploading packages.json..." >&2
	out=$(cd "$dst_tmp"; S3_BUCKET=$dst_bucket S3_PREFIX=$dst_prefix S3_REGION=$dst_region "$here/mkrepo.sh" --upload *.composer.json 2>&1) || { echo -e "\nFailed to generate/upload repository! Error:\n$out\n\nIn case of transient errors, the repository must be re-generated manually." >&2; exit 1; }
fi
echo "" >&2

if (( ${#run_dists_rm[@]} )); then
	echo "Removing ${#run_dists_rm[@]} dists from destination..." >&2
	printf -- "%s\n" "${run_dists_rm[@]}" | s5cmd "${S5CMD_OPTIONS[@]}" run || { echo -e "\nOne or more operation(s) failed. In case of transient errors, failed removals must be performed manually." >&2; exit 1; }
	echo "" >&2
fi

echo -e "Sync complete.\n" >&2
