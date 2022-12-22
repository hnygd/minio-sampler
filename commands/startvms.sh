#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

usage()
{
  echo "Usage: minsampler startvms [-hv] [-m machine]"
}

MACHINES=()

OPTIND=1
while getopts "hvm:" _o ; do
  case "$_o" in
  h)
    usage
    exit 0
    ;;
  m)
    MACHINES+=( "${OPTARG}" )
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

mkdir -p _build

step "Check tooling"
ansible --version >/dev/null
git --version >/dev/null
vagrant --version >/dev/null
vboxheadless --version >/dev/null

step "Make sure vagrant plugins are installed"
(vagrant plugin list | grep "vagrant-disksize" >/dev/null)\
  || VAGRANT_DISABLE_STRICT_DEPENDENCY_ENFORCEMENT=1 VAGRANT_ALLOW_PRERELEASE=1 vagrant plugin install vagrant-disksize

step "Start vagrant vms"
VAGRANT_DISABLE_STRICT_DEPENDENCY_ENFORCEMENT=1 VAGRANT_ALLOW_PRERELEASE=1 vagrant up --provision "${MACHINES[@]}"

step "Success"
