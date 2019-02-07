#### Recent Additions:

This fixes basic support for GPUs to > 1 Nvidia GPUs.
I don't have a AMD GPU to try/test/modify it yet. Also tested on Ubuntu 16.04.

##### Setup 
Try setup instructions from legacy part below. If that doesn't work, you might need to install each of these packages manually.
```sh
$ sudo apt-get install -y gnome-common libgtk-3-dev
libgtop2-dev libappindicator3-0.1-cil-dev
libappindicator3-0.1 appindicator3-0.1 libappindicator3-dev

# add compiler repo
$ sudo add-apt-repository ppa:vala-team
$ sudo apt update

# install compiler
$ sudo apt install valac

# build
$ ./autogen.sh && make -j 8
$ sudo make install
```

##### Legacy README
Basic NVIDIA GPU support modification of the original applet.
Tested on Ubuntu 16.04

to compile and install:
```sh
$ sudo apt-get build-dep indicator-multiload
$ ./autogen.sh && make -j 8
$ sudo make install
```

##### Original README:
Reimplementation of the gnome-applets multiload applet in vala and for Canonicals appindicators.

Strings have been kept the same as in gnome-applets where possible to reduce translation work.

For more advanced settings such as which variables are shown and whether graphs
autoscale, open dconf-editor and navigate to /de/mh21/indicator-multiload/.

Expressions are strings with embedded code within $(...). Variables are of the
form provider.variable, a list is available from indicator-multiload -l. You
can use +, -, *, and / for calculations.