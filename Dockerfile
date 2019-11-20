FROM phusion/baseimage:0.9.22
MAINTAINER pressrelations

ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US
ENV LC_ALL en_US.UTF-8
ENV EDITOR vim
ENV TERM xterm

RUN locale-gen en_US.UTF-8

RUN sed -i -e 's,http://archive.ubuntu.com,http://de.archive.ubuntu.com,g' /etc/apt/sources.list
RUN apt-get update && \
	apt-get -y install git wget curl jq tzdata && \
	apt-get upgrade -y -o Dpkg::Options::="--force-confold" && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Deactivate unused services
RUN mv /etc/service/cron /etc/service/.cron
RUN mv /etc/service/sshd /etc/service/.sshd
RUN mv /etc/service/syslog-ng /etc/service/.syslog-ng
RUN mv /etc/service/syslog-forwarder /etc/service/.syslog-forwarder

ENV ERLANG_VERSION=1:22.1.4-1
ENV ELIXIR_VERSION=1.9.2

RUN cd /tmp && \
	wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && \
	dpkg -i erlang-solutions_1.0_all.deb && \
	rm /tmp/erlang*

RUN apt-get update && \
	apt-get install -y --no-install-recommends esl-erlang=${ERLANG_VERSION} unzip build-essential inotify-tools && \
	apt-get clean

RUN cd /tmp && \
	wget https://github.com/elixir-lang/elixir/releases/download/v$ELIXIR_VERSION/Precompiled.zip && \
	unzip Precompiled.zip -d /usr/local && \
	rm Precompiled.zip

RUN mix local.hex --force && \
	mix local.rebar --force && \
	mix hex.info

ENV ERL_AFLAGS "-kernel shell_history enabled"
ENV ELIXIR_DEPS_PATH "/opt/elixir/deps"
ENV ELIXIR_BUILD_PATH "/opt/elixir/build"

WORKDIR /app

COPY mix.* ./
RUN mix deps.get && \
	mix deps.compile && \
	mix compile && \
	MIX_ENV=test mix compile && \
	MIX_ENV=prod mix compile

COPY lib ./lib
COPY test ./test
COPY config ./config

RUN mix compile && \
	MIX_ENV=prod mix compile && \
 	MIX_ENV=test mix compile

RUN MIX_ENV=test mix test

COPY service/ /etc/service/

ENV PORT 4000
EXPOSE 4000
