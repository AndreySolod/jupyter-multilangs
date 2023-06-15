ARG GOLANG_VERSION=1.20.5
ARG JULIA_VERSION=1.9.1
ARG DOTNET_SDK_VERSION=7.0
ARG ELIXIR_VERSION=1.12.3
ARG JAVA_VERSION=21

FROM golang:${GOLANG_VERSION}-bullseye as golang
FROM julia:${JULIA_VERSION}-bullseye as julia
FROM elixir:${ELIXIR_VERSION}-slim as elixir
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_SDK_VERSION}-bullseye-slim as dotnet-sdk
FROM openjdk:${JAVA_VERSION}-jdk-bullseye as openjdk

FROM continuumio/miniconda3

LABEL maintainer="SoloAD"
LABEL Description="JupyterLab for various languages. Thanks for HeRoMo"
LABEL Version="0.0.1"

RUN apt-get update && apt-get -y upgrade
RUN apt-get install -y pandoc build-essential cmake gnupg locales fonts-noto-cjk libtool libtool-bin libffi-dev libzmq3-dev libczmq-dev ffmpeg git unixodbc unixodbc-dev r-cran-rodbc bzip2 ca-certificates libffi-dev libgmp-dev libssl-dev libyaml-dev procps zlib1g-dev autoconf bison dpkg-dev gcc libbz2-dev libgdbm-compat-dev libgdbm-dev libglib2.0-dev libncurses-dev libreadline-dev libxml2-dev libxslt-dev make wget xz-utils curl
RUN conda update conda --yes && conda install -c conda-forge mamba -y && mamba update -c conda-forge --all
RUN mamba install -y -c conda-forge numpy scipy pandas matplotlib keras ipywidgets ipyleaflet plotly lxml xlrd xlwt jupyterlab jupyterlab-git jupyterlab-language-pack-ru-RU xeus-cling
RUN pip install torch sympy jupyter_dash
RUN mkdir -p /jupyterlab && mkdir -p /jupytercfg && mkdir -p /matplotlibrc
COPY build/jupyter_notebook_config.py /jupytercfg/jupyter_notebook_config.py
COPY build/matplotlibrc /matplotlibrc/matplotlibrc

EXPOSE "8888"
EXPOSE "8050"

CMD ["jupyter", "lab", "--no-browser", "--ip=0.0.0.0", "--allow-root", "--notebook-dir=/jupyterlab", "--config=/jupytercfg/jupyter_notebook_config.py"]

#Installing Sparql
RUN mkdir -p /temp && cd /temp && git clone https://github.com/paulovn/sparql-kernel && cd ./sparql-kernel && git pull origin pull/55/head && pip install . && jupyter sparqlkernel install

#Installing R

RUN R -e "install.packages('IRkernel')"
RUN R -e "IRkernel::installspec(user = FALSE)"

#Installing Julia
ENV JULIA_PATH /usr/local/julia
ENV PATH ${JULIA_PATH}/bin:$PATH
COPY --from=julia ${JULIA_PATH} ${JULIA_PATH}
RUN julia --version
RUN julia -e 'using Pkg; Pkg.add("IJulia"); Pkg.add("DataFrames"); Pkg.add("CSV"); Pkg.add("Colors"); Pkg.add("ColorSchemes"); Pkg.add("PlotlyJS");'

