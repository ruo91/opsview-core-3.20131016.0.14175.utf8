Nagios Icon Generation Script README
====================================

-[ABOUT]-

This script converts one or more GIF files into the following formats:

- PNG
- JPEG
- GD2

The GIF image should have dimentions of 40x40 pixels. During conversion to GD2 any areas of white (FFFFFF) are set to be transparent, this works well in most cases. If you don't like this edit the following line in genicons.sh:

$path/pnmtopng -transparent rgb:ff/ff/ff $arg.pnm > $arg.png


-[PREREQUISITES]-

Make sure the following libraries are installed:

- libjpeg
- libpng
- libgd2

More specifically, make sure the following executables exist on your system:

/usr/bin/giftopnm
/usr/bin/pnmtopng
/usr/bin/pnmtojpeg
/usr/bin/pngtogd2

If they exist in a different path then edit the 'path' variable in genicons.sh accordingly


-[USAGE]-

This script has been designed to run under the GNU Bourne Again SHell (BASH).

The only argument you need to supply is the name(s) of GIF files you wish to convert. Eg:

./genicons.sh tux.gif

Wildcards are also acceptable:

./genicons.sh *.gif








Copyright (C) 2003-2013 Opsview Limited. All rights reserved
