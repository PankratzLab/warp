FROM us.gcr.io/broad-gotc-prod/samtools:1.0.0-1.11-1624651616

ARG BWA_VERSION=0.7.15 \
        PICARD_PUBLIC_VERSION=2.26.10

ENV TERM=xterm-256color \
    BWA_URL=https://github.com/lh3/bwa/releases/download/v${BWA_VERSION}/bwakit-${BWA_VERSION}_x64-linux.tar.bz2 \
    PICARD_URL=https://github.com/broadinstitute/picard/releases/download/${PICARD_PUBLIC_VERSION}/picard.jar

LABEL MAINTAINER="Broad Institute DSDE <dsde-engineering@broadinstitute.org>" \
        BWA_VERSION=${BWA_VERSION} \
        PICARD_PUBLIC_VERSION=${PICARD_PUBLIC_VERSION}

WORKDIR /usr/gitc

# Install dependencies
RUN set -eux; \
        apk add --no-cache \
            gcompat \
            libc6-compat \
            openjdk8 \
    ; \
# Install BWA 
    # apk add bwa;\

    # mkdir temp; \
    # cd temp; \
    # \
    # wget ${BWA_URL} -O bwakit-${BWA_VERSION}.tar.bz2; \
    # tar xf bwakit-${BWA_VERSION}.tar.bz2;  \
    # mv bwa.kit/bwa ../bwa; \
    # \
    # cd ../; \
    # rm -r temp \
    # ; \
# Install picard
    wget ${PICARD_URL};

# Install BWA - use managed package instead of bwa-kit (no precompiled linux distro for 0.7.17)
FROM alpine:3.15 AS bwa-download
RUN apk update && apk upgrade
RUN apk add curl tar xz bzip2
ARG BWA_VERSION=0.7.15
RUN curl -OL https://downloads.sourceforge.net/project/bio-bwa/bwa-${BWA_VERSION}.tar.bz2
RUN tar xjf bwa-${BWA_VERSION}.tar.bz2

FROM alpine:3.15 AS bwa-build
RUN apk update && apk upgrade
RUN apk add bash gcc libc-dev make autoconf automake libtool curl-dev zlib-dev bzip2-dev xz-dev openssl-dev
RUN apk add patch
ARG BWA_VERSION=0.7.15
COPY --from=bwa-download /bwa-${BWA_VERSION} /bwa-${BWA_VERSION}
WORKDIR /bwa-${BWA_VERSION}
# COPY bwa-patch.patch /
# RUN patch -p1 < /bwa-patch.patch
RUN make CC='gcc -fcommon'
RUN make -j4
RUN install -D -t /dest/usr/bin bwa
RUN install -D -t /dest/usr/share/man/man1 bwa.1

# Set tini as default entrypoint
ENTRYPOINT [ "/sbin/tini", "--" ]
