#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
  >&2 echo "This needs to run in bash"
  exit 1
fi

usage()
{
  echo "Usage: minsampler packbox [-hv]"
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

step "Start"
mkdir -p _build
read_potman_config potman.ini
# shellcheck disable=SC2154
FREEBSD_VERSION="${config_freebsd_version}"

step "Check tooling"
ansible --version >/dev/null
git --version >/dev/null
packer --version >/dev/null
vagrant --version >/dev/null
vboxheadless --version >/dev/null

step "Check box already exists"
if vagrant box list | grep "FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64" |\
	  grep "virtualbox" >/dev/null; then
  step "Box already exists"
  exit 0
fi

step "Initialize"

rm -rf _build/packer
git clone -b testing https://github.com/bretton/packer-FreeBSD.git _build/packer
cd _build/packer

# need this to expand disk size, was turned off in custom packer script for another system
{
  printf "\n# Growfs on first boot\n"
  printf "service growfs enable\n"
  printf "touch /firstboot\n"
} >>scripts/cleanup.sh

# future-proofing but simply replaces 13.1 with 13.1 currently, increases disk size
<variables.json.sample sed -e "s|13.1|${FREEBSD_VERSION}|g" -e "s|32G|40960|g" >variables.json
#<variables.json.sample sed -e "s|13.0|${FREEBSD_VERSION}|g" -e "s|32G|10240|g" >variables.json
#cp -f variables.json.sample variables.json

#step "Validate packer build files"
#packer validate -only=virtualbox-iso template.json

step "Packer build"
# debug
export PACKER_LOG=1
export PACKER_LOG_PATH="packer.log"
export PACKER_BUILDER_TYPE="virtualbox-iso"
if [ -f variables.json ]; then
    packer build -only="virtualbox-iso" -var-file="variables.json" template.json
fi
# packer build -only=virtualbox-iso -var-file=variables.json template.json

step "Add Vagrant box"
VAGRANT_DISABLE_STRICT_DEPENDENCY_ENFORCEMENT=1 VAGRANT_ALLOW_PRERELEASE=1 \
  vagrant box add "builds/FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64.box" \
  --name "FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64"

step "Success"
