#!/bin/bash
set -uex
cd /tmp

# Heroku revision.  Must match in 'compile' program.
#
# Affixed to all vendored binary output to represent changes to the
# compilation environment without a change to the upstream version,
# e.g. PHP 5.3.27 without, and then subsequently with, libmcrypt.
heroku_rev='-2'

# Clear /app directory
find /app -mindepth 1 -print0 | xargs -0 rm -rf


# Take care of vendoring ClamAV.
clamav_version=0.98.1
clamav_dirname=clamav-$clamav_version
clamav_archive_name=$clamav_dirname.tar.gz

# Download ClamAV if necessary.
if [ ! -f $clamav_archive_name ]
then
    curl -Lo $clamav_archive_name http://downloads.sourceforge.net/clamav/clamav-0.98.1.tar.gz
fi


# Clean and extract ClamAV.
rm -rf $clamav_dirname
tar xzvf $clamav_archive_name


# Compile ClamAV
pushd $clamav_dirname
./configure --prefix=/app/vendor/clamav --disable-clamav
make -s
make install -s
popd


# Take care of vendoring libmcrypt
mcrypt_version=2.5.8
mcrypt_dirname=libmcrypt-$mcrypt_version
mcrypt_archive_name=$mcrypt_dirname.tar.bz2

# Download mcrypt if necessary
if [ ! -f mcrypt_archive_name ]
then
    curl -Lo $mcrypt_archive_name http://sourceforge.net/projects/mcrypt/files/Libmcrypt/2.5.8/libmcrypt-2.5.8.tar.bz2/download
fi

# Clean and extract mcrypt
rm -rf $mcrypt_dirname
tar jxf $mcrypt_archive_name

# Build and install mcrypt.
pushd $mcrypt_dirname
./configure --prefix=/app/vendor/mcrypt \
  --disable-posix-threads --enable-dynamic-loading
make -s
make install -s
popd

# Take care of vendoring Apache.
httpd_version=2.2.25
httpd_dirname=httpd-$httpd_version
httpd_archive_name=$httpd_dirname.tar.bz2

# Download Apache if necessary.
if [ ! -f $httpd_archive_name ]
then
    curl -LO http://archive.apache.org/dist/httpd/httpd-2.2.25.tar.bz2
fi

# Clean and extract Apache.
rm -rf $httpd_dirname
tar jxf $httpd_archive_name

# Build and install Apache.
pushd $httpd_dirname
./configure --prefix=/app/apache --enable-rewrite --with-included-apr
make -s
make install -s
popd

# Take care of vendoring PHP.
php_version=5.3.27
php_dirname=php-$php_version
php_archive_name=$php_dirname.tar.bz2

# Download PHP if necessary.
if [ ! -f $php_archive_name ]
then
    curl -Lo $php_archive_name http://us1.php.net/get/php-5.3.27.tar.bz2/from/www.php.net/mirror
fi

# Clean and extract PHP.
rm -rf $php_dirname
tar jxf $php_archive_name

# Compile PHP
pushd $php_dirname
./configure --prefix=/app/php --with-apxs2=/app/apache/bin/apxs     \
--with-mysql --with-pdo-mysql --with-pgsql --with-pdo-pgsql         \
--with-iconv --with-gd --with-curl=/usr/lib                         \
--with-config-file-path=/app/php --enable-soap=shared --enable-bcmath              \
--with-openssl --with-mcrypt=/app/vendor/mcrypt --enable-sockets
make -s
make install -s
popd

# Copy in MySQL client library.
mkdir -p /app/php/lib/php
cp /usr/lib/libmysqlclient.so.16 /app/php/lib/php


# php pecl modul installation
#
# $PATH manipulation Necessary for 'pecl install', which relies on
# PHP binaries relative to $PATH.

export PATH=/app/php/bin:$PATH
/app/php/bin/pecl channel-update pecl.php.net

# Use defaults for ZendOpcache build prompts.
yes '' | /app/php/bin/pecl install ZendOpcache-beta

# Use defaults for memcache build prompts.
yes '' | /app/php/bin/pecl install memcache

# Use defaults for zip build prompts.
yes '' | /app/php/bin/pecl install zip


# Take care of vendoring PHPClamAV.
phpclamav_version=0.15.7
phpclamav_dirname=php-clamav-$phpclamav_version
phpclamav_archive_name=$phpclamav_dirname.tar.gz

# Download ClamAV if necessary.
if [ ! -f $phpclamav_archive_name ]
then
    curl -Lo $phpclamav_archive_name http://sourceforge.net/projects/php-clamav/files/0.15/php-clamav_0.15.7.tar.gz/download
fi


# Clean and extract PHPClamAV.
rm -rf $phpclamav_dirname
tar xzvf $phpclamav_archive_name

# Compile PHPClamAV
pushd $phpclamav_dirname
phpize
./configure --with-clamav
make -s
popd

cp modules/clamav.so /app/php/lib/php/extensions/no-debug-non-zts-20090626


# Sanitize default cgi-bin to rid oneself of Apache sample
# programs.
find /app/apache/cgi-bin/ -mindepth 1 -print0 | xargs -0 rm -r

# Stamp and archive binaries.
pushd /app
echo $mcrypt_version > vendor/mcrypt/VERSION
tar -zcf mcrypt-"$mcrypt_version""$heroku_rev".tar.gz vendor/mcrypt
echo $httpd_version > apache/VERSION
tar -zcf apache-"$httpd_version""$heroku_rev".tar.gz apache
echo $php_version > php/VERSION
tar -zcf php-"$php_version""$heroku_rev".tar.gz php
echo clamav_version > vendor/clamav/VERSION
tar -zcf clamav-"$clamav_version""$heroku_rev".tar.gz vendor/clamav
popd
