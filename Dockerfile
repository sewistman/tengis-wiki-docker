FROM seafileltd/seafile-mc:13.0-latest

ARG SEAFILE_VERSION=13.0.21

COPY tengis-wiki-fr/media/css/             /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/css/
COPY tengis-wiki-fr/media/img/             /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/img/
COPY tengis-wiki-fr/media/favicons/        /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/favicons/
COPY tengis-wiki-fr/seahub/templates/      /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/seahub/templates/
COPY tengis-wiki-fr/seahub/help/templates/ /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/seahub/help/templates/
COPY tengis-wiki-fr/locale/                /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/locale/

RUN find /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
