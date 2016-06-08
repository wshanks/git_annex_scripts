#!/usr/bin/env bash

#  This file is part of willsALMANJ's git annex scripts.
#
# willsALMANJ's git annex scripts are free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# willsALMANJ's git annex scripts are distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright 2016, willsALMANJ

usage() {
	echo "Usage: ga_decrypt.sh -r REMOTE [-k SYMLINK] [-d FILE]"
	echo ""
	echo "    Either lookups up key on REMOTE for annex file linked with SYMLINK"
	echo "    or decrypts FILE encrypted for REMOTE."
	echo ""
	echo "    -r: REMOTE is special remote to use"
	echo "    -k: SYMLINK is symlink in annex to print encrypted special remote key for"
	echo "    -d: FILE is path to special remote file to decrypt to STDOUT"
	echo ""
	echo "NOTES: "
	echo "    * Run in an indirect git annex repo."
	echo "    * Must specify -k or -d."
	echo "    * -k prints the key including the leading directory names used for a "
	echo "       directory remote (even if REMOTE is not a directory remote)"
	echo "    * -d works on a locally accessible file. It does not fetch a remote file"
	echo "    * Must have gpg and openssl"
}

decrypt_cipher() {
	cipher="$1"
	echo "$(echo -n "$cipher" | base64 -d | gpg --decrypt --quiet)"
}

lookup_key() {
	encryption="$1"
	cipher="$2"
	symlink="$3"

	if [ "$encryption" == "hybrid" ] || [ "$encryption" == "pubkey" ]; then
		cipher="$(decrypt_cipher "$cipher")"
	fi

	# Pull out MAC cipher from beginning of cipher
	if [ "$encryption" = "hybrid" ] ; then
		cipher="$(echo -n "$cipher" | head  -c 256 )"
	elif [ "$encryption" = "shared" ] ; then
		cipher="$(echo -n "$cipher" | base64 -d | tr -d '\n' | head  -c 256 )"
	elif [ "$encryption" = "pubkey" ] ; then
		# pubkey cipher includes a trailing newline which was stripped in
		# decrypt_cipher process substitution step above
		IFS= read -rd '' cipher < <( printf "$cipher\n" )
	fi

	annex_key="$(basename "$(readlink "$symlink")")"
	hash="$(echo -n "$annex_key" | openssl dgst -sha1 -hmac "$cipher" | sed 's/(stdin)= //')"
	key="GPGHMACSHA1--$hash"
	checksum="$(echo -n $key | md5sum)"
	echo "${checksum:0:3}/${checksum:3:3}/$key"
}

decrypt_file() {
	encryption="$1"
	cipher="$2"
	file_path="$3"

	if [ "$encryption" = "pubkey" ] ; then
		gpg --quiet --decrypt "${file_path}"
	else
		if [ "$encryption" = "hybrid" ] ; then
			cipher="$(decrypt_cipher "$cipher" | tail -c +257)"
		elif [ "$encryption" = "shared" ] ; then
			cipher="$(echo -n "$cipher" | base64 -d | tr -d '\n' | tail  -c +257 )"
		fi
		gpg --quiet --batch --passphrase "$cipher" --output - "${file_path}"
	fi
}

main() {
	OPTIND=1

	mode=""
	remote=""

	while getopts "r:k:d:" opt; do
		case "$opt" in
			r)  remote="$OPTARG"
				;;
			k)  if [ -z "$mode" ] ; then
					mode="lookup key"
				else
					usage
					exit 2
				fi
				symlink="$OPTARG"
				;;
			d)  if [ -z "$mode" ] ; then
					mode="decrypt file"
				else
					usage
					exit 2
				fi
				file_path="$OPTARG"
				;;
		esac
	done

	if [ -z "$mode" ] || [ -z "$remote" ] ; then
		usage
		exit 2
	fi

    shift $((OPTIND-1))

	# Pull out config for desired remote name
	remote_config="$(git show git-annex:remote.log | grep 'name='"$remote ")"

	# Get encryption type and cipher from config
	encryption="$(echo "$remote_config" | grep -oP 'encryption\=.*? ' | tr -d ' \n' | sed 's/encryption=//')"
	cipher="$(echo "$remote_config" | grep -oP 'cipher\=.*? ' | tr -d ' \n' | sed 's/cipher=//')"

	if [ "$mode" = "lookup key" ] ; then
		lookup_key "$encryption" "$cipher" "$symlink"
	elif [ "$mode" = "decrypt file" ] ; then
		decrypt_file "$encryption" "$cipher" "${file_path}"
	fi
}

main "$@"
