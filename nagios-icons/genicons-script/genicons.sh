#!/bin/bash

#  Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#  W: http://www.opsview.com/
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

USE_CONVERT=""

if [ "`uname -s `" == "SunOS" ]; then
	USE_CONVERT=true
fi

for arg
do
  if [ -f "$arg" ]; then
    echo converting $arg
    arg="$(echo $arg | sed 's/\.gif$//')"
		if [ -z "$USE_CONVERT" ] ; then
			giftopnm $arg.gif > $arg.pnm
			pnmtopng -transparent rgb:ff/ff/ff $arg.pnm > $arg.png
			pnmtojpeg -quality=100 -optimize -smooth=0 $arg.pnm > $arg.jpg
			pngtogd2 $arg.png $arg.gd2 0 1 
		else
			convert $arg.gif $arg.pnm
			convert $arg.pnm $arg.png
			convert $arg.pnm $arg.jpg
			convert $arg.png $arg.gd2
		fi
		convert $arg.pnm -resize 20x20 ${arg}_small.png
  fi
done

rm -f *.pnm
