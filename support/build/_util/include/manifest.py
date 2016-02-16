import os, sys, json, re, datetime

require = json.loads(sys.argv[5])
stack=re.match("^([^-]+)(?:-([0-9]+))?$", os.getenv("STACK", "cedar-14"))
require["heroku-sys/"+stack.group(1)] = "^{}.0.0".format(stack.group(2) or "1")
require["heroku/installer-plugin"] = "^1.2.0"

manifest = {
    "type": sys.argv[1],
    "name": sys.argv[2],
    "version": sys.argv[3],
    "dist": {
        "type": "heroku-sys-tar",
        "url": "https://"+os.getenv("S3_BUCKET")+"."+os.getenv("S3_REGION", "s3")+".amazonaws.com/"+os.getenv("S3_PREFIX")+sys.argv[4]
    },
    "require": require,
    "conflict": json.loads(sys.argv[6]) if len(sys.argv) > 6 else {},
    "replace": json.loads(sys.argv[7]) if len(sys.argv) > 7 else {},
    "extra": json.loads(sys.argv[8]) if len(sys.argv) > 8 else {},
    "time": datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
}

json.dump(manifest, sys.stdout, sort_keys=True)
