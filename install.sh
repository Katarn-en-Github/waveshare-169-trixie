#!/usr/bin/env bash
#
# waveshare-169-trixie - Instalador autónomo para Waveshare 1.69" ST7789V2
# Raspberry Pi OS Trixie (armhf), SPI + DRM/MIPI-DBI
#
# No depende de config/waveshare-169.conf ni instala servicios o paquetes.
# La configuración se añade a config.txt y fbcon=map:1 a cmdline.txt.
# uninstall.sh deberá restaurar cmdline.txt desde el respaldo inicial.

set -Eeuo pipefail

# -----------------------------------------------------------------------------
# Configuración del proyecto (fuente única operativa: este script)
# -----------------------------------------------------------------------------
readonly PROJECT="waveshare-169-trixie"
readonly REPO_RAW="https://raw.githubusercontent.com/Katarn-en-Github/waveshare-169-trixie/main"
readonly CONFIG_FILE="/boot/firmware/config.txt"
readonly CMDLINE_FILE="/boot/firmware/cmdline.txt"
readonly FBCON_PARAMETER="fbcon=map:1"
readonly OVERLAY_FILE="/boot/firmware/overlays/mipi-dbi-spi.dtbo"
readonly FIRMWARE_DIR="/lib/firmware"
readonly FIRMWARE_TARGET="${FIRMWARE_DIR}/panel.bin"
readonly STATE_DIR="/var/lib/${PROJECT}"
readonly BEGIN_MARKER="# BEGIN ${PROJECT}"
readonly END_MARKER="# END ${PROJECT}"

readonly DISPLAY_OVERLAY="mipi-dbi-spi"
readonly SPI_DEVICE="spi0-0"
readonly SPI_SPEED_HZ="32000000"
readonly SPI_WRITE_ONLY="1"
readonly GPIO_RESET="27"
readonly GPIO_DC="25"
readonly GPIO_BACKLIGHT="18"
readonly PANEL_FIRMWARE_SIZE="103"

# Formato: orientación|archivo|SHA256|ancho|alto|parámetro de offset|valor MADCTL
readonly ORIENTATION_0='0|panel.bin|b1cc4a8455152e0563fb5db50b19cc3a5b6bbef54322f378adcd197820e0d7b9|240|280|y-offset=20|0x00'
readonly ORIENTATION_90='90|waveshare-169-init-90.bin|ea5d93e09a383fbd5798d99e34e62871b1babe78f1c64ce02fc512e0f18cc671|280|240|x-offset=20|0x60'
readonly ORIENTATION_180='180|waveshare-169-init-180.bin|426550f67f1b636f68913e76c2f81bd85f0ce87177b6305b50b9c8e1268e2427|240|280|y-offset=20|0xC0'
readonly ORIENTATION_270='270|waveshare-169-init-270.bin|3b12d7597bf741921989b1d098efb2a337db0e68f4972649fe9679174e6338d6|280|240|x-offset=20|0xA0'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { printf '  %b[INFO]%b %s\n' "$GREEN" "$NC" "$*"; }
warning() { printf '  %b[AVISO]%b %s\n' "$YELLOW" "$NC" "$*"; }
error()   { printf '  %b[ERROR]%b %s\n' "$RED" "$NC" "$*" >&2; }
die()     { error "$*"; exit 1; }

WORK_DIR=""
STAGED_STATE_DIR=""
STATE_CREATED=0
TRANSACTION_STARTED=0
ROLLING_BACK=0
ROLLBACK_FAILED=0
KEEP_WORK_DIR=0
KEEP_STATE_DIR=0
INSTALL_SUCCEEDED=0
HAD_FIRMWARE=0

