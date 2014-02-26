opsview-core-3.20131016.0.14175.utf8
====================================

git clone https://github.com/ruo91/opsview-core-3.20131016.0.14175.utf8.git

cd opsview-core-3.20131016.0.14175.utf8

mkdir ../tools

echo "#!/usr/bin/perl" > ../tools/build_os

echo "$os = "ubuntu12";" >> ../tools/build_os

echo "print $os, $/;" >> ../tools/build_os

chmod a+x ../tools/build_os

make && make install

Thanks :)
