#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

GREEN='\033[0;32m'
RESET='\033[0m'

export DEBIAN_FRONTEND=noninteractive

. /etc/os-release

if [[ -z ${VERSION_ID:-} ]]; then
  echo "Unable to determine the distribution version from /etc/os-release" >&2
  exit 1
fi

DEBIAN_MAJOR="${VERSION_ID%%.*}"
REPO_DEB_PATH="/tmp/packages-microsoft-prod.deb"
REPO_DEB_URL="https://packages.microsoft.com/config/debian/${DEBIAN_MAJOR}/packages-microsoft-prod.deb"

echo -e "${GREEN}Registering the Microsoft apt repository...${RESET}"
if ! curl -fsSL -o "${REPO_DEB_PATH}" "${REPO_DEB_URL}"; then
  REPO_DEB_URL="https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb"
  echo -e "${GREEN}No repository for debian/${DEBIAN_MAJOR}; falling back to ubuntu/24.04...${RESET}"
  curl -fsSL -o "${REPO_DEB_PATH}" "${REPO_DEB_URL}"
fi
dpkg -i "${REPO_DEB_PATH}"
rm -f "${REPO_DEB_PATH}"

if command -v debconf-set-selections >/dev/null 2>&1; then
  echo "msodbcsql18 msodbcsql/ACCEPT_EULA boolean true" | debconf-set-selections
fi

echo -e "${GREEN}Installing the Microsoft ODBC Driver 18 for SQL Server...${RESET}"
ACCEPT_EULA=Y /app/docker/apt-install.sh \
  unixodbc-dev \
  msodbcsql18 \
  libgssapi-krb5-2

if ! odbcinst -q -d | grep -q "ODBC Driver 18 for SQL Server"; then
  echo "ODBC Driver 18 for SQL Server was not registered with unixODBC" >&2
  exit 1
fi

echo -e "${GREEN}Microsoft ODBC Driver 18 installation complete.${RESET}"
