#!/usr/bin/env bash
set -eu

# getopt strategy entirely from https://stackoverflow.com/a/7948533
# NOTE: This requires GNU getopt.  On Mac OS X and FreeBSD, you have to install
# this separately; see below.
TEMP=$(getopt -o o: --long out:,output: -n 'export' -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around '$TEMP': they are essential!
eval set -- "$TEMP"

OUT_DIR=.
while true; do
  case "$1" in
    -o | --out | --output ) OUT_DIR="$2"; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

EMACS_VERSION=$(emacs --version | head -n 1)




cat <<EOF
Starting org-mode export to HTML
Emacs Version: $EMACS_VERSION
EOF

# Manually expand tilde, from https://stackoverflow.com/a/27485157
# OUT_DIR="${OUT_DIR/#\~/$HOME}"

# Note: Emacs finds OUT_DIR by position, so don't mess with order of things
# emacs --batch -Q --script ./export.el "$OUT_DIR"
emacs --batch -Q --load=./ox-11ty.el --script ./export.el
