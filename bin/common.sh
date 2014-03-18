error() {
  echo " !     $*" >&2
  exit 1
}

warning() {
  status "WARNING!"
  echo $* | indent
}

status() {
  echo "-----> $*"
}

notice() {
  echo
  echo "NOTICE: $*" | indent
  echo "See https://devcenter.heroku.com/articles/php-support" | indent
  echo
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
