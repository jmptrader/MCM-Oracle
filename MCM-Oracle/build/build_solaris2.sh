#!/usr/bin/ksh

. ./build_solaris2.cfg

extract() {
    echo "Extracting..."
    tarfile=$SOFTWARE_DIR/$1.tar.gz
    if [ ! -e $tarfile ]
    then
        echo "Cannot find $tarfile, exiting..."
        exit 1
    fi
    if [ "a$2" != "a" ]
    then
        mkdir -p $INSTALL_DIR/$2
        if [ $? -ne 0 ]
        then
            echo "Cannot create $INSTALL_DIR/$2, exiting..."
            exit 1
        fi
    fi
    cd $TEMP_DIR
    gzcat $tarfile | $TAR xf -
    if [ $? -ne 0 ]
    then
        echo "Extraction failed, exiting..."
        exit 1
    fi
    cd $TEMP_DIR/$1 
}

#------------#
# pre-checks #
#------------#
if [ ! -e $CC ]
then
    echo "Cannot find Sun C compiler ($CC)"
    exit 1
fi
if [ ! -e $MAKE ]
then
    echo "Cannot find make command ($MAKE)"
    exit 1
fi
if [ ! -e $GMAKE ]
then
    echo "Cannot find GNU make ($GMAKE)"
    exit 1
fi
if [ ! -e $TAR ]
then
    echo "Cannot find GNU tar ($TAR)"
    exit 1
fi
if [ ! -d $INSTALL_DIR ]
then
    echo "Cannot find installation directory ($INSTALL_DIR)"
    exit 1
fi
if [ ! -d $SOFTWARE_DIR ]
then
    echo "Cannot find software directory ($SOFTWARE_DIR)"
    exit 1
fi
if [ ! -d $LOG_DIR ]
then
    echo "Cannot find log directory ($LOG_DIR)"
    exit 1
fi
if [ ! -d $TEMP_DIR ]
then
    echo "Cannot find temporary directory ($TEMP_DIR)"
    exit 1
fi

