FROM viaductoss/ksops:v3.0.2 as ksops

FROM argoproj/argocd:v2.5.3

# Dockerfile template based off https://itnext.io/argocd-a-helm-chart-deployment-and-working-with-helm-secrets-via-aws-kms-96509bfc5eb3

ARG SOPS_VERSION="v3.7.3"
ARG GCS_PLUGIN_VERSION="0.3.22"
ARG HELM_SECRETS_VERSION="4.2.2"

USER root

COPY helm-wrapper.sh /usr/local/bin/

RUN apt-get update

RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    curl -o /usr/local/bin/sops -L https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux && \
    chmod +x /usr/local/bin/sops && \
    cd /usr/local/bin && \
    mv helm helm.bin && \
    mv helm-wrapper.sh helm && \
    chmod +x helm

# Argo user
USER 999

ENV XDG_CONFIG_HOME=/home/argocd/.config

# Prepare ksops files
COPY --from=ksops /go/bin/kustomize /usr/local/bin/kustomize
COPY --from=ksops /go/src/github.com/viaduct-ai/kustomize-sops/* .config/kustomize/plugin/viaduct.ai/v1/ksops/

RUN /usr/local/bin/helm.bin plugin install https://github.com/jkroepke/helm-secrets --version ${HELM_SECRETS_VERSION}

RUN /usr/local/bin/helm.bin plugin install https://github.com/hayorov/helm-gcs.git --version ${GCS_PLUGIN_VERSION}

ENV HELM_PLUGINS="/home/argocd/.local/share/helm/plugins/"
