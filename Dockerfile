ARG DISTRO=focal
ARG GCC_MAJOR=11
ARG QT_MAJOR=514
ARG QT_VERSION=5.14.2
ARG QBS_BRANCH=v1.16.0
ARG RUNTIME_APT
ARG RUNTIME_XENIAL="libicu55 libglib2.0-0"
ARG RUNTIME_FOCAL="libicu66 libglib2.0-0 libpcre2-16-0"

FROM ubuntu:${DISTRO} AS gcc_base
ARG DISTRO
ARG GCC_MAJOR

ENV \
  APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 \
  DEBIAN_FRONTEND=noninteractive \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8

# install GCC
RUN \
  apt-get update --quiet \
  && apt-get upgrade \
  && apt-get install --yes --quiet --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    gnupg \
    wget \
  && wget -qO - "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x60c317803a41ba51845e371a1e9377a2ba9ef27f" | apt-key add - \
  && echo "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu ${DISTRO} main" > /etc/apt/sources.list.d/gcc.list \
  && apt-get update --quiet \
  && apt-get install --yes --quiet --no-install-recommends \
    libstdc++-${GCC_MAJOR}-dev \
    gcc-${GCC_MAJOR} \
    g++-${GCC_MAJOR} \
  && update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-${GCC_MAJOR} 100 \
  && update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-${GCC_MAJOR} 100 \
  && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_MAJOR} 100 \
  && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_MAJOR} 100 \
  && c++ --version \
  && apt-get --yes autoremove \
  && apt-get clean autoclean \
  && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

# compile & install Qbs
FROM gcc_base AS qbs-build
ARG DISTRO
ARG QT_MAJOR
ARG QT_VERSION
ARG QBS_BRANCH

ENV \
  QTDIR=/opt/qt${QT_MAJOR} \
  PATH=/opt/qt${QT_MAJOR}/bin:/opt/qbs/bin:${PATH} \
  LD_LIBRARY_PATH=/opt/qt${QT_MAJOR}/lib/x86_64-linux-gnu:/opt/qt${QT_MAJOR}/lib:${LD_LIBRARY_PATH} \
  PKG_CONFIG_PATH=/opt/qt${QT_MAJOR}/lib/pkgconfig:${PKG_CONFIG_PATH}

RUN \
  wget -qO - "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xC65D51784EDC19A871DBDBB710C56D0DE9977759" | apt-key add - \
  && echo "deb http://ppa.launchpad.net/beineri/opt-qt-${QT_VERSION}-${DISTRO}/ubuntu ${DISTRO} main" > /etc/apt/sources.list.d/qt.list \
  && apt-get update --quiet \
  && apt-get install --yes --quiet --no-install-recommends \
    git \
    make \
    libgl1-mesa-dev \
    qt${QT_MAJOR}script \
    qt${QT_MAJOR}base \
    qt${QT_MAJOR}tools \
  && apt-get --yes autoremove \
  && apt-get clean autoclean \
  && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

RUN \
  cd /opt \
  && git clone --depth 1 -b ${QBS_BRANCH} https://github.com/qbs/qbs.git qbs-src \
  && cd /opt/qbs-src \
  && qmake -r qbs.pro \
    QBS_INSTALL_PREFIX=/opt/qbs \
    CONFIG+=qbs_no_dev_install \
    CONFIG+=release CONFIG-=debug \
  && make -j \
  && make install \
  && rm -rf /opt/qbs-src

# final qbs-gcc (no Qt)
FROM gcc_base AS qbs-gcc
ARG DISTRO
ARG GCC_MAJOR
ARG QT_MAJOR
ARG QBS_BRANCH
ARG RUNTIME_APT
ARG RUNTIME_FOCAL
ARG RUNTIME_XENIAL

LABEL Description="Ubuntu ${DISTRO} - Gcc${GCC_MAJOR} + Qbs ${QBS_BRANCH}"

COPY --from=qbs-build /opt/qbs /opt/qbs
COPY --from=qbs-build /opt/qt${QT_MAJOR}/bin /opt/qt${QT_MAJOR}/bin
COPY --from=qbs-build /opt/qt${QT_MAJOR}/lib /opt/qt${QT_MAJOR}/lib
ENV \
  PATH=/opt/qbs/bin:${PATH} \
  LD_LIBRARY_PATH=/opt/qt${QT_MAJOR}/lib/x86_64-linux-gnu:/opt/qt${QT_MAJOR}/lib:${LD_LIBRARY_PATH}

RUN apt-get update --quiet \
  && if [ "${RUNTIME_APT}" != "" ] ; then export "RUNTIME_APT2=${RUNTIME_APT}" ; \
    elif [ "${DISTRO}" = "xenial" ] ; then export "RUNTIME_APT2=${RUNTIME_XENIAL}" ; \
    else export "RUNTIME_APT2=${RUNTIME_FOCAL}" ; \
    fi \
  && apt-get install --yes --quiet --no-install-recommends \
    ${RUNTIME_APT2} \
  && apt-get --yes autoremove \
  && apt-get clean autoclean \
  && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/* \
  && qbs setup-toolchains --type gcc /usr/bin/g++ gcc \
  && qbs config defaultProfile gcc \
  && qbs config --list

WORKDIR /build
ENTRYPOINT ["/opt/qbs/bin/qbs"]

# final qbs-gcc-qt (with Qt)
FROM gcc_base AS qbs-gcc-qt
ARG DISTRO
ARG GCC_MAJOR
ARG QT_MAJOR
ARG QT_VERSION
ARG QBS_BRANCH
ARG RUNTIME_APT
ARG RUNTIME_FOCAL
ARG RUNTIME_XENIAL

LABEL Description="Ubuntu ${DISTRO} - Gcc${GCC_MAJOR} + Qt ${QT_VERSION} + Qbs ${QBS_BRANCH}"

COPY --from=qbs-build /opt/qbs /opt/qbs
COPY --from=qbs-build /opt/qt${QT_MAJOR} /opt/qt${QT_MAJOR}
ENV \
  QTDIR=/opt/qt${QT_MAJOR} \
  PATH=/opt/qt${QT_MAJOR}/bin:/opt/qbs/bin:${PATH} \
  LD_LIBRARY_PATH=/opt/qt${QT_MAJOR}/lib/x86_64-linux-gnu:/opt/qt${QT_MAJOR}/lib:${LD_LIBRARY_PATH} \
  PKG_CONFIG_PATH=/opt/qt${QT_MAJOR}/lib/pkgconfig:${PKG_CONFIG_PATH}

RUN apt-get update --quiet \
  && if [ "${RUNTIME_APT}" != "" ] ; then export "RUNTIME_APT2=${RUNTIME_APT}" ; \
    elif [ "${DISTRO}" = "xenial" ] ; then export "RUNTIME_APT2=${RUNTIME_XENIAL}" ; \
    else export "RUNTIME_APT2=${RUNTIME_FOCAL}" ; \
    fi \
  && apt-get install --yes --quiet --no-install-recommends \
    ${RUNTIME_APT2} \
  && apt-get --yes autoremove \
  && apt-get clean autoclean \
  && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/* \
  && qbs setup-toolchains --detect \
  && qbs setup-qt /opt/qt${QT_MAJOR}/bin/qmake qt${QT_MAJOR} \
  && qbs config defaultProfile qt${QT_MAJOR} \
  && qbs config --list

WORKDIR /build
ENTRYPOINT ["/opt/qbs/bin/qbs"]
