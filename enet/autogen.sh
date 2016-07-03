#!/bin/sh
aclocal && \
autoconf && \
automake --add-missing
exit $?
