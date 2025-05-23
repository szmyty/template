# syntax=docker/dockerfile:1

# Use a base image with common development tools (Ubuntu-based)
FROM mcr.microsoft.com/devcontainers/base@sha256:a04e0d63bb8087c8931947bed44364b3addeb40591949bbec9b18eafe80fc220

# Proxy Environment Variables
# https://docs.docker.com/engine/reference/builder/#predefined-args
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG FTP_PROXY
ARG ALL_PROXY
ARG http_proxy
ARG https_proxy
ARG no_proxy
ARG ftp_proxy
ARG all_proxy

# Locale and Timezone
ARG LANG=en_US.UTF-8
ARG LANGUAGE=en_US:en
ARG TZ=UTC
ARG TMPDIR=/tmp

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    DEBIAN_PRIORITY=critical \
    DEBCONF_NOWARNINGS=yes \
    TERM=xterm-256color \
    APT_LISTCHANGES_FRONTEND=none \
    APT_LISTBUGS_FRONTEND=none \
    TMPDIR=${TMPDIR} \
    LANG=${LANG} \
    LANGUAGE=${LANGUAGE} \
    TZ=${TZ} \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# Install required dependencies
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ccache \
        clang \
        clang-format \
        clang-tidy \
        cmake \
        libblosc-dev \
        libboost-all-dev \
        libbz2-dev \
        libffi-dev \
        liblz4-dev \
        liblzma-dev \
        libncurses5-dev \
        libncursesw5-dev \
        libreadline-dev \
        libsqlite3-dev \
        libssl-dev \
        libxi-dev \
        libxml2-dev \
        libxmlsec1-dev \
        libxslt1-dev \
        libzstd-dev \
        llvm \
        ninja-build \
        pkg-config \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
        tk-dev \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

# Set the devtools directory
ENV DEVTOOLS_HOME=/opt/devtools
ENV DEVTOOLS_LOGS=${DEVTOOLS_HOME}/logs

# Create the devtools directory
RUN mkdir --parents --mode 777 ${DEVTOOLS_HOME} \
    && mkdir --parents --mode 777 ${DEVTOOLS_LOGS} \
    && chown -R vscode:vscode ${DEVTOOLS_HOME} \
    && chown -R vscode:vscode ${DEVTOOLS_LOGS}

# Set asdf environment variables
ENV ASDF_DIR=${DEVTOOLS_HOME}/.asdf
ENV ASDF_DATA_DIR=${ASDF_DIR}/data
ENV ASDF_SHIMS_DIR=${ASDF_DATA_DIR}/shims
ENV ASDF_CONFIG_FILE=${ASDF_DIR}/.asdfrc

# Add asdf and Taskfile to the PATH
ENV TASKFILE_HOME_DIR=${DEVTOOLS_HOME}/taskfile
ENV PATH=${TASKFILE_HOME_DIR}:${ASDF_SHIMS_DIR}:${ASDF_DIR}/bin:${PATH}

# Set up user workspace
WORKDIR /workspace

# Ensure the container keeps running
CMD ["sleep", "infinity"]
