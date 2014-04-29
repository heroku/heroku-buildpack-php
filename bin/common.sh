error() {
  echo
  echo -n " !     ERROR: "
  echo "$*" | indent
  echo
  exit 1
}

warning() {
  echo
  echo -n " !     WARNING: "
  echo "$*" | indent
  echo "See https://devcenter.heroku.com/categories/php" | indent
  echo
}

warning_inline() {
  echo -n " !     WARNING: "
  echo "$*" | indent
}

status() {
  echo "-----> $*"
}

notice() {
  echo
  echo "NOTICE: $*" | indent
  echo "See https://devcenter.heroku.com/categories/php" | indent
  echo
}

notice_inline() {
  echo "NOTICE: $*" | indent
}

# sed -l basically makes sed replace and buffer through stdin to stdout
# so you get updates while the command runs and dont wait for the end
# e.g. npm install | indent
indent() {
  c='s/^/       /'
  case $(uname) in
    Darwin) sed -l "$c";; # mac/bsd sed: -l buffers on line boundaries
    *)      sed -u "$c";; # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
  esac
}

export_env_dir() {
  env_dir=$1
  whitelist_regex=${2:-''}
  blacklist_regex=${3:-'^(PATH|GIT_DIR|CPATH|CPPATH|LD_PRELOAD|LIBRARY_PATH)$'}
  if [ -d "$env_dir" ]; then
    for e in $(ls $env_dir); do
      echo "$e" | grep -E "$whitelist_regex" | grep -qvE "$blacklist_regex" &&
      export "$e=$(cat $env_dir/$e)"
      :
    done
  fi
}