cleanup() {
    if [[ -n "$STAGED_STATE_DIR" && -d "$STAGED_STATE_DIR" ]]; then
        rm -rf -- "$STAGED_STATE_DIR"
    fi
    if [[ "$KEEP_STATE_DIR" != "1" && "$INSTALL_SUCCEEDED" != "1" &&
          "$STATE_CREATED" == "1" && "$TRANSACTION_STARTED" == "0" && -d "$STATE_DIR" ]]; then
        rm -rf -- "$STATE_DIR"
    fi
    if [[ "$KEEP_WORK_DIR" != "1" && -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        rm -rf -- "$WORK_DIR"
    fi
}

rollback() {
    local status="${1:-1}"
    (( TRANSACTION_STARTED == 1 )) || return 0
    (( ROLLING_BACK == 0 )) || return 0
    ROLLING_BACK=1
    trap - ERR INT TERM HUP
    set +e
    error "La instalación no se completó. Intentando restaurar los archivos anteriores..."

    if [[ -f "$WORK_DIR/config.txt.before-transaction" ]]; then
        cp -a -- "$WORK_DIR/config.txt.before-transaction" "$CONFIG_FILE" || ROLLBACK_FAILED=1
    else
        ROLLBACK_FAILED=1
    fi

    if [[ -f "$WORK_DIR/cmdline.txt.before-transaction" ]]; then
        cp -a -- "$WORK_DIR/cmdline.txt.before-transaction" "$CMDLINE_FILE" || ROLLBACK_FAILED=1
    else
        ROLLBACK_FAILED=1
    fi

    if (( HAD_FIRMWARE == 1 )); then
        if [[ -f "$WORK_DIR/panel.bin.before-transaction" ]]; then
            cp -a -- "$WORK_DIR/panel.bin.before-transaction" "$FIRMWARE_TARGET" || ROLLBACK_FAILED=1
        else
            ROLLBACK_FAILED=1
        fi
    else
        rm -f -- "$FIRMWARE_TARGET" || ROLLBACK_FAILED=1
    fi

    if (( ROLLBACK_FAILED == 0 && STATE_CREATED == 1 )); then
        rm -rf -- "$STATE_DIR" || ROLLBACK_FAILED=1
    fi

    TRANSACTION_STARTED=0
    if (( ROLLBACK_FAILED == 1 )); then
        KEEP_WORK_DIR=1
        KEEP_STATE_DIR=1
        error "ATENCIÓN: la restauración no pudo completarse por completo."
        error "Se conservaron los archivos temporales para recuperación en: $WORK_DIR"
        error "No borres ese directorio. Código de salida original: $status"
    else
        error "Los archivos anteriores fueron restaurados. Código de salida: $status"
    fi
}

on_error() {
    local status=$?
    rollback "$status"
    exit "$status"
}

trap cleanup EXIT
trap on_error ERR
trap 'rollback 130; exit 130' INT
trap 'rollback 143; exit 143' TERM
trap 'rollback 129; exit 129' HUP

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "No se encontró el comando requerido: $1"
}

download_file() {
    local url="$1"
    local destination="$2"

    if command -v curl >/dev/null 2>&1; then
        curl --fail --location --silent --show-error "$url" --output "$destination"
    elif command -v wget >/dev/null 2>&1; then
        wget --quiet --output-document="$destination" "$url"
    else
        die "Se necesita curl o wget para descargar el firmware."
    fi
}

check_platform() {
    [[ $EUID -eq 0 ]] || die "Ejecuta el instalador con sudo: sudo bash install.sh"
    [[ -r /etc/os-release ]] || die "No se puede identificar el sistema operativo."
    # shellcheck disable=SC1091
    source /etc/os-release

    [[ "${ID:-}" == "raspbian" ]] ||
        die "Sistema no reconocido como Raspberry Pi OS. Se requiere Raspberry Pi OS Trixie."
    [[ "${VERSION_CODENAME:-}" == "trixie" ]] ||
        die "Este instalador está preparado para Raspberry Pi OS Trixie."

    local architecture
    architecture="$(dpkg --print-architecture)"
    [[ "$architecture" == "armhf" ]] ||
        die "Arquitectura no validada: ${architecture}. Se requiere armhf."

    [[ -d /boot/firmware ]] || die "No existe /boot/firmware."
    [[ -f "$CONFIG_FILE" && -w "$CONFIG_FILE" ]] ||
        die "No existe o no se puede escribir $CONFIG_FILE."
    [[ -f "$CMDLINE_FILE" && -w "$CMDLINE_FILE" && ! -L "$CMDLINE_FILE" ]] ||
        die "No existe, no es seguro o no se puede escribir $CMDLINE_FILE."
    [[ -f "$OVERLAY_FILE" ]] ||
        die "No se encuentra el overlay $OVERLAY_FILE. Comprueba Raspberry Pi OS."
    [[ -d "$FIRMWARE_DIR" && -w "$FIRMWARE_DIR" ]] ||
        die "No existe o no se puede escribir $FIRMWARE_DIR."

    [[ -r /proc/device-tree/model ]] ||
        die "No se pudo identificar el modelo del equipo mediante Device Tree."
    local model
    model="$(tr -d '\0' </proc/device-tree/model)"
    [[ "$model" == *"Raspberry Pi"* ]] ||
        die "El equipo no parece ser una Raspberry Pi: $model"
    info "Equipo detectado: $model"

    info "Sistema: ${PRETTY_NAME:-Raspberry Pi OS Trixie}"
    info "Arquitectura: $architecture"
}

select_orientation() {
    local choice record

    printf '\nOrientación de la pantalla Waveshare 1.69"\n'
    printf '  1) 0 grados   (vertical, predeterminada)\n'
    printf '  2) 90 grados  (horizontal)\n'
    printf '  3) 180 grados (vertical invertida)\n'
    printf '  4) 270 grados (horizontal)\n\n'

    if [[ ! -t 0 ]]; then
        warning "No hay terminal interactiva; se seleccionará 0 grados."
        choice="1"
    else
        read -r -p "Selecciona una orientación [1]: " choice ||
            die "No se pudo leer la orientación seleccionada."
        choice="${choice:-1}"
    fi

    case "$choice" in
        1) record="$ORIENTATION_0" ;;
        2) record="$ORIENTATION_90" ;;
        3) record="$ORIENTATION_180" ;;
        4) record="$ORIENTATION_270" ;;
        *) die "Opción no válida. Ejecuta nuevamente y elige 1, 2, 3 o 4." ;;
    esac

    IFS='|' read -r ORIENTATION FIRMWARE_SOURCE FIRMWARE_SHA256 WIDTH HEIGHT \
        OFFSET_PARAMETER MADCTL <<< "$record"

    info "Orientación: ${ORIENTATION} grados | ${WIDTH} x ${HEIGHT} | MADCTL ${MADCTL}"
    info "Firmware: ${FIRMWARE_SOURCE}"
}

