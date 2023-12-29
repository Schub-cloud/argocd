FROM viaductoss/ksops:v4.3.0 as ksops-builder

FROM quay.io/argoproj/argocd:v2.9.3

ARG SOPS_VERSION="v3.8.1"
ARG HELM_SECRETS_VERSION="4.5.1"

# Switch to root for the ability to perform install
USER root

COPY helm-wrapper.sh /usr/local/bin/

# Install tools needed for your repo-server to retrieve & decrypt secrets, render manifests
# (e.g. curl, awscli, gpg, sops)
RUN apt-get update && \
    apt-get install -y \
        curl \
        awscli \
        gpg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    curl -o /usr/local/bin/sops -L https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux && \
    chmod +x /usr/local/bin/sops &&\
    cd /usr/local/bin && \
    mv helm helm.bin && \
    mv helm-wrapper.sh helm && \
    chmod +x helm

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
ENV HELM_PLUGINS="/home/argocd/.local/share/helm/plugins/"
RUN /usr/local/bin/helm.bin plugin install https://github.com/jkroepke/helm-secrets --version ${HELM_SECRETS_VERSION}
