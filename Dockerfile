FROM node:24-slim

ARG TERRAFORM_VERSION=1.15.7
ARG FORGE_CLI_VERSION=13.2.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
        git \
    && architecture="$(dpkg --print-architecture)" \
    && case "${architecture}" in \
        amd64) terraform_arch="amd64" ;; \
        arm64) terraform_arch="arm64" ;; \
        *) echo "Unsupported architecture: ${architecture}" >&2; exit 1 ;; \
    esac \
    && curl -fsSLO \
        "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${terraform_arch}.zip" \
    && curl -fsSLO \
        "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
    && grep \
        "terraform_${TERRAFORM_VERSION}_linux_${terraform_arch}.zip" \
        "terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
        | sha256sum -c - \
    && unzip \
        "terraform_${TERRAFORM_VERSION}_linux_${terraform_arch}.zip" \
        -d /usr/local/bin \
    && rm \
        "terraform_${TERRAFORM_VERSION}_linux_${terraform_arch}.zip" \
        "terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
    && npm install --global "@forge/cli@${FORGE_CLI_VERSION}" \
    && npm cache clean --force \
    && apt-get purge -y --auto-remove curl unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["bash"]