check_config_markers() {
    local begin_count end_count
    begin_count="$(grep -Fxc "$BEGIN_MARKER" "$CONFIG_FILE" || true)"
    end_count="$(grep -Fxc "$END_MARKER" "$CONFIG_FILE" || true)"

    [[ "$begin_count" == "$end_count" ]] ||
        die "Los marcadores del proyecto están incompletos. No se modificará config.txt."
    [[ "$begin_count" -le 1 ]] ||
        die "Hay más de un bloque del proyecto. Revisa config.txt manualmente."

    # No tomar como conflicto las líneas que estén dentro del bloque administrado.
    local outside_config="$WORK_DIR/config-without-managed-block"
    remove_managed_block "$CONFIG_FILE" "$outside_config"

    # config.txt admite directivas include. No se recorren archivos externos:
    # se rechazan para no pasar por alto un overlay duplicado en otro archivo.
    if grep -Eq '^[[:space:]]*include([[:space:]]|$)' "$outside_config"; then
        die "config.txt contiene una directiva include activa. Revisa los archivos incluidos antes de instalar; no se modificará la configuración."
    fi

    if grep -Eq '^[[:space:]]*dtoverlay[[:space:]]*=[[:space:]]*mipi-dbi-spi([,[:space:]]|$)' "$outside_config"; then
        die "Ya existe otro dtoverlay mipi-dbi-spi fuera del bloque del proyecto. Revisa config.txt antes de continuar."
    fi
}

remove_managed_block() {
    local source_file="$1"
    local destination_file="$2"

    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
        $0 == begin { if (inside) exit 20; inside=1; next }
        $0 == end   { if (!inside) exit 21; inside=0; next }
        !inside { print }
        END { if (inside) exit 22 }
    ' "$source_file" >"$destination_file" ||
        die "No se pudo procesar de forma segura el bloque administrado de config.txt."
}

