#!/usr/bin/bash

. ./build_solaris.cfg

do_extract() {
    echo -n "Extracting..."
    if [ ! -e $tarfile ]
    then
        echo "Cannot find $tarfile, exiting..."
        exit 1
    fi
    if [ $2 == 'gz' ]
    then
		extension=gz
        do_extracttool=gzcat
	    do_tartool=tar  
    elif [ $2 == 'xz' ]
    then 
		extension=xz
        do_extracttool=xzcat
	    do_tartool=tar  
    elif [ $2 == 'bz2' ]
    then
		extension=bz2
        do_extracttool=bzcat
	    do_tartool=tar  
    elif [ $2 == 'ggz' ]
    then
		extension=gz
        do_extracttool=gzcat
        do_tartool=/usr/sfw/bin/gtar
    fi
    tarfile=$SOFTWARE_DIR/$1.tar.$extension
    cd $TEMPDIR
    $do_extracttool $tarfile | $do_tartool xf -
    if [ $? -eq 0 ]
    then
        echo "done"
    else
        echo "failed"
        exit 1 
    fi
    cd $TEMPDIR/$1
}

do_patch() {
    echo -n "Patching ($3)... "
    patch -i $CONFDIR/$2 $3 >>${LOGDIR}/$1.log 2>&1
    if [ $? -eq 0 ]
    then
        echo "done"
    else
        echo "failed"
        exit 1 
    fi
}

do_configure() {
    echo -n "Configuring..."
    eval ./configure $2 >>${LOGDIR}/$1.log 2>&1
    if [ $? -eq 0 ]
    then
        echo "done"
    else
        echo "failed"
        exit 1 
    fi
}

do_build() {
    echo -n "Building..."
    maketool=make
    if [ "a$2" == "agnu" ]
    then
        maketool=gmake
    fi
    $maketool >>${LOGDIR}/$1.log 2>&1
    if [ $? -eq 0 ]
    then
        echo "done"
    else
        echo "failed"
        exit 1 
    fi
}

do_install() {
    echo -n "Installing..."
    maketool=make
    if [ "a$2" == "agnu" ]
    then
        maketool=gmake
    fi
    $maketool install >>${LOGDIR}/$1.log 2>&1
    if [ $? -eq 0 ]
    then
        echo "done"
    else
        echo "failed"
        exit 1 
    fi
    echo ""
}

##############################################
#                                            #
# pkg-config-0.28                            #
# http://pkgconfig.freedesktop.org/releases/ #
#                                            #
##############################################
if [ $BUILD_PKGCONFIG = 'y' ]
then
  SOFT='pkg-config-0.28'
  echo "Installing $SOFT"

  do_extract $SOFT gz

  do_configure $SOFT "--prefix=$INSTALL_DIR --with-internal-glib CFLAGS='-m64'"

  do_build $SOFT

  export PATH=/usr/xpg4/bin:$PATH
  do_install $SOFT
  export PATH=$COREPATH
fi

##########################
#                        # 
# xz-5.0.5               #
# http://tukaani.org/xz/ #
#                        #
##########################
if [ $BUILD_XZ = 'y' ]
then
  SOFT='xz-5.0.5'
  echo "Installing $SOFT"

  do_extract $SOFT gz

  do_configure $SOFT "--prefix=$INSTALL_DIR CFLAGS='-m64'"

  do_build $SOFT

  do_install $SOFT
fi

#####################################################
#                                                   #
# libiconv-1.14                                     #
# http://www.gnu.org/software/libiconv/#downloading #
#                                                   #
#####################################################
if [ $BUILD_ICONV = 'y' ]
then
  SOFT='libiconv-1.14'
  echo "Installing $SOFT"

  do_extract $SOFT gz

  do_configure $SOFT "--prefix=$INSTALL_DIR CFLAGS='-m64'"

  do_build $SOFT

  do_install $SOFT
fi

