#!/bin/sh

## live-build(7) - System Build Scripts
## Copyright (C) 2016-2020 The Debian Live team
## Copyright (C) 2006-2015 Daniel Baumann <mail@daniel-baumann.ch>
##
## This program comes with ABSOLUTELY NO WARRANTY; for details see COPYING.
## This is free software, and you are welcome to redistribute it
## under certain conditions; see COPYING for details.

Write_apt_sources_stanza ()
{
	local FILE TYPES URIS SUITES COMPONENTS
	FILE="${1}"
	TYPES="${2}"
	URIS="${3}"
	SUITES="${4}"
	COMPONENTS="${5}"
  TRUSTED="${6:-}"

	mkdir -p "$(dirname "${FILE}")"

	if [ -f "${FILE}" ]; then
		echo '' >> "${FILE}"
	fi

	echo "Types: ${TYPES}" >> "${FILE}"
	echo "URIs: ${URIS}" >> "${FILE}"
	echo "Suites: ${SUITES}" >> "${FILE}"
  if [ "${COMPONENTS}" != 'NO_COMPONENTS' ]; then
  	echo "Components: ${COMPONENTS}" >> "${FILE}"
  fi
	if [ -z "${TRUSTED}" ]; then
		echo "Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg" >> "${FILE}"
	else
		echo "Trusted: ${TRUSTED}" >> "${FILE}"
	fi
}