check_cmdline() {
    local line_count exact_count conflict_count

    line_count="$(awk 'END { print NR+0 }' "$CMDLINE_FILE")"
    [[ "$line_count" -le 1 ]] ||
        die "$CMDLINE_FILE contiene más de una línea. No se modificará un cmdline con formato inesperado."

    exact_count="$(awk '{ for (i=1; i<=NF; i++) if ($i == "fbcon=map:1") n++ } END { print n+0 }' "$CMDLINE_FILE")"
    conflict_count="$(awk '{ for (i=1; i<=NF; i++) if ($i ~ /^fbcon=map:/ && $i != "fbcon=map:1") n++ } END { print n+0 }' "$CMDLINE_FILE")"

    [[ "$conflict_count" -eq 0 ]] ||
        die "cmdline.txt ya contiene una asignación fbcon=map: diferente de fbcon=map:1. Revisa la configuración manualmente."
    [[ "$exact_count" -le 1 ]] ||
        die "cmdline.txt contiene fbcon=map:1 repetido. Corrige los duplicados antes de instalar."
}

write_cmdline() {
    local destination="$1" original newline_count
    original="$(cat "$CMDLINE_FILE")"
    newline_count="$(wc -l <"$CMDLINE_FILE")"

    if awk '{ for (i=1; i<=NF; i++) if ($i == "fbcon=map:1") found=1 } END { exit !found }' "$CMDLINE_FILE"; then
        cp -a -- "$CMDLINE_FILE" "$destination"
        return 0
    fi

    [[ -n "$original" ]] || die "$CMDLINE_FILE está vacío; no se puede añadir fbcon de forma segura."
    printf '%s %s' "$original" "$FBCON_PARAMETER" >"$destination"
    if [[ "$newline_count" -eq 1 ]]; then
        printf '\n' >>"$destination"
    fi
    chmod --reference="$CMDLINE_FILE" "$destination"
}

validate_existing_state() {
    [[ ! -L "$STATE_DIR" ]] ||
        die "$STATE_DIR es un enlace simbólico. No se modificará el sistema."
    if [[ -e "$STATE_DIR" && ! -d "$STATE_DIR" ]]; then
        die "$STATE_DIR existe, pero no es un directorio. No se modificará el sistema."
    fi
    [[ -d "$STATE_DIR" ]] || return 0

    [[ ! -L "$STATE_DIR/config.txt.before-install" && -f "$STATE_DIR/config.txt.before-install" ]] ||
        die "El respaldo config.txt.before-install no existe o no es un archivo regular seguro."
    [[ ! -L "$STATE_DIR/cmdline.txt.before-install" && -f "$STATE_DIR/cmdline.txt.before-install" ]] ||
        die "El respaldo cmdline.txt.before-install no existe. Esta copia del estado procede de una versión anterior; desinstala esa versión antes de actualizar."
    if [[ -e "$STATE_DIR/cmdline.txt.fbcon-added" ]]; then
        [[ ! -L "$STATE_DIR/cmdline.txt.fbcon-added" && -f "$STATE_DIR/cmdline.txt.fbcon-added" && ! -e "$STATE_DIR/cmdline.txt.fbcon-preexisting" ]] ||
            die "El registro de fbcon en los respaldos es contradictorio."
    elif [[ -e "$STATE_DIR/cmdline.txt.fbcon-preexisting" ]]; then
        [[ ! -L "$STATE_DIR/cmdline.txt.fbcon-preexisting" && -f "$STATE_DIR/cmdline.txt.fbcon-preexisting" && ! -e "$STATE_DIR/cmdline.txt.fbcon-added" ]] ||
            die "El registro de fbcon en los respaldos es contradictorio."
    else
        die "Falta el registro de propiedad del parámetro fbcon en los respaldos."
    fi

    if [[ -e "$STATE_DIR/panel.bin.had-original" || -L "$STATE_DIR/panel.bin.had-original" ]]; then
        [[ ! -L "$STATE_DIR/panel.bin.had-original" && -f "$STATE_DIR/panel.bin.had-original" &&
            ! -e "$STATE_DIR/panel.bin.was-absent" && ! -L "$STATE_DIR/panel.bin.was-absent" &&
            ! -L "$STATE_DIR/panel.bin.original" && -f "$STATE_DIR/panel.bin.original" ]] ||
            die "El registro del firmware original es contradictorio o está incompleto."
    elif [[ -e "$STATE_DIR/panel.bin.was-absent" || -L "$STATE_DIR/panel.bin.was-absent" ]]; then
        [[ ! -L "$STATE_DIR/panel.bin.was-absent" && -f "$STATE_DIR/panel.bin.was-absent" &&
            ! -e "$STATE_DIR/panel.bin.original" && ! -L "$STATE_DIR/panel.bin.original" ]] ||
            die "El registro del firmware original es contradictorio."
    else
        die "No se encuentra el registro del firmware original. No se sobrescribirán respaldos."
    fi
}