#Installing go
ENV GOLANG_VERSION=${GOLANG_VERSION}
# https://github.com/gopherdata/gophernotes/releases
ENV GOPHERNOTES_VERSION=0.7.5
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH
COPY --from=golang /usr/local/go/ /usr/local/go/
RUN go install github.com/gopherdata/gophernotes@v${GOPHERNOTES_VERSION} \
    && mkdir -p ~/.local/share/jupyter/kernels/gophernotes \
    && cd ~/.local/share/jupyter/kernels/gophernotes \
    && cp "$(go env GOPATH)"/pkg/mod/github.com/gopherdata/gophernotes@v${GOPHERNOTES_VERSION}/kernel/*  "." \
    && chmod +w ./kernel.json \
    && sed "s|gophernotes|$(go env GOPATH)/bin/gophernotes|" < kernel.json.in > kernel.json

#Install Rust
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH
ENV RUST_VERSION=1.70.0
ENV RUSTUP_VERSION=1.25.1
RUN set -eux; \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "${dpkgArch##*-}" in \
        amd64) rustArch='x86_64-unknown-linux-gnu'; rustupSha256='5cc9ffd1026e82e7fb2eec2121ad71f4b0f044e88bca39207b3f6b769aaa799c' ;; \
        arm64) rustArch='aarch64-unknown-linux-gnu'; rustupSha256='e189948e396d47254103a49c987e7fb0e5dd8e34b200aa4481ecc4b8e41fb929' ;; \
        *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
    esac; \
    url="https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${rustArch}/rustup-init"; \
    wget "$url"; \
    echo "${rustupSha256} *rustup-init" | sha256sum -c -; \
    chmod +x rustup-init; \
    ./rustup-init -y --no-modify-path --default-toolchain ${RUST_VERSION}; \
    rm rustup-init; \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME; \
    rustup --version; \
    cargo --version; \
    rustc --version;
RUN cargo install evcxr_jupyter \
    && evcxr_jupyter --install

# Install Ruby https://www.ruby-lang.org
ENV RUBY_VERSION=3.2.2
ENV RUBY_HOME=/opt/ruby
RUN git clone https://github.com/rbenv/ruby-build.git \
    && PREFIX=/usr/local ./ruby-build/install.sh \
    && mkdir -p ${RUBY_HOME} \
    && ruby-build ${RUBY_VERSION} ${RUBY_HOME}/${RUBY_VERSION}
ENV PATH=${RUBY_HOME}/${RUBY_VERSION}/bin:$PATH
RUN gem install --no-document \
                benchmark_driver \
                cztop \
                iruby \
    && iruby register --force

# Install .NET7
ENV DOTNET_ROOT=/usr/share/dotnet
ENV DOTNET_SDK_VERSION=${DOTNET_SDK_VERSION}
ENV PATH=/usr/share/dotnet:/root/.dotnet/tools:$PATH
COPY --from=dotnet-sdk ${DOTNET_ROOT} ${DOTNET_ROOT}
RUN ln -s ${DOTNET_ROOT}/dotnet /usr/bin/dotnet \
    && dotnet help
RUN dotnet tool install --global Microsoft.dotnet-interactive \
    && dotnet interactive jupyter install

# Install Erlang and Elixir
COPY --from=elixir /usr/local/lib/erlang /usr/local/lib/erlang
COPY --from=elixir /usr/local/lib/elixir /usr/local/lib/elixir
COPY --from=elixir /usr/local/bin/rebar3 /usr/local/bin/rebar3

RUN runtimeDeps=' \
		libodbc1 \
		libssl1.1 \
		libsctp1 \
	' \
	&& apt-get update \
    && apt-get install -y --no-install-recommends $runtimeDeps

RUN ln -s /usr/local/lib/erlang/bin/ct_run /usr/local/bin/ct_run \
    && ln -s /usr/local/lib/erlang/bin/dialyzer /usr/local/bin/dialyzer \
    && ln -s /usr/local/lib/erlang/bin/epmd /usr/local/bin/epmd \
    && ln -s /usr/local/lib/erlang/bin/erl /usr/local/bin/erl \
    && ln -s /usr/local/lib/erlang/bin/erlc /usr/local/bin/erlc \
    && ln -s /usr/local/lib/erlang/bin/escript /usr/local/bin/escript \
    && ln -s /usr/local/lib/erlang/bin/run_erl /usr/local/bin/run_erl \
    && ln -s /usr/local/lib/erlang/bin/to_erl /usr/local/bin/to_erl \
    && ln -s /usr/local/lib/erlang/bin/typer /usr/local/bin/typer \
    && ln -s /usr/local/lib/elixir/bin/elixir /usr/local/bin/elixir \
    && ln -s /usr/local/lib/elixir/bin/elixirc /usr/local/bin/elixirc \
    && ln -s /usr/local/lib/elixir/bin/iex /usr/local/bin/iex \
    && ln -s /usr/local/lib/elixir/bin/mix /usr/local/bin/mix
RUN mix local.hex --force \
    && mix local.rebar --force
RUN git clone https://github.com/filmor/ierl.git ierl \
    && cd ierl \
    && mkdir $HOME/.ierl \
    && mix deps.get \
    # Build lfe explicitly for nowwhoami
    && (cd deps/lfe && ~/.mix/rebar3 compile) \
    && (cd apps/ierl && env MIX_ENV=prod mix escript.build) \
    && cp apps/ierl/ierl $HOME/.ierl/ierl.escript \
    && chmod +x $HOME/.ierl/ierl.escript \
    && $HOME/.ierl/ierl.escript install erlang --user \
    && $HOME/.ierl/ierl.escript install elixir --user \
    && cd .. \
    && rm -rf ierl

# Install JVM languages
## Java
# https://github.com/allen-ball/ganymede
ENV JAVA_HOME /usr/local/openjdk-21
ENV PATH $JAVA_HOME/bin:$PATH
ENV GANYMEDE_VERSION=2.1.1.20221231
COPY --from=openjdk ${JAVA_HOME} ${JAVA_HOME}
RUN wget https://github.com/allen-ball/ganymede/releases/download/v${GANYMEDE_VERSION}/ganymede-${GANYMEDE_VERSION}.jar -O /tmp/ganymede.jar
RUN ${JAVA_HOME}/bin/java -jar /tmp/ganymede.jar -i --sys-prefix --id=java --display-name=Java21 --copy-jar=true
## Kotlin
RUN mamba install --quiet --yes -c jetbrains 'kotlin-jupyter-kernel'
## Scala
RUN curl -Lo coursier https://git.io/coursier-cli \
    && chmod +x coursier \
    && ./coursier launch --fork almond -- --install \
    && rm -f coursier

## Haskell

RUN apt-get install -y ghc haskell-stack
RUN stack install ihaskell --local-bin-path /bin/
RUN ihaskell install --stack

#Install c++
#C++ was installed on mamba install xeus-cling -c conda-forge

## Install javascript - uncompatible with c++ kernel
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs && npm install npm -g
RUN npm install -g ijavascript && ijsinstall
RUN jupyter lab build

## Install typescript
RUN npm install -g typescript-jupyter-kernel && ts-kernel install

#language servers

RUN rm -rf /temp
RUN mamba install -y -c conda-forge jedi-language-server
RUN julia -e 'using Pkg; Pkg.add("LanguageServer")'
RUN npm install -g --save-dev bash-language-server
RUN npm i -g jupyterlab-plotly

#Widgets
RUN mamba install -y -c conda-forge ipydrawio
RUN jupyter labextension install @krassowski/jupyterlab_go_to_definition

RUN mkdir -p /jupyterlab
WORKDIR "/jupyterlab"
VOLUME "/jupyterlab"

RUN mamba clean --all && apt-get autoremove && apt-get clean