Create_apt_sources_list ()
{
	local PARENT_MIRROR
	local MIRROR
	local PARENT_MIRROR_SECURITY
	local MIRROR_SECURITY
	local PARENT_DISTRIBUTION
	local DISTRIBUTION
	local USE_DEB822_SOURCES

	case "${1}" in
		chroot)
			PARENT_MIRROR=${LB_PARENT_MIRROR_CHROOT}
			MIRROR=${LB_MIRROR_CHROOT}
			PARENT_MIRROR_SECURITY=${LB_PARENT_MIRROR_CHROOT_SECURITY}
			MIRROR_SECURITY=${LB_MIRROR_CHROOT_SECURITY}
			PARENT_DISTRIBUTION=${LB_PARENT_DISTRIBUTION_CHROOT}
			DISTRIBUTION=${LB_DISTRIBUTION_CHROOT}
			USE_DEB822_SOURCES=${USE_DEB822_SOURCES_CHROOT}
			;;
		binary)
			PARENT_MIRROR="${LB_PARENT_MIRROR_BINARY}"
			MIRROR="${LB_MIRROR_BINARY}"
			PARENT_MIRROR_SECURITY=${LB_PARENT_MIRROR_BINARY_SECURITY}
			MIRROR_SECURITY=${LB_MIRROR_BINARY_SECURITY}
			PARENT_DISTRIBUTION=${LB_PARENT_DISTRIBUTION_BINARY}
			DISTRIBUTION=${LB_DISTRIBUTION_BINARY}
			USE_DEB822_SOURCES=${USE_DEB822_SOURCES_BINARY}
			;;
		*)
			Echo_error "Invalid mode '${1}' specified for source list creation!"
			exit 1
			;;
	esac

	local _PASS="${2}"

	local PARENT_FILE
	local LIST_FILE
	if [ "${USE_DEB822_SOURCES}" = "true" ]; then
		PARENT_FILE="sources.list.d/debian.sources"
		LIST_FILE="chroot/etc/apt/sources.list.d/${LB_MODE}.sources"
	else
		case "${LB_DERIVATIVE}" in
			true)
				PARENT_FILE="sources.list.d/debian.list"
				;;

			false)
				PARENT_FILE="sources.list"
				;;
		esac
		LIST_FILE="chroot/etc/apt/sources.list.d/${LB_MODE}.list"
	fi
	local PARENT_LIST_FILE="chroot/etc/apt/${PARENT_FILE}"

	local _DISTRIBUTION
	if [ "${LB_DERIVATIVE}" = "true" ]; then
		_DISTRIBUTION="$(echo ${DISTRIBUTION} | sed -e 's|-backports||')"
	fi

	# Clear out existing lists
	rm -f ${PARENT_LIST_FILE} ${LIST_FILE}

	# Get rid of sources.list if we're using deb822 sources
	if [ "${USE_DEB822_SOURCES}" = "true" ]; then
		rm -f chroot/etc/apt/sources.list
	fi

	# Set general repo
	if [ "${USE_DEB822_SOURCES}" = "true" ]; then
		Write_apt_sources_stanza "${PARENT_LIST_FILE}" 'deb deb-src' "${PARENT_MIRROR}" "${PARENT_DISTRIBUTION}" "${LB_PARENT_ARCHIVE_AREAS}"
	else
		echo "deb ${PARENT_MIRROR} ${PARENT_DISTRIBUTION} ${LB_PARENT_ARCHIVE_AREAS}" >> ${PARENT_LIST_FILE}
		echo "deb-src ${PARENT_MIRROR} ${PARENT_DISTRIBUTION} ${LB_PARENT_ARCHIVE_AREAS}" >> "${PARENT_LIST_FILE}"
	fi

	if [ "${LB_DERIVATIVE}" = "true" ]; then
		if [ "${USE_DEB822_SOURCES}" = "true" ]; then
			Write_apt_sources_stanza "${PARENT_LIST_FILE}" 'deb deb-src' "${MIRROR}" "${_DISTRIBUTION}" "${LB_ARCHIVE_AREAS}"
		else
			echo "deb ${MIRROR} ${_DISTRIBUTION} ${LB_ARCHIVE_AREAS}" >> "${LIST_FILE}"
			echo "deb-src ${MIRROR} ${_DISTRIBUTION} ${LB_ARCHIVE_AREAS}" >> "${LIST_FILE}"
		fi
	fi

	# Set security repo
	if [ "${LB_SECURITY}" = "true" ]; then
		case "${LB_MODE}" in
			debian)
				case "${PARENT_DISTRIBUTION}" in
					sid|unstable)
						# do nothing
						;;

					buster|jessie|stretch)
						# No deb822 check needed here, all of these versions are blacklisted from using deb822 above.
						echo "deb ${PARENT_MIRROR_SECURITY} ${PARENT_DISTRIBUTION}/updates ${LB_PARENT_ARCHIVE_AREAS}" >> "${PARENT_LIST_FILE}"
						echo "deb-src ${PARENT_MIRROR_SECURITY} ${PARENT_DISTRIBUTION}/updates ${LB_PARENT_ARCHIVE_AREAS}" >> "${PARENT_LIST_FILE}"
						;;
					*)
						if [ "${USE_DEB822_SOURCES}" = "true" ]; then
							Write_apt_sources_stanza "${PARENT_LIST_FILE}" 'deb deb-src' "${PARENT_MIRROR_SECURITY}" "${PARENT_DISTRIBUTION}-security" "${LB_PARENT_ARCHIVE_AREAS}"
						else
							echo "deb ${PARENT_MIRROR_SECURITY} ${PARENT_DISTRIBUTION}-security ${LB_PARENT_ARCHIVE_AREAS}" >> "${PARENT_LIST_FILE}"
							echo "deb-src ${PARENT_MIRROR_SECURITY} ${PARENT_DISTRIBUTION}-security ${LB_PARENT_ARCHIVE_AREAS}" >> "${PARENT_LIST_FILE}"
						fi
						;;
				esac

				if [ "${LB_DERIVATIVE}" = "true" ]; then
					if [ "${USE_DEB822_SOURCES}" = "true" ]; then
						Write_apt_sources_stanza "${LIST_FILE}}" 'deb deb-src' "${MIRROR_SECURITY}" "${_DISTRIBUTION}-security" "${LB_ARCHIVE_AREAS}"
					else
						# TODO: This is almost certainly outdated for most derivatives of Debian, even ones that aren't using deb822 yet
						echo "deb ${MIRROR_SECURITY} ${_DISTRIBUTION}/updates ${LB_ARCHIVE_AREAS}" >> "${LIST_FILE}"
						echo "deb-src ${MIRROR_SECURITY} ${_DISTRIBUTION}/updates ${LB_ARCHIVE_AREAS}" >> "${LIST_FILE}"
					fi
				fi
				;;
		esac
	fi

	# Set updates repo
	if [ "${LB_UPDATES}" = "true" ]; then
		if [ "${USE_DEB822_SOURCES}" = "true" ]; then
			Write_apt_sources_stanza "${PARENT_LIST_FILE}" 'deb deb-src' "${PARENT_MIRROR}" "${PARENT_DISTRIBUTION}-updates" "${LB_PARENT_ARCHIVE_AREAS}"
		else
			echo "deb ${PARENT_MIRROR} ${PARENT_DISTRIBUTION}-updates ${LB_PARENT_ARCHIVE_AREAS}" >> "${PARENT_LIST_FILE}"
			echo "deb-src ${PARENT_MIRROR} ${PARENT_DISTRIBUTION}-updates ${LB_PARENT_ARCHIVE_AREAS}" >> "${PARENT_LIST_FILE}"
		fi

		if [ "${LB_DERIVATIVE}" = "true" ]; then
			if [ "${USE_DEB822_SOURCES}" = "true" ]; then
				Write_apt_sources_stanza "${LIST_FILE}" 'deb deb-src' "${MIRROR}" "${_DISTRIBUTION}-updates" "${LB_ARCHIVE_AREAS}"
			else
				echo "deb ${MIRROR} ${_DISTRIBUTION}-updates ${LB_ARCHIVE_AREAS}" >> "${LIST_FILE}"
				echo "deb-src ${MIRROR} ${_DISTRIBUTION}-updates ${LB_ARCHIVE_AREAS}" >> "${LIST_FILE}"
			fi
		fi
	fi

	# Set proposed-updates repo
	if [ "${LB_PROPOSED_UPDATES}" = "true" ]; then
		if [ "${USE_DEB822_SOURCES}" = "true" ]; then
			Write_apt_sources_stanza "${PARENT_LIST_FILE}" 'deb deb-src' "${PARENT_MIRROR}" "${PARENT_DISTRIBUTION}-proposed-updates" "${LB_PARENT_ARCHIVE_AREAS}"
		else
			echo "deb ${PARENT_MIRROR} ${PARENT_DISTRIBUTION}-proposed-updates ${LB_PARENT_ARCHIVE_AREAS}" >> "${PARENT_LIST_FILE}"
			echo "deb-src ${PARENT_MIRROR} ${PARENT_DISTRIBUTION}-proposed-updates ${LB_PARENT_ARCHIVE_AREAS}" >> "${PARENT_LIST_FILE}"
		fi

		if [ "${LB_DERIVATIVE}" = "true" ]; then
			if [ "${USE_DEB822_SOURCES}" = "true" ]; then
				Write_apt_sources_stanza "${LIST_FILE}" 'deb deb-src' "${MIRROR}" "${_DISTRIBUTION}-proposed-updates" "${LB_ARCHIVE_AREAS}"
			else
				echo "deb ${MIRROR} ${_DISTRIBUTION}-proposed-updates ${LB_ARCHIVE_AREAS}" >> "${LIST_FILE}"
				echo "deb-src ${MIRROR} ${_DISTRIBUTION}-proposed-updates ${LB_ARCHIVE_AREAS}" >> "${LIST_FILE}"
			fi
		fi
	fi

	# Set backports repo
	if [ "${LB_BACKPORTS}" = "true" ]; then
		case "${LB_MODE}" in
			debian)
				if [ "${PARENT_DISTRIBUTION}" != "sid" ] && [ "${PARENT_DISTRIBUTION}" != "unstable" ]; then
					if [ "${USE_DEB822_SOURCES}" = "true" ]; then
						Write_apt_sources_stanza "${PARENT_LIST_FILE}" 'deb deb-src' "${PARENT_MIRROR}" "${PARENT_DISTRIBUTION}-backports" "${LB_PARENT_ARCHIVE_AREAS}"
					else
						echo "deb ${PARENT_MIRROR} ${PARENT_DISTRIBUTION}-backports ${LB_PARENT_ARCHIVE_AREAS}" >> "${PARENT_LIST_FILE}"
						echo "deb-src ${PARENT_MIRROR} ${PARENT_DISTRIBUTION}-backports ${LB_PARENT_ARCHIVE_AREAS}" >> "${PARENT_LIST_FILE}"
					fi
				fi
				;;
		esac

		if [ "${LB_DERIVATIVE}" = "true" ]; then
			if [ "${USE_DEB822_SOURCES}" = "true" ]; then
				Write_apt_sources_stanza "${LIST_FILE}" 'deb deb-src' "${MIRROR}" "${_DISTRIBUTION}-backports" "${LB_ARCHIVE_AREAS}"
			else
				echo "deb ${MIRROR} ${_DISTRIBUTION}-backports ${LB_ARCHIVE_AREAS}" >> "${LIST_FILE}"
				echo "deb-src ${MIRROR} ${_DISTRIBUTION}-backports ${LB_ARCHIVE_AREAS}" >> "${LIST_FILE}"
			fi
		fi
	fi

	# Disable deb-src entries?
	if [ "${_PASS}" != "source" ] && [ "${LB_APT_SOURCE_ARCHIVES}" != "true" ]; then
		if [ "${USE_DEB822_SOURCES}" = "true" ]; then
			sed -i "s/^Types: deb deb-src/Types: deb/g" "${PARENT_LIST_FILE}"
		else
			sed -i "s/^deb-src/#deb-src/g" "${PARENT_LIST_FILE}"
		fi
		if [ "${LB_DERIVATIVE}" = "true" ]; then
			if [ "${USE_DEB822_SOURCES}" = "true" ]; then
				sed -i "s/^Types: deb deb-src/Types: deb/g" "${LIST_FILE}"
			else
				sed -i "s/^deb-src/#deb-src/g" "${LIST_FILE}"
			fi
		fi
	fi
}