prepare_initial_state() {
    # Crear el staging junto a STATE_DIR: así el rename final es atómico y no
    # depende de si /tmp y /var/lib están en sistemas de archivos distintos.
    STAGED_STATE_DIR="$(mktemp -d "${STATE_DIR}.new.XXXXXX")"
    chmod 700 "$STAGED_STATE_DIR"
    cp -a "$CONFIG_FILE" "$STAGED_STATE_DIR/config.txt.before-install"
    cp -a "$CMDLINE_FILE" "$STAGED_STATE_DIR/cmdline.txt.before-install"
    if awk '{ for (i=1; i<=NF; i++) if ($i == "fbcon=map:1") found=1 } END { exit !found }' "$CMDLINE_FILE"; then
        : >"$STAGED_STATE_DIR/cmdline.txt.fbcon-preexisting"
        chmod 600 "$STAGED_STATE_DIR/cmdline.txt.fbcon-preexisting"
    else
        : >"$STAGED_STATE_DIR/cmdline.txt.fbcon-added"
        chmod 600 "$STAGED_STATE_DIR/cmdline.txt.fbcon-added"
    fi

    if [[ -e "$FIRMWARE_TARGET" ]]; then
        cp -a "$FIRMWARE_TARGET" "$STAGED_STATE_DIR/panel.bin.original"
        : >"$STAGED_STATE_DIR/panel.bin.had-original"
    else
        : >"$STAGED_STATE_DIR/panel.bin.was-absent"
    fi
    # El directorio 0700 protege los respaldos sin alterar sus metadatos originales.
    # Sólo los pequeños archivos indicadores necesitan permisos 0600.
    if [[ -f "$STAGED_STATE_DIR/panel.bin.had-original" ]]; then
        chmod 600 "$STAGED_STATE_DIR/panel.bin.had-original"
    fi
    if [[ -f "$STAGED_STATE_DIR/panel.bin.was-absent" ]]; then
        chmod 600 "$STAGED_STATE_DIR/panel.bin.was-absent"
    fi

    # Publicar los respaldos completos con un rename dentro del mismo filesystem.
    mv -- "$STAGED_STATE_DIR" "$STATE_DIR"
    STAGED_STATE_DIR=""
    STATE_CREATED=1
}

write_config() {
    local destination="$1"
    local base_config="$2"

    remove_managed_block "$base_config" "$destination"
    {
        # El archivo generado por awk termina en newline; no añadir separadores
        # extra evita acumular líneas vacías en cada reinstalación.
        printf '%s\n' "$BEGIN_MARKER"
        printf '# Waveshare 1.69" ST7789V2 - orientación %s grados\n' "$ORIENTATION"
        printf '[all]\n'
        printf 'dtparam=spi=on\n'
        printf 'dtoverlay=%s,%s,speed=%s,%s\n' "$DISPLAY_OVERLAY" "$SPI_DEVICE" "$SPI_SPEED_HZ" \
            "$([[ "$SPI_WRITE_ONLY" == "1" ]] && printf 'write-only')"
        printf 'dtparam=width=%s,height=%s\n' "$WIDTH" "$HEIGHT"
        printf 'dtparam=reset-gpio=%s,dc-gpio=%s\n' "$GPIO_RESET" "$GPIO_DC"
        printf 'dtparam=backlight-gpio=%s\n' "$GPIO_BACKLIGHT"
        printf 'dtparam=%s\n' "$OFFSET_PARAMETER"
        printf '%s\n' "$END_MARKER"
    } >>"$destination"
}

