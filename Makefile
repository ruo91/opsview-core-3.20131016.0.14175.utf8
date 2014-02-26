# Makefile for opsview
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

# This variable is defined in trunk/Makefile
#VERSION = 2.7a
#DBVERSION = 2.7.5 - This variable is now hardcoded in bin/db_opsview

SUBDIRS = nagios-plugins nagios-icons opsview-images

GENERATED = ndologs_xs opspacks share/sidenav.html share/favicon.ico etc/opsview_build_os

NAGIOS_USER=nagios
NAGIOS_GROUP=nagios

all: filelist protected ${GENERATED}
	for d in ${SUBDIRS} ; do [ -d $$d ] && ( cd $$d && make ) || exit 1 ; done

dev: all

protected:
	cp -v bin-protected/* bin/

install-protected:

filelist:
	cp -v $@.in $@
	find lib -mindepth 1 -type d | grep -v .svn | grep -v 'lib/auto' | sort | awk '{print "d nagios:nagios 0755 /usr/local/nagios/"$$1 }' >> $@
	find lib -mindepth 1 -type f -name "*.pm" | grep -v .svn | grep -v 'lib/auto' | sort | awk '{print "f nagios:nagios 0644 /usr/local/nagios/"$$1" "$$1 }' >> $@

version:
	perl -pe 's/%VERSION%/${VERSION}/g;' $@.in > $@

# $$os comes from Hudson
etc/opsview_build_os:
	BUILD_OS=`../tools/build_os $$os ${DIST}` && echo "$$BUILD_OS ${ARCH}" > $@
	cat $@

ndologs_xs:
	( cd opsview-perl-modules/Opsview-Utils-NDOLogsImporter-XS && perl Makefile.PL && make )

ndologs_xs_reinstall: ndologs_xs
	TMP_FILELIST=filelist.xs.reinstall; \
	grep XS filelist > $$TMP_FILELIST; \
	build-aux/fladmin -r ${ROOT_DIR} install $$TMP_FILELIST; \
	rm -v $$TMP_FILELIST;

# Working out community or enterprise version is a bit messy here. Can't do as a gnumake variable
# because debian packaging invokes the make. Probably should set version at top level and everything
# else below references top level
share/favicon.ico: version
	version=`cat version`; \
	community=`perl -e '@v = split(/\./, shift @ARGV); $$comm = $$v[1] % 2; print $$comm' $$version`; \
	if [ "$$community" = "1" ] ; then ico=share/faviconCommunity.ico ; else ico=share/faviconEnterprise.ico ; fi && \
	  cp $$ico share/favicon.ico

# Need to treat this slightly differently as debian creates at a different time
share/sidenav.html: version
	perl -pe 's/%VERSION%/'`cat version`'/g;' $@.in > $@

debpkg debpkg-par:
	cp debian/changelog.in debian/changelog
	cp bin/rc.opsview debian/opsview.init
	perl -pe 's/%VERSION%/${VERSION}/g; s/%OPSVIEW_PERL_VERSION%/${OPSVIEW_PERL_VERSION}/g; s/%OPSVIEW_BASE_VERSION%/${OPSVIEW_BASE_VERSION}/g' debian/control.in > debian/control
	VERSION=`cat version` && cd debian && build/mkdeb $$VERSION-1 ..

opspacks:
	mkdir import/opspacks 2>/dev/null || true
	cd import/opspacks_source && for d in `ls`; do tar -zc --exclude=".svn" --exclude=".git*" -f ../opspacks/$$d.tar.gz $$d/; done

test-opspacks:
	rm -fr import/opspacks
	make opspacks
	bin/db_opsview -n db_install

# See opsview-base's notes
solpkg:
	rm -fr /tmp/opsview-core
	mkdir /tmp/opsview-core
	mksolpkg -s /tmp/opsview-core

opsview-core.spec: opsview-core.spec.in
	perl -pe 's/%VERSION%/${VERSION}/g; s/%OPSVIEW_PERL_VERSION%/${OPSVIEW_PERL_VERSION}/g; s/%OPSVIEW_BASE_VERSION%/${OPSVIEW_BASE_VERSION}/g' opsview-core.spec.in > opsview-core.spec

opsview-perl.spec: opsview-perl.spec.in
	perl -pe 's/%VERSION%/${VERSION}/g;' opsview-perl.spec.in > opsview-perl.spec

install: install-check install-force

install-force: install-extra install-fladmin

# Sick of installing on development server by mistake!
# If bin/nagios exists, this is a dev server
install-check:
	[ ! -f bin/nagios ]

install-extra:
	for d in ${SUBDIRS} ; do [ -d $$d ] && ( cd $$d && make install ) || exit 1 ; done

install-fladmin:
	build-aux/fladmin -r ${ROOT_DIR} install filelist
	tar -cf - --exclude=".svn" --exclude=".git*" installer/ndoutils | ( cd ${ROOT_DIR}/usr/local/nagios && tar -xvf - | xargs chown $(NAGIOS_USER):$(NAGIOS_GROUP) )

install-fladmindev:
	build-aux/fladmin -r ${ROOT_DIR} devinstall filelist

# Not sure this is needed anymore, if nagios is the development user
# This is needed to relax permissions on a development server. Will not be
# used for production servers
install-dev: install-extra install-fladmindev

uninstall:
	build-aux/fladmin uninstall filelist
	installer/preremove && installer/remove

# For Opsview Core, we create all the necessary files
tar:
	#[ `whoami` = root ] || (echo "Must be root"; false ) # Don't think is required for packaging
	if [ x${VERSION} = "x" ] ; then echo "Need version" ; false; fi
	$(MAKE) clean
	#$(MAKE)
	$(MAKE) opsview-core.spec
	rm -f ../opsview-core-${VERSION}
	cd .. && ln -s opsview-core opsview-core-${VERSION}
	cd .. && tar --gzip -h -cf opsview-core-${VERSION}.tar.gz --exclude=.svn opsview-core-${VERSION}
	rm ../opsview-core-${VERSION}

pkg:
	[ `whoami` = root ] || (echo "Must be root"; false )
	mkdir /tmp/opsview-${VERSION}
	tar --exclude=CVS -C installer -cf - . | tar -C /tmp/opsview-${VERSION} -xf -
	tar -C / -cf /tmp/opsview-${VERSION}/opsview.tar ./usr/local/nagios
	cd /tmp && tar --gzip -cf opsview-${VERSION}.tar.gz opsview-${VERSION}
	rm -r /tmp/opsview-${VERSION}

test:
	perl -MTest::Harness -e 'runtests(@ARGV)' t/*.t

clean:
	for d in ${SUBDIRS} ; do [ -d $$d ] && ( cd $$d && make clean ) || true ; done
	rm -f ${GENERATED} opsview-core.spec opsview-perl.spec

.PHONY: solpkg debpkg
