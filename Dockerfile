FROM ubuntu:focal-20210325 AS build

# the commit where parallel signal sending optimization was added
ENV ERLANG_REV OTP-25.0-rc1
ENV LANG=C.UTF-8

RUN apt-get update -&& \
  apt-get -y --no-install-recommends install \
  autoconf \
  dpkg-dev \
  gcc \
  g++ \
  make \
  libncurses-dev \
  unixodbc-dev \
  libssl-dev \
  libsctp-dev \
  wget \
  ca-certificates \
  pax-utils \
  git \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /OTP/subdir
RUN git clone -b master --single-branch https://github.com/erlang/otp /OTP/subdir

WORKDIR /OTP/subdir

RUN git checkout $ERLANG_REV
RUN ./otp_build autoconf
RUN ./configure --with-ssl --enable-dirty-schedulers
RUN make -j$(getconf _NPROCESSORS_ONLN)
RUN make install
RUN find /usr/local -regex '/usr/local/lib/erlang/\(lib/\|erts-\).*/\(man\|doc\|obj\|c_src\|emacs\|info\|examples\)' | xargs rm -rf
RUN find /usr/local -name src | xargs -r find | grep -v '\.hrl$' | xargs rm -v || true
RUN find /usr/local -name src | xargs -r find | xargs rmdir -vp || true
RUN scanelf --nobanner -E ET_EXEC -BF '%F' --recursive /usr/local | xargs -r strip --strip-all
RUN scanelf --nobanner -E ET_DYN -BF '%F' --recursive /usr/local | xargs -r strip --strip-unneeded

FROM ubuntu:focal-20210325 AS final

RUN apt-get update && \
  apt-get -y --no-install-recommends install \
  libodbc1 \
  libssl1.1 \
  libsctp1

COPY --from=build /usr/local /usr/local
ENV LANG=C.UTF-8