main() {
    local firmware_url new_config actual_size actual_hash

    require_command awk
    require_command chmod
    require_command cp
    require_command cat
    require_command dpkg
    require_command grep
    require_command install
    require_command mktemp
    require_command mv
    require_command rm
    require_command sha256sum
    require_command tr
    require_command wc
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        die "Se necesita curl o wget para descargar el firmware."
    fi

    printf '\nWaveshare 1.69" ST7789V2 - Instalador para Raspberry Pi OS Trixie\n\n'
    check_platform
    select_orientation

    WORK_DIR="$(mktemp -d /tmp/${PROJECT}.XXXXXX)"
    firmware_url="${REPO_RAW}/firmware/${FIRMWARE_SOURCE}"

    info "Descargando firmware desde GitHub..."
    download_file "$firmware_url" "$WORK_DIR/panel.bin"
    [[ -s "$WORK_DIR/panel.bin" ]] || die "El firmware descargado está vacío."
    actual_size="$(wc -c <"$WORK_DIR/panel.bin")"
    [[ "$actual_size" -eq "$PANEL_FIRMWARE_SIZE" ]] ||
        die "Tamaño de firmware incorrecto: ${actual_size} bytes; se esperaban ${PANEL_FIRMWARE_SIZE}."
    actual_hash="$(sha256sum "$WORK_DIR/panel.bin" | awk '{print $1}')"
    [[ "$actual_hash" == "$FIRMWARE_SHA256" ]] ||
        die "SHA256 incorrecto para ${FIRMWARE_SOURCE}. Descarga rechazada."
    info "Tamaño y SHA256 del firmware verificados."

    [[ ! -L "$CONFIG_FILE" && ! -L "$FIRMWARE_TARGET" ]] ||
        die "config.txt o panel.bin es un enlace simbólico. Revisa las rutas antes de continuar."
    if [[ -e "$FIRMWARE_TARGET" && ! -f "$FIRMWARE_TARGET" ]]; then
        die "$FIRMWARE_TARGET existe, pero no es un archivo regular. No se modificará."
    fi

    check_config_markers
    check_cmdline
    validate_existing_state

    # Copias temporales para poder revertir una instalación que falle a mitad.
    cp -a "$CONFIG_FILE" "$WORK_DIR/config.txt.before-transaction"
    cp -a "$CMDLINE_FILE" "$WORK_DIR/cmdline.txt.before-transaction"
    if [[ -e "$FIRMWARE_TARGET" ]]; then
        cp -a "$FIRMWARE_TARGET" "$WORK_DIR/panel.bin.before-transaction"
        HAD_FIRMWARE=1
    fi

    if [[ ! -d "$STATE_DIR" ]]; then
        prepare_initial_state
    fi

    new_config="$WORK_DIR/config.txt.new"
    write_config "$new_config" "$CONFIG_FILE"
    write_cmdline "$WORK_DIR/cmdline.txt.new"

    # Desde aquí, cualquier error debe disparar la restauración.
    TRANSACTION_STARTED=1
    install -m 644 "$new_config" "$CONFIG_FILE"
    install -m 644 "$WORK_DIR/cmdline.txt.new" "$CMDLINE_FILE"
    install -m 644 "$WORK_DIR/panel.bin" "$FIRMWARE_TARGET"
    TRANSACTION_STARTED=0
    INSTALL_SUCCEEDED=1

    info "Firmware instalado en $FIRMWARE_TARGET"
    info "Configuración añadida a $CONFIG_FILE"
    info "Parámetro $FBCON_PARAMETER configurado en $CMDLINE_FILE"
    printf '\n'
    warning "La instalación está preparada. Reinicia la Raspberry Pi para activar la pantalla:"
    printf '  sudo reboot\n\n'
    info "El respaldo inicial se conserva en $STATE_DIR"
    info "La configuración administrada está delimitada por los marcadores del proyecto."
}

main "$@"