################################
#                              #
# make-3.82                    #
# http://ftp.gnu.org/gnu/make/ #
#                              #
################################
if [ $BUILD_MAKE = 'y' ]
then
  SOFT='make-3.82'
  echo "Installing $SOFT"

  do_extract $SOFT gz

  do_configure $SOFT "--prefix=$INSTALL_DIR"

  do_build $SOFT

  do_install $SOFT

  mv $INSTALL_DIR/bin/make $INSTALL_DIR/bin/gmake
fi

##########################################################
#                                                        #
# libffi-3.0.13                                          #
# http://ltsp.mirrors.tds.net/pub/sourceware.org/libffi/ #
#                                                        # 
##########################################################
if [ $BUILD_FFI = 'y' ]
then
  SOFT='libffi-3.0.13'
  echo "Installing $SOFT"

  do_extract $SOFT gz

  #do_patch $SOFT libffi_1.diff src/x86/ffi64.c
  #do_patch $SOFT libffi_2.diff src/x86/unix64.S

  do_configure $SOFT "--prefix=$INSTALL_DIR CFLAGS='-m64'"

  do_build $SOFT

  do_install $SOFT
fi

##################################################
#                                                #
# Python-2.7.6                                   #
# http://www.python.org/download/releases/       #
#                                                #
##################################################
if [ $BUILD_PYTHON = 'y' ]
then
  SOFT='Python-2.7.6'
  echo "Installing $SOFT"

  do_extract $SOFT gz

  export CC="$COMPILER_PATH/bin/cc -m64"
  do_configure $SOFT "CFLAGS='-m64 -mt' --prefix=$PYTHON_PATH"

  do_build $SOFT

  do_install $SOFT

  export CC="$COMPILER_PATH/bin/cc"
fi

#############################################
#                                           #
# libelf-0.8.13                             #
# http://www.mr511.de/software/english.html #
#                                           #
#############################################
if [ $BUILD_ELF = 'y' ]
then
  SOFT='libelf-0.8.13'
  echo "Installing $SOFT"

  do_extract $SOFT gz

  do_patch $SOFT libelf.diff configure

  export CC="$COMPILER_PATH/bin/cc -m64"
  do_configure $SOFT "--prefix=$INSTALL_DIR"

  do_build $SOFT

  do_install $SOFT

  export CC="$COMPILER_PATH/bin/cc"
fi

########################################
#                                      #
# gettext-0.18.3.1                     #
# http://www.gnu.org/software/gettext/ #
#                                      #
########################################
if [ $BUILD_GETTEXT = 'y' ]
then
  SOFT='gettext-0.18.3.1'
  echo "Installing $SOFT"

  do_extract $SOFT gz

  do_configure $SOFT "--prefix=$INSTALL_DIR CFLAGS='-m64' CXXFLAGS='-m64'"

  do_build $SOFT

  do_install $SOFT
fi

#####################################################
#                                                   #
# glib-2.32.4                                       #
# http://ftp.gnome.org/pub/gnome/sources/glib/2.32/ #
#                                                   #
#####################################################
if [ $BUILD_GLIB = 'y' ]
then
  SOFT='glib-2.32.4'
  echo "Installing $SOFT"

  do_extract $SOFT xz

  do_patch $SOFT libglib_1.diff glib/tests/Makefile.in

  do_patch $SOFT libglib_2.diff gio/gsocket.c

  do_configure $SOFT "--prefix=$INSTALL_DIR CFLAGS='-m64 -D_XPG6 -xc99=all -features=extensions' LDFLAGS='-lintl' --disable-dtrace"

  do_build $SOFT gnu

  do_install $SOFT gnu
fi

#############################################
#                                           #
# libpng-1.6.7                              #
# http://www.libpng.org/pub/png/libpng.html #
#                                           #
#############################################
if [ $BUILD_PNG = 'y' ]
then
  SOFT='libpng-1.6.7'
  echo "Installing $SOFT"

  do_extract $SOFT gz

  do_configure $SOFT "--prefix=$INSTALL_DIR CFLAGS='-m64'"

  do_patch $SOFT libpng.diff contrib/tools/pngfix.c

  do_build $SOFT

  do_install $SOFT
fi

