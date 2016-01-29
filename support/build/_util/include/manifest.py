import os, sys, json, re, datetime

require = {
    "heroku-sys/"+os.getenv("STACK"): "^1.0.0",
    "heroku/installer-plugin": "^1.0.0",
}
engine=re.match('heroku-sys-(\w+)-extension', sys.argv[1])
if engine:
    require["heroku-sys/"+engine.group(1)] = sys.argv.pop(5)

manifest = {
    "type": sys.argv[1],
    "name": sys.argv[2],
    "version": sys.argv[3],
    "require": require,
    "conflict": dict(item.split(":") for item in sys.argv[5:]),
    "dist": {
        "type": "heroku-sys-tar",
        "url": "https://"+os.getenv("S3_BUCKET")+"."+os.getenv("S3_REGION", "s3")+".amazonaws.com/"+os.getenv("S3_PREFIX")+"/"+sys.argv[4]
    },
    "time": datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
}

if not sys.stdin.isatty():
    manifest["replace"] = dict(item.rstrip("\n").split(" ") for item in tuple(sys.stdin))

json.dump(manifest, sys.stdout, sort_keys=True)
