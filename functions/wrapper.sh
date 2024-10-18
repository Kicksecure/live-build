#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2016-2020 The Debian Live team
## Copyright (C) 2006-2015 Daniel Baumann <mail@daniel-baumann.ch>
##
## This program comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.


Apt ()
{
	local CHROOT="${1}"
	local MODE="${2}"
	shift 2

	case "${LB_APT}" in
		apt|apt-get)
			if [ "${MODE}" = "update" ]
			then
				Chroot ${CHROOT} apt-get ${APT_OPTIONS} ${APT_UPDATE_OPTIONS} ${MODE} "${@}"
			else
				Chroot ${CHROOT} apt-get ${APT_OPTIONS} ${MODE} "${@}"
			fi
			;;

		aptitude)
			Chroot ${CHROOT} aptitude ${APTITUDE_OPTIONS} ${MODE} "${@}"
			;;
	esac
}
