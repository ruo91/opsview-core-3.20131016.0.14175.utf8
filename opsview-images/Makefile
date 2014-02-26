# Makefile for opsview-images
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
# The png files are the source files in this directory. Each png file
# will be converted into gif and resized
#
# The filenames explain the function of the icon. Some icons may be duplicated
# but that will be stored in SVN independently

ROOT_DIR ?= ${DESTDIR}
TARGET_DIR = ${ROOT_DIR}/usr/local/nagios/share/images
ICO_DIR = ${ROOT_DIR}/usr/local/nagios/share
HOSTICON_DIR = ${TARGET_DIR}/logos

SOURCE_PNG = $(wildcard images/*.png) $(wildcard icons/*.png) $(wildcard hosticons/*.png)
SOURCE_GIF = $(wildcard images/*.gif) $(wildcard icons/*.gif) $(wildcard hosticons/*.gif)
HOSTICONS = $(wildcard hosticons/*.png) $(wildcard hosticons/*.gd2)

HTML_FILES = $(wildcard images/*.html) $(wildcard hosticons/*.html) $(wildcard icons/*.html)

ICO_FILES = $(wildcard icons/*.ico)

IMAGE_FILES = ${SOURCE_PNG} ${SOURCE_GIF}
ALL_FILES = ${IMAGE_FILES} ${HOSTICONS}

all: ${ALL_FILES}

# Special case for graph icon as Nagios CGIs expet it to be in the logos directory
install: ${ALL_FILES}
	install -m 0644 ${IMAGE_FILES} ${TARGET_DIR}
	install -m 0644 ${HOSTICONS} ${HOSTICON_DIR}
	install -m 0644 ${ICO_FILES} ${ICO_DIR}
	install -m 0644 icons/graph-32x32.png ${HOSTICON_DIR}/graph.png

install-html: ${HTML_FILES}
	install -m 0644 ${HTML_FILES} ${TARGET_DIR}

clean:
