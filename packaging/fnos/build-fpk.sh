#!/usr/bin/env bash
# Build native fnOS packages (.fpk) for Denova.
#
# Usage: packaging/fnos/build-fpk.sh [--skip-web] [x86|arm ...]   (default: x86 arm)
#   --skip-web    reuse the existing web/dist instead of rebuilding the frontend
# Environment:
#   FNPACK            fnpack executable (downloaded into packaging/fnos/out/tools when missing)
#   DENOVA_VERSION    binary version; defaults to the exact Git tag, otherwise "dev"
#   FPK_VERSION       package version; defaults to <latest tag>.<commits since tag>
# Requires: go, pnpm, python3 with Pillow (icons), network access for ripgrep and fnpack.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../.." && pwd)"
OUT="${HERE}/out"
FNPACK_VERSION="1.2.3"

SKIP_WEB=0
if [[ "${1:-}" == "--skip-web" ]]; then SKIP_WEB=1; shift; fi
ARCHES=("$@")
[[ ${#ARCHES[@]} -eq 0 ]] && ARCHES=(x86 arm)

log() { echo "==> $*"; }
die() { echo "Error: $*" >&2; exit 1; }

cd "${ROOT}"
for cmd in go python3; do command -v "${cmd}" >/dev/null 2>&1 || die "required command not found: ${cmd}"; done
python3 -c "import PIL" 2>/dev/null || die "python3 Pillow is required to generate icons"

LATEST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || echo v0.0.0)"
if [[ -z "${DENOVA_VERSION:-}" ]]; then
  if git describe --tags --exact-match >/dev/null 2>&1; then
    DENOVA_VERSION="$(git describe --tags --exact-match)"
  else
    DENOVA_VERSION="dev"
  fi
fi
DENOVA_VERSION="${DENOVA_VERSION#v}"
FPK_VERSION="${FPK_VERSION:-${LATEST_TAG#v}.$(git rev-list --count "${LATEST_TAG}..HEAD" 2>/dev/null || echo 0)}"
COMMIT="$(git rev-parse --short=8 HEAD)"
log "Denova ${DENOVA_VERSION} (${COMMIT}), fpk ${FPK_VERSION}, arches: ${ARCHES[*]}"

ensure_fnpack() {
  if [[ -n "${FNPACK:-}" ]]; then echo "${FNPACK}"; return; fi
  if command -v fnpack >/dev/null 2>&1; then command -v fnpack; return; fi
  local f="${OUT}/tools/fnpack-${FNPACK_VERSION}"
  if [[ ! -x "${f}" ]]; then
    mkdir -p "${OUT}/tools"
    echo "Downloading fnpack ${FNPACK_VERSION}" >&2
    curl -fsSL -o "${f}.tmp" "https://static2.fnnas.com/fnpack/fnpack-${FNPACK_VERSION}-linux-amd64"
    chmod +x "${f}.tmp"
    mv "${f}.tmp" "${f}"
  fi
  echo "${f}"
}

build_web() {
  if [[ "${SKIP_WEB}" -eq 0 ]]; then
    log "Building frontend"
    [[ -d web/node_modules ]] || pnpm --dir web install --frozen-lockfile
    pnpm --dir web build
  fi
  [[ -f web/dist/index.html ]] || die "web/dist is missing; build the frontend first"
  rm -rf internal/webfs/dist
  cp -r web/dist internal/webfs/dist
}

stage() {
  local arch="$1" goarch rg_target dir
  case "${arch}" in
    x86) goarch=amd64; rg_target=linux-x64 ;;
    arm) goarch=arm64; rg_target=linux-arm64 ;;
    *) die "unknown arch: ${arch} (use x86 or arm)" ;;
  esac
  dir="${OUT}/stage/${arch}/denova"
  rm -rf "${OUT}/stage/${arch}"
  mkdir -p "$(dirname "${dir}")"
  cp -a "${HERE}/template" "${dir}"

  log "[${arch}] Building binaries (linux/${goarch})"
  local ldflags="-s -w -X denova/internal/buildinfo.Version=${DENOVA_VERSION} -X denova/internal/buildinfo.InstallManager=fnos"
  CGO_ENABLED=0 GOOS=linux GOARCH="${goarch}" go build -tags embedweb -trimpath -ldflags "${ldflags}" -o "${dir}/app/denova" ./cmd/denova
  CGO_ENABLED=0 GOOS=linux GOARCH="${goarch}" go build -trimpath -ldflags "-s -w" -o "${dir}/app/bin/denova-fnos-setup" ./packaging/fnos/setup

  log "[${arch}] Bundling ripgrep, Skills and startup config"
  GOOS="$(go env GOHOSTOS)" GOARCH="$(go env GOHOSTARCH)" go run ./scripts/ripgrep-assets -target "${rg_target}" -destination "${dir}/app"
  cp -r skills "${dir}/app/skills"
  cp config.toml LICENSE "${dir}/app/"

  python3 - "${ROOT}/web/public/pwa-512.png" "${dir}" <<'PY'
import sys
from PIL import Image
src, pkg = sys.argv[1:3]
image = Image.open(src).convert("RGBA")
for size, names in ((64, ["ICON.PNG", "app/ui/images/icon_64.png"]), (256, ["ICON_256.PNG", "app/ui/images/icon_256.png"])):
    resized = image.resize((size, size), Image.LANCZOS)
    for name in names:
        resized.save(f"{pkg}/{name}")
PY

  local changelog="Denova ${DENOVA_VERSION} (${COMMIT})"
  sed -i -e "s|@VERSION@|${FPK_VERSION}|" -e "s|@PLATFORM@|${arch}|" -e "s|@CHANGELOG@|${changelog}|" "${dir}/manifest"
  python3 - "${dir}" <<'PY'
import json, os, sys
pkg = sys.argv[1]
for path in ("config/privilege", "config/resource", "app/ui/config", "wizard/install", "wizard/config"):
    json.load(open(os.path.join(pkg, path)))
PY
  chmod -R u=rwX,go=rX "${dir}"
  chmod 755 "${dir}"/cmd/* "${dir}/app/denova" "${dir}/app/bin/denova-fnos-setup"
}

build_web
FNPACK_BIN="$(ensure_fnpack)"
mkdir -p "${OUT}"
for arch in "${ARCHES[@]}"; do
  stage "${arch}"
  dir="${OUT}/stage/${arch}/denova"
  log "[${arch}] fnpack build"
  ( cd "${dir}" && "${FNPACK_BIN}" build )
  target="${OUT}/denova-${FPK_VERSION}-${arch}.fpk"
  mv -f "${dir}/denova.fpk" "${target}"
  log "[${arch}] $(du --apparent-size -h "${target}" | cut -f1) ${target}"
done
( cd "${OUT}" && sha256sum denova-"${FPK_VERSION}"-*.fpk > "SHA256SUMS-${FPK_VERSION}.txt" && cat "SHA256SUMS-${FPK_VERSION}.txt" )
