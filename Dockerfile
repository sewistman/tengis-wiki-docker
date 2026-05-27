FROM seafileltd/seafile-mc:13.0-latest

ARG SEAFILE_VERSION=13.0.21

COPY tengis-wiki-fr/media/css/             /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/css/
COPY tengis-wiki-fr/media/img/             /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/img/
COPY tengis-wiki-fr/media/favicons/        /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/favicons/
COPY tengis-wiki-fr/seahub/templates/      /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/seahub/templates/
COPY tengis-wiki-fr/seahub/help/templates/ /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/seahub/help/templates/
COPY tengis-wiki-fr/locale/                /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/locale/

COPY tengis-wiki-fr/frontend/build/                  /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/frontend/build/
COPY tengis-wiki-fr/frontend/webpack-stats.pro.json  /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/frontend/webpack-stats.pro.json
COPY tengis-wiki-fr/media/assets/                    /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media/assets/

RUN find /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
