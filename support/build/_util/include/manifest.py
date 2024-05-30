import os, sys, json, re, datetime

require = json.loads(sys.argv[5]) if len(sys.argv) > 5 else {}
stack=re.match(r"^([^-]+)(?:-([0-9]+))?$", os.getenv("STACK", "heroku-22"))
require["heroku-sys/"+stack.group(1)] = "^{}.0.0".format(stack.group(2) or "1")

require["heroku/installer-plugin"] = "^1.2.0"
if sys.argv[1] == 'heroku-sys-php':
	require["heroku/installer-plugin"] = "^1.6.0"
elif sys.argv[1] == 'heroku-sys-php-extension':
	require["heroku/installer-plugin"] = "^1.6.0"
elif sys.argv[1] == 'heroku-sys-library':
	require["heroku/installer-plugin"] = "^1.3.0"
elif sys.argv[1] == 'heroku-sys-program':
	require["heroku/installer-plugin"] = "^1.4.0"

s3_region_string = os.getenv("S3_REGION")
if s3_region_string == None:
	s3_region_string = "s3"
else:
	s3_region_string = "s3.{}".format(s3_region_string)

manifest = {
	"type": sys.argv[1],
	"name": sys.argv[2],
	"version": sys.argv[3],
	"dist": {
		"type": "heroku-sys-tar",
		"url": "https://"+os.getenv("S3_BUCKET")+"."+s3_region_string+".amazonaws.com/"+os.getenv("S3_PREFIX")+sys.argv[4]
	},
	"require": require,
	"conflict": json.loads(sys.argv[6]) if len(sys.argv) > 6 else {},
	"replace": json.loads(sys.argv[7]) if len(sys.argv) > 7 else {},
	"provide": json.loads(sys.argv[8]) if len(sys.argv) > 8 else {},
	"extra": json.loads(sys.argv[9]) if len(sys.argv) > 9 else {},
	"time": os.getenv("NOW", datetime.datetime.now(tz=datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S"))
}

# if it's a PHP manifest, we will generate full manifests for each shared extension into extra.shared; mkrepo.sh will then expand those into actual package declarations when it generates the repo
if manifest["type"] == "heroku-sys-php":
	extensions = {}
	# prepare some values that each extension manifest will need
	phpconflict = manifest.get("conflict")
	require = manifest.get("require").copy() # we want the PHP package's requirements, then add to them
	phptime = manifest.get("time")
	phpversion = manifest.get("version")
	require.update({"heroku-sys/php": phpversion}) # all extensions requires exactly this PHP version
	# now convert our list of shared extension names and versions into full manifests
	shared = manifest.get("extra", {}).get("shared", {})
	for extname in shared.keys():
		# TODO: support the input value being a dict with some/all of the metadata below; use cases: bundled extensions that 1) require another (e.g. on Windows, ext-exif can only use ext-mbstring if mbstring is loaded first), or 2) conflict with others (ext-imap conflicts with ext-yaz if libyaz is < 2.0), or 3) need custom configs of some kind
		dist = manifest.get("dist").copy()
		dist["type"] = "heroku-sys-php-bundled-extension" # we have a no-op downloader for this type
		dist["url"] += "?extension="+extname # for better readability in packages.json, test cases, diffs etc
		extensions[extname] = {
			"conflict": phpconflict,
			"dist": dist,
			"name": extname,
			"require": require,
			"time": phptime,
			"type": "heroku-sys-php-extension",
			"version": phpversion if shared[extname] == "self.version" else shared[extname]
		}
	manifest.get("extra", {})["shared"] = extensions

json.dump(manifest, sys.stdout, sort_keys=True)