#---------#
# cleanup #
#---------#
rm -rf $TEMP_DIR/*
if [ $CLEANUP = 'y' ]
then
    echo "\nCleaning up installation directory ($INSTALL_DIR)"
    rm -rf $INSTALL_DIR/*
fi

#--------------------#
# BerkeleyDB install #
#--------------------#
if [ $INSTALL_BERKELEYDB = 'y' ]
then
    logfile=$LOG_DIR/${BERKELEYDB_SOFT}.log
    echo "\nInstalling BerkeleyDB ($BERKELEYDB_SOFT)"
    extract $BERKELEYDB_SOFT BerkeleyDB
    echo "Configuring..."
    cd build_unix
    ../dist/configure --prefix=$INSTALL_DIR/BerkeleyDB >$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Compiling..."
    $MAKE >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi
    echo "Installing..."
    $MAKE install >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi
    echo "BerkeleyDB is successfully installed"
fi

LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$INSTALL_DIR/BerkeleyDB/lib
export LD_LIBRARY_PATH

#-----------------#
# OpenSSL install #
#-----------------#
if [ $INSTALL_OPENSSL = 'y' ]
then
    logfile=$LOG_DIR/${OPENSSL_SOFT}.log
    echo "\nInstalling OpenSSL ($OPENSSL_SOFT)"
    extract $OPENSSL_SOFT openssl
    echo "Configuring..."
    ./Configure solaris64-x86_64-cc --prefix=$INSTALL_DIR/openssl --openssldir=$INSTALL_DIR/openssl shared >$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Compiling..."
    $MAKE >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi
    echo "Installing..."
    $MAKE install >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi
    echo "OpenSSL is successfully installed"
fi

LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$INSTALL_DIR/openssl/lib
export LD_LIBRARY_PATH

#--------------#
# perl install #
#--------------#
if [ $INSTALL_PERL = 'y' ]
then
    logfile=$LOG_DIR/${PERL_SOFT}.log
    echo "\nInstalling Perl ($PERL_SOFT)"
    extract $PERL_SOFT perl
    echo "Configuring..."
    ./Configure -de -Dcc=$SIMPLE_CC -Dprefix=$INSTALL_DIR/perl -Dusethreads -A ccflags='-m64 -fPIC' -A ldflags='-m64' >$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Compiling..."
    $MAKE >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi
    echo "Testing..."
    $MAKE test >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Testing failed, exiting..."
        exit 1
    fi
    echo "Installing..."
    $MAKE install >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi
    echo "Perl is successfully installed"
    chmod +w $INSTALL_DIR/perl/lib/5.??.?/IPC/Open3.pm
    patch -i $CONF_DIR/Open3.pm.diff $INSTALL_DIR/perl/lib/5.??.?/IPC/Open3.pm
    chmod -w $INSTALL_DIR/perl/lib/5.??.?/IPC/Open3.pm
fi

PATH=$INSTALL_DIR/perl/bin:$PATH
export PATH

#----------------#
# apache install #
#----------------#
if [ $INSTALL_APACHE = 'y' ]
then
    logfile=$LOG_DIR/${APACHE_SOFT}.log
    echo "\nInstalling Apache ($APACHE_SOFT)"
    extract $APACHE_SOFT apache
    echo "Configuring..."
    CFLAGS="-I$INSTALL_DIR/include -L$INSTALL_DIR/lib -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" CPPFLAGS="-I$INSTALL_DIR/include" ./configure --prefix=$INSTALL_DIR/apache --enable-ssl --enable-so --with-ssl=$INSTALL_DIR/openssl >$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Compiling..."
    $MAKE >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi
    patch -i $CONF_DIR/httpd.conf.diff docs/conf/httpd.conf >>$logfile 2>&1 # rt.cpan.org #66085
    echo "Installing..."
    $MAKE install >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi
    echo "Apache is successfully installed"
fi

#------------------#
# mod_perl install #
#------------------#
if [ $INSTALL_MODPERL = 'y' ]
then
    logfile=$LOG_DIR/${MODPERL_SOFT}.log
    echo "\nInstalling mod_perl ($MODPERL_SOFT)"
    extract $MODPERL_SOFT
    echo "Configuring..."
    perl Makefile.PL MP_APXS=$INSTALL_DIR/apache/bin/apxs LIBS="-L$INSTALL_DIR/lib"  >$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Compiling..."
    $MAKE >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi
#    echo "Testing..."
#    $MAKE test >>$logfile 2>&1
#    if [ $? -ne 0 ]
#    then
#        echo "Testing failed, exiting..."
#        exit 1
#    fi
    echo "Installing..."
    $MAKE install >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi
    echo "mod_perl is successfully installed"
fi

#-------------#
# php install #
#-------------#
if [ $INSTALL_PHP = 'y' ]
then
    logfile=$LOG_DIR/${PHP_SOFT}.log
    echo "\nInstalling PHP ($PHP_SOFT)"
    extract $PHP_SOFT php
    echo "Configuring..."
    ./configure --prefix=$INSTALL_DIR/php --with-apxs2=$INSTALL_DIR/apache/bin/apxs CFLAGS="-m64" CPPFLAGS="-m64" LDFLAGS="-m64 -L$INSTALL_DIR/lib" --with-gd=$INSTALL_DIR >$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Compiling..."
    $MAKE >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi
#    echo "Testing..."
#    $MAKE test >>$logfile 2>&1
#    if [ $? -ne 0 ]
#    then
#        echo "Testing failed, exiting..."
#        exit 1
#    fi
    echo "Installing..."
    $MAKE install >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi
    echo "PHP is successfully installed"
fi

#-----------------#
# rrdtool install #
#-----------------#
if [ $INSTALL_RRDTOOL = 'y' ]
then
    logfile=$LOG_DIR/${RRDTOOL_SOFT}.log
    echo "\nInstalling rrdtool ($RRDTOOL_SOFT)"
    extract $RRDTOOL_SOFT tools/rrdtool
    echo "Configuring..."
    LDFLAGS=-L$INSTALL_DIR/lib CPPFLAGS="-I$INSTALL_DIR/include/glib-2.0 -I$INSTALL_DIR/lib/glib-2.0/include -I$INSTALL_DIR/include/cairo -I$INSTALL_DIR/include/pango-1.0" CC=$CC ./configure --prefix=$INSTALL_DIR/tools/rrdtool --disable-ruby --disable-python --disable-tcl >$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Compiling..."
    $MAKE >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi
    echo "Installing..."
    $MAKE install >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$INSTALL_DIR/tools/rrdtool/lib
    export LD_LIBRARY_PATH
	echo LD_LIBRARY_PATH: $LD_LIBRARY_PATH
    echo "Building Perl module (1/2)"
    cd ./bindings/perl-shared
    
    perl Makefile.PL >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Compiling..."
    $MAKE >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi
    echo "Testing..."
    $MAKE test >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Testing failed, exiting..."
        exit 1
    fi
    echo "Installing..."
    $MAKE install >>$logfile 2>&1 
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi
    echo "Building Perl module (2/2)"
    cd ../perl-piped
    echo "Configuring..."
    perl Makefile.PL >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Compiling..."
    $MAKE >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi
    echo "Testing..."
    $MAKE test >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Testing failed, exiting..."
        exit 1
    fi
    echo "Installing..."
    $MAKE install >>$logfile 2>&1 
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi
    echo "rrdtool is successfully installed"
fi

PATH=$PATH:$INSTALL_DIR/tools/rrdtool/bin
export PATH
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$INSTALL_DIR/tools/rrdtool/lib
export LD_LIBRARY_PATH

#------------#
# m4 install #
#------------#
if [ $INSTALL_M4 = 'y' ]
then
    logfile=$LOG_DIR/${M4_SOFT}.log
    echo "\nInstalling m4 ($M4_SOFT)"
    extract $M4_SOFT
    echo "Configuring..."
    ./configure --prefix=$INSTALL_DIR CFLAGS="-m64" CPPFLAGS="-m64" LDFLAGS="-m64 -L$INSTALL_DIR/lib" >$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Compiling..."
    $MAKE >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi
    echo "Installing..."
    $MAKE install >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi
    echo "m4 is successfully installed"
fi

#------------------#
# autoconf install #
#------------------#
if [ $INSTALL_AUTOCONF = 'y' ]
then
    logfile=$LOG_DIR/${AUTOCONF_SOFT}.log
    echo "\nInstalling autoconf ($AUTOCONF_SOFT)"
    extract $AUTOCONF_SOFT
    echo "Configuring..."
    ./configure --prefix=$INSTALL_DIR CFLAGS="-m64" CPPFLAGS="-m64" LDFLAGS="-m64 -L$INSTALL_DIR/lib" >$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Compiling..."
    $MAKE >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi
    echo "Installing..."
    $MAKE install >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi
    echo "autoconf is successfully installed"
fi

#--------------#
# curl install #
#--------------#
if [ $INSTALL_CURL = 'y' ]
then
    logfile=$LOG_DIR/${CURL_SOFT}.log
    echo "\nInstalling curl ($CURL_SOFT)"
    extract $CURL_SOFT
    echo "Configuring..."
    ./configure --prefix=$INSTALL_DIR CFLAGS="-m64" CPPFLAGS="-m64" LDFLAGS="-m64 -L$INSTALL_DIR/lib" >$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Compiling..."
    $MAKE >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi
    echo "Installing..."
    $MAKE install >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi
    echo "curl is successfully installed"
fi

#-------------#
# git install #
#-------------#
if [ $INSTALL_GIT = 'y' ]
then
    logfile=$LOG_DIR/${GIT_SOFT}.log
    echo "\nInstalling git ($GIT_SOFT)"
    extract $GIT_SOFT
    echo "Configuring...(1)"
    gmake configure
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Configuring...(2)"
	export OPENSSLDIR=$INSTALL_DIR/openssl
    ./configure --prefix=$INSTALL_DIR/git --with-curl=$INSTALL_DIR CFLAGS="-m64" CPPFLAGS="-m64" LDFLAGS="-m64 -L$INSTALL_DIR/lib -I$INSTALL_DIR/include -lnsl -lsocket -lintl" >$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi
    echo "Compiling..."
    gmake all >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi
    echo "Installing..."
    gmake install >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi
    echo "git is successfully installed"
fi

if [ $INSTALL_MODULES = 'n' ]
then
    exit
fi

#--------------#
# perl modules #
#--------------#
for module in $PERL_MODULES
do
    echo "\nInstalling Perl module $module"

    tarfile=$SOFTWARE_DIR/${module}.tar.gz
    logfile=$LOG_DIR/${module}.log

    if [ ! -e $tarfile ]
    then
        echo "Cannot find $tarfile, exiting..."
        exit 1
    fi

    echo "Extracting..."
    cd $TEMP_DIR
    gzcat $tarfile | $TAR xf -
    if [ $? -ne 0 ]
    then
        echo "Extraction failed, exiting..."
        exit 1
    fi  
    cd $TEMP_DIR/$module

    args=''
    makefile='Makefile.PL'
    makecommand=$MAKE
	perlcommand='perl'

    case $module in
    'DBD-Sybase-1.14')
        args='--accept_test_defaults --chained Y --threaded_libs N'
        ;;
    'SOAP-Lite-1.08')
        args='--noprompt'
        ;;
    'Params-Validate-1.08')
        makefile='Build.PL'
        makecommand='./Build'
        ;;
    'Test-Requires-0.07')
        makefile='Build.PL'
        makecommand='./Build'
        ;;
    'GD-2.50')
        args='CCFLAGS="-m64"'
        ;;
    'XML-Parser-2.41')
        args="EXPATLIBPATH=$INSTALL_DIR/lib EXPATINCPATH=$INSTALL_DIR/include"
        ;;
    'XML-Twig-3.44')
        args='-y'
        ;;
    'String-Random-0.22')
        makefile='Build.PL'
        makecommand='./Build'
        ;;
    'SQL-Beautify-0.04')
        makefile='Build.PL'
        makecommand='./Build'
        ;;
    'HTML-Escape-1.08')
        makefile='Build.PL'
        makecommand='./Build'
        ;;
    'Protocol-WebSocket-0.16')
        makefile='Build.PL'
        makecommand='./Build'
        ;;
    'BerkeleyDB-0.54')
        sed -e "s|__INCLUDEDIR__|$INSTALL_DIR/BerkeleyDB/include|" -e "s|__LIBDIR__|$INSTALL_DIR/BerkeleyDB/lib|" $CONF_DIR/BerkeleyDB.config > $TEMP_DIR/$module/config.in
        ;;
    'Net-SSLeay-1.55')
        export OPENSSL_PREFIX=$INSTALL_DIR/openssl
        ;;
    'Crypt-SSLeay-0.64')
        args="INC='-I$INSTALL_DIR/openssl/include' LIBS='-L$INSTALL_DIR/openssl/lib -lcrypto -lssl'"
        ;;
    'libapreq2-2.13')
		perlcommand='./configure'
		makefile=''
        args="--with-perl=$INSTALL_DIR/perl/bin/perl --enable-perl-glue --with-apache2-apxs=$INSTALL_DIR/apache/bin/apxs LDFLAGS=-L$INSTALL_DIR/lib CFLAGS=-m64"
        ;;
    'Template-Toolkit-2.25')
        args='TT_ACCEPT=y'
        ;;
    esac

    echo "Configuring..."
    PERL_MM_USE_DEFAULT=1 $perlcommand $makefile $args >$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Configuration failed, exiting..."
        exit 1
    fi

    if [ $module = 'SQL-Library-0.0.5' ]
    then
        mv Makefile Makefile.tmp
        cat Makefile.tmp | tr -d "\0" > Makefile
    fi

    echo "Compiling..."
    $makecommand >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Compilation failed, exiting..."
        exit 1
    fi

    case $module in
    'DBD-Sybase-1.14')
        cp $CONF_DIR/Sybase-PWD $TEMP_DIR/$module/PWD
        ;;
    'SOAP-Lite-1.08')
        cat $TEMP_DIR/$module/examples/SOAP/Transport/HTTP/Daemon/ForkOnAccept.pm >> $TEMP_DIR/$module/lib/SOAP/Transport/HTTP.pm
        ;;
    'IPC-ShareLite-0.17')
        patch -i $CONF_DIR/ShareLite.pm.diff $TEMP_DIR/$module/lib/IPC/ShareLite.pm >>$logfile 2>&1
        patch -i $CONF_DIR/ShareLite.pm.diff $TEMP_DIR/$module/blib/lib/IPC/ShareLite.pm >>$logfile 2>&1
        ;;
    'Hash-Flatten-1.19')
        patch -i $CONF_DIR/Flatten.pm.diff $TEMP_DIR/$module/lib/Hash/Flatten.pm >>$logfile 2>&1
        patch -i $CONF_DIR/Flatten.pm.diff $TEMP_DIR/$module/blib/lib/Hash/Flatten.pm >>$logfile 2>&1
        ;;
    'XML-XPath-1.13')
        chmod +w $TEMP_DIR/$module/blib/lib/XML/XPath/Node/Element.pm
        patch -i $CONF_DIR/Element.pm.diff $TEMP_DIR/$module/blib/lib/XML/XPath/Node/Element.pm >>$logfile 2>&1
        ;;
    esac

    echo $SKIP_MODULES_FOR_TEST | grep $module

    if [ $? -eq 0 ]
    then
        echo "Skipping test"
    else
        echo "Testing..."
        $makecommand test >>$logfile 2>&1
        if [ $? -ne 0 ]
        then
            echo "Testing failed, exiting..."
            exit 1
        fi
    fi

    echo "Installing..."
    $makecommand install >>$logfile 2>&1
    if [ $? -ne 0 ]
    then
        echo "Installation failed, exiting..."
        exit 1
    fi 

    echo "$module successfully installed"
done

