# BUILD
FROM ubuntu:20.04

# https://github.com/babelfish-for-postgresql/babelfish-for-postgresql/tags
ARG BABELFISH_VERSION=BABEL_3_1_0__PG_15_2

ENV DEBIAN_FRONTEND=noninteractive
ENV BABELFISH_HOME=/opt/babelfish

RUN apt-get update && apt-get install -y --no-install-recommends\
	build-essential flex libxml2-dev libxml2-utils\
	libxslt-dev libssl-dev libreadline-dev zlib1g-dev\
	libldap2-dev libpam0g-dev gettext uuid uuid-dev\
	cmake lld apt-utils libossp-uuid-dev gnulib bison\
	xsltproc icu-devtools libicu66\
	libicu-dev gawk\
	curl openjdk-8-jre openssl\
	g++ libssl-dev python-dev libpq-dev\
	pkg-config libutfcpp-dev\
	gnupg unixodbc-dev net-tools unzip wget

# Download source.
WORKDIR /workplace
ENV BABELFISH_REPO=babelfish-for-postgresql/babelfish-for-postgresql
ENV BABELFISH_URL=https://github.com/${BABELFISH_REPO}
ENV BABELFISH_TAG=${BABELFISH_VERSION}
ENV BABELFISH_FILE=${BABELFISH_VERSION}.tar.gz
RUN wget ${BABELFISH_URL}/releases/download/${BABELFISH_TAG}/${BABELFISH_FILE}
RUN tar -xvzf ${BABELFISH_FILE}

# ENV
ENV PG_SRC=/workplace/${BABELFISH_VERSION}
WORKDIR ${PG_SRC}
ENV PG_CONFIG=${BABELFISH_HOME}/bin/pg_config

# ANTLR
ENV ANTLR4_VERSION=4.9.3
ENV ANTLR4_JAVA_BIN=/usr/bin/java
ENV ANTLR4_RUNTIME_LIBRARIES=/usr/include/antlr4-runtime
ENV ANTLR_FILE=antlr-${ANTLR4_VERSION}-complete.jar
ENV ANTLR_EXECUTABLE=/usr/local/lib/${ANTLR_FILE}
ENV ANTLR_CONTRIB=${PG_SRC}/contrib/babelfishpg_tsql/antlr/thirdparty/antlr
ENV ANTLR_RUNTIME=/workplace/antlr4

RUN cp ${ANTLR_CONTRIB}/${ANTLR_FILE} /usr/local/lib

WORKDIR /workplace
ENV ANTLR_DOWNLOAD=http://www.antlr.org/download
ENV ANTLR_CPP_SOURCE=antlr4-cpp-runtime-${ANTLR4_VERSION}-source.zip

RUN wget ${ANTLR_DOWNLOAD}/${ANTLR_CPP_SOURCE}
RUN unzip -d ${ANTLR_RUNTIME} ${ANTLR_CPP_SOURCE}

RUN mkdir -p ${ANTLR_RUNTIME}/build && cd ${ANTLR_RUNTIME}/build && cmake .. -D\
	ANTLR_JAR_LOCATION=${ANTLR_EXECUTABLE}\
	-DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release && make && make install

# Build PostgreSQL.
RUN cd ${PG_SRC} && ./configure CFLAGS="-ggdb"\
	--prefix=${BABELFISH_HOME}/\
	--enable-debug\
	--with-ldap\
	--with-libxml\
	--with-pam\
	--with-uuid=ossp\
	--enable-nls\
	--with-libxslt\
	--with-icu\
	--with-openssl

RUN cd ${PG_SRC} && make DESTDIR=${BABELFISH_HOME}/ 2>error.txt && make install
RUN cd ${PG_SRC}/contrib && make && make install
RUN cp /usr/local/lib/libantlr4-runtime.so.${ANTLR4_VERSION} ${BABELFISH_HOME}/lib
RUN cd ${PG_SRC}/contrib/babelfishpg_tsql/antlr && cmake -Wno-dev . && make all
RUN cd ${PG_SRC}/contrib/babelfishpg_common && make && make PG_CONFIG=${PG_CONFIG} install
RUN cd ${PG_SRC}/contrib/babelfishpg_money && make && make PG_CONFIG=${PG_CONFIG} install
RUN cd ${PG_SRC}/contrib/babelfishpg_tds && make && make PG_CONFIG=${PG_CONFIG} install
RUN cd ${PG_SRC}/contrib/babelfishpg_tsql && make && make PG_CONFIG=${PG_CONFIG} install

# RUN
FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
ENV BABELFISH_HOME=/opt/babelfish
ENV BABELFISH_DATA=/data/babelfish
WORKDIR ${BABELFISH_HOME}

COPY --from=0 ${BABELFISH_HOME} .

RUN apt-get update && apt-get install -y --no-install-recommends\
	libssl1.1 openssl libldap-2.4-2 libxml2 libpam0g uuid libossp-uuid16\
	libxslt1.1 libicu66 libpq5 unixodbc

RUN mkdir -p /data
RUN useradd -ms /bin/bash postgres && chown -R postgres /data && chmod -R 750 /data
VOLUME /data
USER postgres

EXPOSE 1433 5432

COPY start.sh /
ENTRYPOINT [ "/start.sh" ]