######################################
#                                    #
# pixman-0.32.4                      #
# http://cairographics.org/releases/ #
#                                    # 
######################################
if [ $BUILD_PIXMAN = 'y' ]
then
  SOFT='pixman-0.32.4'
  echo "Installing $SOFT"

  do_extract $SOFT gz

  do_configure $SOFT "--prefix=$INSTALL_DIR CFLAGS='-m64'"

  do_build $SOFT

  do_install $SOFT
fi

#######################################################
#                                                     #
# freetype-2.5.2                                      #
# http://download.savannah.gnu.org/releases/freetype/ #
#                                                     #
#######################################################
if [ $BUILD_FREETYPE = 'y' ]
then
  SOFT='freetype-2.5.2'
  echo "Installing $SOFT"

  do_extract $SOFT ggz

  export GNUMAKE=gmake
  do_configure $SOFT "--prefix=$INSTALL_DIR CFLAGS='-m64'"

  do_build $SOFT gnu

  do_install $SOFT gnu
fi

############################################################
#                                                          #
# expat-2.1.0                                              #
# http://sourceforge.net/projects/expat/files/expat/2.1.0/ #
#                                                          #
############################################################
if [ $BUILD_EXPAT = 'y' ]
then
  SOFT='expat-2.1.0'
  echo "Installing $SOFT"

  do_extract $SOFT gz

  do_configure $SOFT "--prefix=$INSTALL_DIR CFLAGS='-m64'"

  do_build $SOFT

  do_install $SOFT
fi

###########################################################
#                                                         #
# fontconfig-2.11.0                                       #
# http://www.freedesktop.org/software/fontconfig/release/ #
#                                                         #
###########################################################
if [ $BUILD_FONTCONFIG = 'y' ]
then
  SOFT='fontconfig-2.11.0'
  echo "Installing $SOFT"

  do_extract $SOFT gz

  do_patch $SOFT libfontconfig_1.diff configure

  do_configure $SOFT "--prefix=$INSTALL_DIR CFLAGS='-m64'"

  do_patch $SOFT libfontconfig_2.diff test/test-migration.c

  do_build $SOFT gnu

  do_install $SOFT gnu
fi

######################################
#                                    #
# cairo-1.12.16                      #
# http://cairographics.org/releases/ #
#                                    #
######################################
if [ $BUILD_CAIRO = 'y' ]
then
  SOFT='cairo-1.12.16'
  echo "Installing $SOFT"

  do_extract $SOFT xz

  do_configure $SOFT "--prefix=$INSTALL_DIR --enable-xlib=no --enable-xlib-render=no --enable-win32=no CFLAGS='-m64 -xO1 -xc99=all'"

  do_build $SOFT

  do_install $SOFT
fi

###########################################################
#                                                         #
# pango-1.30.1                                            #
# from http://ftp.gnome.org/pub/GNOME/sources/pango/1.30/ #
# (later versions require harfbuzz)                       #
#                                                         #
###########################################################
if [ $BUILD_PANGO = 'y' ]
then
  SOFT='pango-1.30.1'
  echo "Installing $SOFT"

  do_extract $SOFT xz

  do_configure $SOFT "--prefix=$INSTALL_DIR CFLAGS='-m64' CXXFLAGS='-m64' CPPFLAGS='-m64'"

  do_patch $SOFT libpango.diff pango/opentype/Makefile

  do_build $SOFT gnu

  do_install $SOFT gnu
fi

####################################################
#                                                  #
# libgd-2.1.0.tar.gz                               #
# https://bitbucket.org/libgd/gd-libgd/downloads   #
#                                                  #
####################################################
if [ $BUILD_GD = 'y' ]
then
  SOFT='libgd-2.1.0'
  echo "Installing $SOFT"

  do_extract $SOFT gz

  do_configure $SOFT "--prefix=$INSTALL_DIR CFLAGS='-m64' CXXFLAGS='-m64' --with-png=$INSTALL_DIR --without-jpeg"

  do_build $SOFT gnu

  do_install $SOFT gnu
fi
