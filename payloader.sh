#!/usr/bin/env bash

dname=$(dirname ${BASH_SOURCE[0]})
bname=$(basename "$0")
script_dir=$(cd "${dname}" &>/dev/null && pwd -P)
payload_dir="${script_dir}"

_openssl=$(which openssl)
if [ -z "${_openssl}" ] ; then
  echo "ERROR: OpenSSL not found"
  exit 1
fi
_tar=$(which tar)
if [ -z "${_tar}" ] ; then
  echo "ERROR:Tar not found"
  exit 1
fi

function unpack_payload() {
  local _pass=$1
  local _opts=""
  if [ ! -z "${_pass}" ] ; then
    _opts="-k ${_pass}"
  fi

  # https://stackoverflow.com/questions/29418050/package-tar-gz-into-a-shell-script
  # determine the line number of this script where the payload begins
  PAYLOAD_LINE=`awk '/^__PAYLOAD__/ {print NR + 1; exit 0; }' $0`
  echo "Payload starts at: $PAYLOAD_LINE"
  # use the tail command and the line number we just determined to skip
  # past this leading script code and pipe the payload to tar
  tail -n+$PAYLOAD_LINE $0 | \
  "${_openssl}" enc -aes-256-cbc -md sha256 -pbkdf2 -iter 100000 -a -d ${_opts} | \
  ${_tar} xzv -C "${payload_dir}" -f -
  if [ $? -gt 0 ] ; then
    echo "Failed to unpack payload"
    exit 1
  fi
}

function pack_payload() {
  local _pass=$1
  local _tarball="${payload_dir}/payload.tgz.enc"
  local _output="${payload_dir}/payload.sh"

  if [ ! -d "${payload_dir}/payload" ] ; then
    echo "Payload directory not found"
    exit 1
  fi

  local _opts=""
  if [ ! -z "${_pass}" ] ; then
    _opts="-k ${_pass}"
  fi

  local _pwd=$PWD
  cd "${payload_dir}"
  # ${_tar} cvz -f "${_tarball}" "./payload"
  ${_tar} cvz -f - "./payload" | \
  "${_openssl}" enc -aes-256-cbc -md sha256 -pbkdf2 -iter 100000 -salt -a -out "${_tarball}" ${_opts}
  if [ $? -gt 0 ] ; then
    echo "Failed to pack payload"
    exit 1
  fi
  cd "${_pwd}"

  cat $0 "${_tarball}" > "${_output}"
  chmod a+x "${_output}"
}

## Arguments
_action=${1:-unpack}
shift

if [ "${_action}" = "unpack" ] ; then
  unpack_payload $*
  _pwd=$PWD
  cd "${payload_dir}/payload"
  if [ -r "./provision.sh" ] ; then
    chmod u+x "./provision.sh" 
    echo "Start to run provision.sh in 5s. Press Ctrl+c to abort."
    sleep 5
    ./provision.sh $*
  else
    echo "WARNING: provision.sh not found in the payload"
  fi
  cd "${_pwd}"
  exit 0
fi

if [ "${_action}" = "pack" ] ; then
  pack_payload $*
  exit 0
fi

exit 0

__PAYLOAD__
