# Makefile for nagios-icons
#
# AUTHORS:
#	Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#    This file is part of Opsview
#
#    Opsview is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    Opsview is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Opsview; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

ifdef ROOT
ROOT_DIR = ${ROOT}/
else
ROOT_DIR = ${DESTDIR}/
endif

TARGET_DIR = ${ROOT_DIR}/usr/local/nagios/share/images
DIRS = logos symbols

all: check_binaries
	for i in ${DIRS} ; do \
		if [ x = x`ls $$i/*.png 2>/dev/null | head -1` ] ; then \
			genicons-script/genicons.sh $$i/*.gif ;\
		fi \
	done

check_binaries:
#	which giftopnm || ( echo "**** Install netpbm ****"; false )
	which pnmtopng || ( echo "**** Install netpbm ****"; false )
	which convert || ( echo "**** Install imagemagick ****"; false )
#	which pngtogd2 || ( echo "**** Install libgd-tools ****"; false )

install:
	install -d -o nagios -g nagios -m 0755 ${TARGET_DIR}/logos
	for d in ${DIRS} ; do \
		( cd $$d && for f in *.gd2 *.gif *.jpg *.png ; do \
			install -c -o nagios -g nagios -m 0444 $$f ${TARGET_DIR}/logos/$$f ; \
		done ) \
	done
	install -d -o nagios -g nagios -m 0755 ${TARGET_DIR}/mrtg
	for f in mrtg/*.png ; do \
		install -c -o nagios -g nagios -m 0444 $$f ${TARGET_DIR}/$$f ; \
	done
	install -c -o nagios -g nagios -m 0444 graph-icon.gif ${TARGET_DIR}/logos/graph-icon.gif

clean:
	for i in ${DIRS} ; do rm -f $$i/*.png $$i/*.gd2 $$i/*.jpg $$i/*.pnm ; done
