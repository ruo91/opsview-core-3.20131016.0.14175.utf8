opsview-core-3.20131016.0.14175.utf8
====================================

git clone https://github.com/ruo91/opsview-core-3.20131016.0.14175.utf8.git

cd opsview-core-3.20131016.0.14175.utf8

mkdir ../tools

wget -P ../tools https://gist.githubusercontent.com/ruo91/9223533/raw/75f062e3a68ef8ad4b663884cd8c683dec7689aa/build_os

chmod a+x ../tools/build_os

make && make install

Thanks :)
