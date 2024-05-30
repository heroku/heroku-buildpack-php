import sys, json, os, glob, datetime, re, argparse
from contextlib import contextmanager
from enum import IntFlag
from pathlib import Path

class ManifestDifference(IntFlag):
    CONTENTS = 1
    SRC_NEWER = 2
    DST_NEWER = 4

# for Python < 3.10, where glob.glob() has no root_dir kwarg
@contextmanager
def chdir(path):
    cwd = os.getcwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(cwd)

def serialize_datetime(obj):
    if isinstance(obj, (datetime.datetime, datetime.date)):
        return obj.strftime("%Y-%m-%d %H:%M:%S")
    raise TypeError ("Cannot serialize type %s as JSON" % type(obj))

def parse_manifest(path):
    manifest = json.load(open(path))
    try:
        dt = datetime.datetime.strptime(manifest.pop("time"), "%Y-%m-%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc)
    except (KeyError, ValueError):
        dt = datetime.datetime.fromtimestamp(os.path.getmtime(path), tz=datetime.timezone.utc)
        print("WARNING: manifest {} has invalid time entry, using mtime: {}".format(os.path.basename(path), serialize_datetime(dt)), file=sys.stderr)
    manifest["time"] = dt
    return manifest

def manifests_difference(src_manifest, dst_manifest):
    src_copy = src_manifest.copy()
    dst_copy = dst_manifest.copy()
    
    ret = 0
    
    # a newer source time means we will copy
    if src_copy["time"] > dst_copy["time"]:
        ret |= ManifestDifference.SRC_NEWER
    elif src_copy["time"] < dst_copy["time"]:
        ret |= ManifestDifference.DST_NEWER
    
    src_copy.pop("time")
    dst_copy.pop("time")
    src_copy.pop("dist")
    dst_copy.pop("dist")
    
    if src_copy != dst_copy:
        ret |= ManifestDifference.CONTENTS
    
    return ret

def rewrite_dist(manifest, src_region, src_bucket, src_prefix, dst_region, dst_bucket, dst_prefix):
    # pattern for basically "https://lang-php.(s3.us-east-1|s3).amazonaws.com/dist-heroku-22-stable/"
    # this ensures old packages are correctly handled even when they do not contain the region in the URL
    s3_url_re=re.escape("https://{}.".format(src_bucket))
    s3_url_re+=r"(?:s3.{}|s3)".format(re.escape(src_region))
    s3_url_re+=re.escape(".amazonaws.com/{}".format(src_prefix))
    s3_url_re+=r"([^?]+)(\?.*)?"
    url=manifest.get("dist",{}).get("url","")
    r = re.match(s3_url_re, url)
    if r:
        # rewrite dist URL in manifest to destination bucket
        manifest["dist"]["url"] = r.expand("https://{}.s3.{}.amazonaws.com/{}\\1\\2".format(dst_bucket, dst_region, dst_prefix))
        return {"kind": "dist", "source": "s3://{}/{}{}".format(src_bucket, src_prefix, r.group(1)), "source-region": src_region, "destination": "s3://{}/{}{}".format(dst_bucket, dst_prefix, r.group(1)), "destination-region": dst_region}
    else:
        return {"kind": "dist", "skip": True, "source": url, "reason": "file located outside of bucket"}

parser = argparse.ArgumentParser()
parser.add_argument("--dry-run", action="store_true")
parser.add_argument("src_region")
parser.add_argument("src_bucket")
parser.add_argument("src_prefix")
parser.add_argument("src_dir")
parser.add_argument("dst_region")
parser.add_argument("dst_bucket")
parser.add_argument("dst_prefix")
parser.add_argument("dst_dir")
args = parser.parse_args()

src_region = args.src_region
src_bucket = args.src_bucket
src_prefix = args.src_prefix
src_dir = Path(args.src_dir)

dst_region = args.dst_region
dst_bucket = args.dst_bucket
dst_prefix = args.dst_prefix
dst_dir = Path(args.dst_dir)

# we cannot use Path.glob, since we need the file names only, for comparison
# using our chdir context manager for compatibility with Python < 3.10, where glob.glob() has no root_dir kwarg
with chdir(src_dir):
    src = set(glob.glob("*.composer.json"))
with chdir(dst_dir):
    dst = set(glob.glob("*.composer.json"))

add = src - dst
rem = dst - src
upd = src & dst

ops = []

# anything not in dst is copied from src
for manifest_file in add:
    package = re.sub(r"\.composer\.json$", "", manifest_file)
    manifest = parse_manifest(src_dir/manifest_file)
    # rewrite dist.url to point to dst bucket (if it's a URL in src bucket)
    dist_op = rewrite_dist(manifest, src_region, src_bucket, src_prefix, dst_region, dst_bucket, dst_prefix)
    dist_op["op"] = "add"
    dist_op["package"] = package
    # copy operation for the dist file (might also be an ignore if the URL isn't in the src bucket)
    ops.append(dist_op)
    # create dst manifest
    args.dry_run or json.dump(manifest, open(dst_dir / manifest_file, "w"), sort_keys=True, default=serialize_datetime)
    # copy operation from local dst manifest to dst bucket
    ops.append({"kind": "manifest", "op": "add", "package": package, "source": dst_dir/manifest_file, "destination": "s3://{}/{}{}".format(dst_bucket, dst_prefix, manifest_file), "destination-region": dst_region})

for manifest_file in rem:
    package = re.sub(r"\.composer\.json$", "", manifest_file)
    manifest = parse_manifest(dst_dir / manifest_file)
    # we're just checking if this file qualifies for copying - that'll tell us whether we have to remove it or not
    dist_op = rewrite_dist(manifest, dst_region, dst_bucket, dst_prefix, src_region, src_bucket, src_prefix)
    if dist_op.get("skip", False) == False:
        # it would be copied, so it's in the bucket, and we can actually remove it
        ops.append({"kind": dist_op["kind"], "op": "remove", "package": package, "destination": dist_op["source"], "destination-region": dist_op["source-region"]})
    else:
        # it's a URL somewhere else, so we just re-use the ignore operation
        ops.append({"kind": dist_op["kind"], "op": "remove", "skip": dist_op["skip"], "package": package, "destination": dist_op["source"], "reason": dist_op["reason"]})
    # drop the package from dst_dir (that's what we'll be syncing up, and what we'll be running mkrepo.sh off of)
    args.dry_run or (dst_dir/manifest_file).unlink()
    # removal operation from dst bucket
    ops.append({"kind": "manifest", "op": "remove", "package": package, "destination": "s3://{}/{}{}".format(dst_bucket, dst_prefix, manifest_file), "destination-region": dst_region})

for manifest_file in upd:
    package = re.sub(r"\.composer\.json$", "", manifest_file)
    src_manifest = parse_manifest(src_dir/manifest_file)
    dst_manifest = parse_manifest(dst_dir/manifest_file)
    # compare the two manifests
    diff = manifests_difference(src_manifest, dst_manifest)
    if diff:
        # the manifests differ somehow
        if diff & ManifestDifference.SRC_NEWER:
            # source is newer than destination, so we copy both dist and manifest
            # take updated manifest from src
            dist_op = rewrite_dist(src_manifest, src_region, src_bucket, src_prefix, dst_region, dst_bucket, dst_prefix)
            dist_op["op"] = "update"
            dist_op["package"] = package
            ops.append(dist_op)
            # write out updated manifest (remember we updated the newer src manifest with a dst dist url)
            args.dry_run or json.dump(src_manifest, open(dst_dir / manifest_file, "w"), sort_keys=True, default=serialize_datetime)
            # so we're passing in the dst_dir here
            ops.append({"kind": "manifest", "op": "update", "package": package, "source": dst_dir/manifest_file, "destination": "s3://{}/{}{}".format(dst_bucket, dst_prefix, manifest_file), "destination-region": dst_region})
        elif diff & ManifestDifference.DST_NEWER:
            # destination is newer - do not overwrite
            ops.append({"kind": "manifest", "op": "update", "skip": True, "package": package, "source": src_dir/manifest_file, "reason": "destination is newer"})
        elif diff & ManifestDifference.CONTENTS:
            ops.append({"kind": "manifest", "op": "update", "skip": True, "package": package, "source": src_dir/manifest_file, "reason": "contents differ, but times are identical"})

json.dump(ops, sys.stdout, default=str)
