#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

DATE=$(date "+%Y-%m-%d")

usage()
{
  echo "Usage: minsampler status [-hv]"
}

OPTIND=1
while getopts "hv" _o ; do
  case "$_o" in
  h)
    usage
    exit 0
    ;;
  v)
    # shellcheck disable=SC2034
    VERBOSE="YES"
    ;;
  *)
    usage
    exit 1
    ;;
  esac
done

shift "$((OPTIND-1))"

if [ $# -ne 0 ]; then
  usage
  exit 1
fi

set -eE
trap 'echo error: $STEP failed' ERR
# shellcheck disable=SC1091
source "${INCLUDE_DIR}/common.sh"
common_init_vars

step "Load potman config"
read_potman_config potman.ini
# shellcheck disable=SC2154
FREEBSD_VERSION="${config_freebsd_version}"
FBSD="${FREEBSD_VERSION}"
FBSD_TAG=${FREEBSD_VERSION//./_}

step "Check tooling"
ansible --version >/dev/null
git --version >/dev/null
vagrant --version >/dev/null
vboxheadless --version >/dev/null

step "Show vagrant status"
echo "
===> Vagrant status <==="
VAGRANT_DISABLE_STRICT_DEPENDENCY_ENFORCEMENT=1 VAGRANT_ALLOW_PRERELEASE=1 vagrant status | grep -E "($MINIO1|$MINIO2)"

# if DEBUG is enabled, dump the variables
if [ "$DEBUG" -eq 1 ]; then
    printf "\n\n"
    echo "Dump of variables"
    echo "================="
    echo "FBSD: $FBSD"
    echo "FBSD_TAG: $FBSD_TAG"
    echo "Version: $VERSION with suffix: $VERSION_SUFFIX"
    printf "\n\n"
    echo "Date: $DATE"
    printf "\n\n"
fi

step "Success"
