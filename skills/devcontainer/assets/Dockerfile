# {{PROJECT_NAME}} devcontainer
# Base: toolchain image, pinned by digest for reproducibility.
FROM {{BASE_IMAGE}}

ARG TZ=UTC
ENV TZ="$TZ"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# System packages: dev QoL + runtime needs + sandboxing tools.
# Single layer, alphabetized, --no-install-recommends, clean up in-layer.
# The list below is the generic core; add stack-specific packages in the fence.
RUN apt-get update && apt-get install -y --no-install-recommends \
      bubblewrap \
      build-essential \
      ca-certificates \
      curl \
      dnsutils \
      fd-find \
      git \
      iproute2 \
      ipset \
      iptables \
      jq \
      locales \
      nano \
      openssh-client \
      ripgrep \
      socat \
      sudo \
      tmux \
      unzip \
      vim \
      zsh \
# >>> STACK:packages
# Add stack-specific apt packages here, one per line with trailing backslash.
# Example (Elixir/Phoenix): inotify-tools postgresql-client
# <<< STACK:packages
    && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && locale-gen \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# git-delta from GitHub release (apt version is stale)
ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" -o /tmp/git-delta.deb && \
    dpkg -i /tmp/git-delta.deb && \
    rm /tmp/git-delta.deb

# fzf from GitHub release (includes built-in shell integration)
ARG FZF_VERSION=0.70.0
RUN ARCH=$(dpkg --print-architecture) && \
    case "${ARCH}" in \
      amd64) FZF_ARCH="linux_amd64" ;; \
      arm64) FZF_ARCH="linux_arm64" ;; \
      *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-${FZF_ARCH}.tar.gz" | tar -xz -C /usr/local/bin

# Non-root user. Name is editor-neutral; UID/GID align to host via updateRemoteUserUID.
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME && \
    useradd  --uid $USER_UID --gid $USER_GID -m -s /bin/zsh $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

RUN mkdir -p /commandhistory /workspace /home/$USERNAME/.claude /opt && \
    touch /commandhistory/.bash_history /commandhistory/.zsh_history && \
    chown -R $USERNAME:$USERNAME /commandhistory /workspace /home/$USERNAME/.claude /opt

ENV DEVCONTAINER=true \
    SHELL=/bin/zsh \
    EDITOR=nano \
    VISUAL=nano

WORKDIR /workspace
USER $USERNAME

ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Claude Code, installed natively.
RUN curl -fsSL https://claude.ai/install.sh | bash
# >>> STACK:plugins
# Optional: install Claude Code marketplaces/plugins at build time as their own
# self-contained RUN layer (do NOT try to chain onto the install above), e.g.:
#   RUN claude plugin marketplace add anthropics/skills && \
#       claude plugin marketplace add trailofbits/skills
# Delete this fence if no build-time plugins are needed.
# <<< STACK:plugins

# Oh My Zsh
ARG ZSH_IN_DOCKER_VERSION=1.2.1
RUN sh -c "$(curl -fsSL https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -p git \
    -x

COPY --chown=$USERNAME:$USERNAME .zshrc /home/$USERNAME/.zshrc.custom
RUN echo 'source ~/.zshrc.custom' >> /home/$USERNAME/.zshrc

COPY --chown=$USERNAME:$USERNAME post_install.sh /opt/post_install.sh
RUN chmod +x /opt/post_install.sh
