#!/bin/bash
################################################################################
#
# prep_libtool_modules.sh - removes static and import libraries for libtool modules
#
# Part of cygport - Cygwin packaging application
# Copyright (C) 2006, 2007 Yaakov Selkowitz
# Provided by the Cygwin Ports project <http://cygwinports.dotsrc.org/>
#
# cygport is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# cygport is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with cygport.  If not, see <http://www.gnu.org/licenses/>.
#
# $Id: prep_libtool_modules.sh,v 1.12 2008-04-16 00:16:56 yselkowitz Exp $
#
################################################################################
set -e

declare -r ltversion="$(/usr/bin/libtool --version | /bin/grep ltmain.sh)"

echo "Fixing libtool modules:"

for lib_la
do
	# sanity check
	if [ ! -f ${lib_la} ]
	then
		error "file ${lib_la} does not exist!"
	fi

	# check that the file is actually a libtool library
	# e.g. xmodmap.la, where 'la' is a language code
	if ! grep -q "libtool library file" ${lib_la}
	then
		continue
	fi

	source ${lib_la}

	ltlibdir=${lib_la%/*}

	# check that all library members were installed
	for l in dlname library_names old_library
	do
		if defined ${l} && [ ! -f ${ltlibdir}/${!l} ]
		then
			# FIXME: error?
			warning "${!l} was not installed"
		fi
	done

	# Only a -module should be "fixed" in this way
	if [ "x${shouldnotlink}" = "xyes" ]
	then
		echo "        ${lib_la}"

		ltlibname=${lib_la##*/}
		ltlibname=${ltlibname%.la}

		if [ "x${dlname}" = "x" ]
		then
			error "${ltlibname}.la dynamic module was not built"
		fi

		# warn if -avoid-version was not used with -module
		# 99.9% of time should be, but there are notable exceptions
		case "${dlname#../bin/}" in
			cyg${ltlibname#lib}.dll|${ltlibname}.dll)	;;
			cyg${ltlibname#lib}.so|${ltlibname}.so)		;;
			*)	warning "${ltlibname}.la appears to be a versioned module." ;;
		esac

		# static and import libraries are pointless for modules
		rm -f ${ltlibdir}/${ltlibname}.a ${ltlibdir}/${ltlibname}.dll.a

		cat > ${lib_la} <<-_EOF
			# ${ltlibname}.la - a libtool library file
			# Generated by ${ltversion}
			# Modified by cygport
			#
			# Please DO NOT delete this file!
			# It is necessary for linking the library.

			# The name that we can dlopen(3).
			dlname='${dlname}'

			# Names of this library.
			library_names='${dlname}'

			# The name of the static archive.
			old_library=''

			# Linker flags that can not go in dependency_libs.
			inherited_linker_flags='${inherited_linker_flags}'

			# Libraries that this one depends upon.
			# This is set to empty to speed up lt_dlopen and friends.
			dependency_libs=''

			# Names of additional weak libraries provided by this library
			weak_library_names='${weak_library_names}'

			# Version information for ${ltlibname}.
			current=${current}
			age=${age}
			revision=${revision}

			# Is this an already installed library?
			installed=yes

			# Should we warn about portability when linking against -modules?
			shouldnotlink=yes

			# Files to dlopen/dlpreopen
			dlopen=''
			dlpreopen=''

			# Directory that this library needs to be installed in:
			libdir='${libdir}'
			_EOF
	else
		# shouldnotlink = no; this is a regular library
		true
	fi
done
