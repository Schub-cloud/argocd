FROM viaductoss/ksops:v4.3.0 as ksops-builder

FROM quay.io/argoproj/argocd:v2.12.3

ARG SOPS_VERSION="v3.8.1"
ARG HELM_SECRETS_VERSION="4.5.1"

ENV HELM_SECRETS_BACKEND="sops" \
    HELM_PLUGINS="/home/argocd/.local/share/helm/plugins/" \
    HELM_SECRETS_HELM_PATH=/usr/local/bin/helm \
    HELM_SECRETS_VALUES_ALLOW_SYMLINKS=false \
    HELM_SECRETS_VALUES_ALLOW_ABSOLUTE_PATH=false \
    HELM_SECRETS_VALUES_ALLOW_PATH_TRAVERSAL=false \
    HELM_SECRETS_WRAPPER_ENABLED=false
# Switch to root for the ability to perform install
USER root

# Install tools needed for your repo-server to retrieve & decrypt secrets, render manifests
# (e.g. curl, awscli, gpg, sops)
RUN apt-get update && \
    apt-get install -y \
        curl \
        gpg \
        unzip && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install sops
RUN curl -o /usr/local/bin/sops -L https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64 && \
    chmod +x /usr/local/bin/sops

RUN ln -sf "$(helm env HELM_PLUGINS)/helm-secrets/scripts/wrapper/helm.sh" /usr/local/sbin/helm

# Switch back to non-root user
USER $ARGOCD_USER_ID

#################
# Install ksops #
#################
# Override the default kustomize executable with the Go built version
COPY --from=ksops-builder /usr/local/bin/kustomize /usr/local/bin/kustomize
# Add ksops executable to path
COPY --from=ksops-builder /usr/local/bin/ksops .config/kustomize/plugin/viaduct.ai/v1/ksops/

########################
# Install Helm Secrets #
########################
RUN /usr/local/bin/helm plugin install https://github.com/jkroepke/helm-secrets --version ${HELM_SECRETS_VERSION}
