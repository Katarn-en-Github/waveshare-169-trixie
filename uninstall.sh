#!/usr/bin/env bash
#
# waveshare-169-trixie - Desinstalador de Waveshare 1.69" ST7789V2
# Restaura los archivos originales guardados por install.sh.
# No elimina paquetes ni modifica otros archivos del sistema.

set -Eeuo pipefail

readonly PROJECT="waveshare-169-trixie"
readonly CONFIG_FILE="/boot/firmware/config.txt"
readonly CMDLINE_FILE="/boot/firmware/cmdline.txt"
readonly FBCON_PARAMETER="fbcon=map:1"
readonly FIRMWARE_TARGET="/lib/firmware/panel.bin"
readonly STATE_DIR="/var/lib/${PROJECT}"
readonly BEGIN_MARKER="# BEGIN ${PROJECT}"
readonly END_MARKER="# END ${PROJECT}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { printf '  %b[INFO]%b %s\n' "$GREEN" "$NC" "$*"; }
warning() { printf '  %b[AVISO]%b %s\n' "$YELLOW" "$NC" "$*"; }
error()   { printf '  %b[ERROR]%b %s\n' "$RED" "$NC" "$*" >&2; }
die()     { error "$*"; exit 1; }

WORK_DIR=""
TRANSACTION_STARTED=0
ROLLING_BACK=0
ROLLBACK_FAILED=0
KEEP_WORK_DIR=0
HAD_CURRENT_FIRMWARE=0
ORIGINAL_FBCON_ADDED=0

cleanup() {
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
    error "La desinstalación no se completó. Intentando restaurar el estado anterior..."

    if [[ -f "$WORK_DIR/config.txt.before-uninstall" ]]; then
        cp -a -- "$WORK_DIR/config.txt.before-uninstall" "$CONFIG_FILE" || ROLLBACK_FAILED=1
    else
        ROLLBACK_FAILED=1
    fi

    if [[ -f "$WORK_DIR/cmdline.txt.before-uninstall" ]]; then
        cp -a -- "$WORK_DIR/cmdline.txt.before-uninstall" "$CMDLINE_FILE" || ROLLBACK_FAILED=1
    else
        ROLLBACK_FAILED=1
    fi

    if (( HAD_CURRENT_FIRMWARE == 1 )); then
        if [[ -f "$WORK_DIR/panel.bin.before-uninstall" ]]; then
            cp -a -- "$WORK_DIR/panel.bin.before-uninstall" "$FIRMWARE_TARGET" || ROLLBACK_FAILED=1
        else
            ROLLBACK_FAILED=1
        fi
    else
        rm -f -- "$FIRMWARE_TARGET" || ROLLBACK_FAILED=1
    fi

    TRANSACTION_STARTED=0
    if (( ROLLBACK_FAILED == 1 )); then
        KEEP_WORK_DIR=1
        error "ATENCIÓN: la recuperación tampoco pudo completarse por completo."
        error "Se conservaron las copias temporales en: $WORK_DIR"
        error "No borres ese directorio. Código de salida original: $status"
    else
        error "Se restauró el estado anterior a esta desinstalación. Código de salida: $status"
        error "Los respaldos originales siguen en $STATE_DIR"
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

validate_state() {
    [[ -d "$STATE_DIR" && ! -L "$STATE_DIR" ]] ||
        die "No existe un directorio de respaldos válido en $STATE_DIR. No se modificará el sistema."

    [[ ! -L "$STATE_DIR/config.txt.before-install" && -f "$STATE_DIR/config.txt.before-install" ]] ||
        die "Falta el respaldo original de config.txt o no es un archivo regular seguro."

    [[ ! -L "$STATE_DIR/cmdline.txt.before-install" && -f "$STATE_DIR/cmdline.txt.before-install" ]] ||
        die "Falta el respaldo original de cmdline.txt. Este respaldo pertenece a una versión anterior del instalador; no se modificará el sistema."

    if [[ -e "$STATE_DIR/cmdline.txt.fbcon-added" || -L "$STATE_DIR/cmdline.txt.fbcon-added" ]]; then
        [[ ! -L "$STATE_DIR/cmdline.txt.fbcon-added" && -f "$STATE_DIR/cmdline.txt.fbcon-added" &&
           ! -e "$STATE_DIR/cmdline.txt.fbcon-preexisting" && ! -L "$STATE_DIR/cmdline.txt.fbcon-preexisting" ]] ||
            die "El registro de propiedad de fbcon es contradictorio o inseguro."
        ORIGINAL_FBCON_ADDED=1
    elif [[ -e "$STATE_DIR/cmdline.txt.fbcon-preexisting" || -L "$STATE_DIR/cmdline.txt.fbcon-preexisting" ]]; then
        [[ ! -L "$STATE_DIR/cmdline.txt.fbcon-preexisting" && -f "$STATE_DIR/cmdline.txt.fbcon-preexisting" &&
           ! -e "$STATE_DIR/cmdline.txt.fbcon-added" && ! -L "$STATE_DIR/cmdline.txt.fbcon-added" ]] ||
            die "El registro de propiedad de fbcon es contradictorio o inseguro."
        ORIGINAL_FBCON_ADDED=0
    else
        die "Falta el registro que indica si fbcon=map:1 fue añadido por el instalador o ya existía."
    fi

    if [[ -e "$STATE_DIR/panel.bin.had-original" || -L "$STATE_DIR/panel.bin.had-original" ]]; then
        [[ ! -L "$STATE_DIR/panel.bin.had-original" && -f "$STATE_DIR/panel.bin.had-original" &&
           ! -e "$STATE_DIR/panel.bin.was-absent" && ! -L "$STATE_DIR/panel.bin.was-absent" &&
           ! -L "$STATE_DIR/panel.bin.original" && -f "$STATE_DIR/panel.bin.original" ]] ||
            die "El respaldo del firmware original es contradictorio o está incompleto."
        ORIGINAL_FIRMWARE_PRESENT=1
    elif [[ -e "$STATE_DIR/panel.bin.was-absent" || -L "$STATE_DIR/panel.bin.was-absent" ]]; then
        [[ ! -L "$STATE_DIR/panel.bin.was-absent" && -f "$STATE_DIR/panel.bin.was-absent" &&
           ! -e "$STATE_DIR/panel.bin.original" && ! -L "$STATE_DIR/panel.bin.original" ]] ||
            die "El registro de ausencia del firmware original es contradictorio."
        ORIGINAL_FIRMWARE_PRESENT=0
    else
        die "No se encuentra el registro del firmware original. No se modificará el sistema."
    fi
}

remove_managed_block() {
    local source_file="$1"
    local destination_file="$2"

    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
        $0 == begin { if (inside) exit 20; inside=1; begin_count++; next }
        $0 == end   { if (!inside) exit 21; inside=0; end_count++; next }
        !inside { print }
        END {
            if (inside || begin_count != 1 || end_count != 1) exit 22
        }
    ' "$source_file" >"$destination_file" ||
        die "El bloque administrado de config.txt está mal formado. No se modificará el sistema."
}

validate_current_installation() {
    [[ -f "$CONFIG_FILE" && ! -L "$CONFIG_FILE" ]] ||
        die "$CONFIG_FILE no existe, no es un archivo regular o es un enlace simbólico."
    [[ ! -L "$FIRMWARE_TARGET" ]] ||
        die "$FIRMWARE_TARGET es un enlace simbólico. No se modificará."
    if [[ -e "$FIRMWARE_TARGET" && ! -f "$FIRMWARE_TARGET" ]]; then
        die "$FIRMWARE_TARGET existe, pero no es un archivo regular."
    fi

    remove_managed_block "$CONFIG_FILE" "$WORK_DIR/config.txt.without-managed-block"

    # La comparación evita sobrescribir cambios hechos por el usuario después
    # de instalar Waveshare. Sólo se permite retirar el bloque del proyecto.
    if ! cmp -s -- "$STATE_DIR/config.txt.before-install" "$WORK_DIR/config.txt.without-managed-block"; then
        die "config.txt contiene cambios ajenos al bloque Waveshare desde la instalación. No se modificó ningún archivo. Revisa o respalda esos cambios antes de desinstalar."
    fi

    [[ -f "$CMDLINE_FILE" && ! -L "$CMDLINE_FILE" ]] ||
        die "$CMDLINE_FILE no existe, no es un archivo regular o es un enlace simbólico."
    local line_count
    line_count="$(awk 'END { print NR+0 }' "$CMDLINE_FILE")"
    [[ "$line_count" -le 1 ]] ||
        die "$CMDLINE_FILE contiene más de una línea. No se modificará."

    # Construir la versión esperada: el cmdline original, más fbcon sólo si
    # el instalador fue quien lo añadió. Cualquier otro cambio posterior
    # provoca una parada segura en lugar de sobrescribirlo.
    cp -a -- "$STATE_DIR/cmdline.txt.before-install" "$WORK_DIR/cmdline.txt.expected"
    if (( ORIGINAL_FBCON_ADDED == 1 )); then
        local original_lines
        original_lines="$(awk 'END { print NR+0 }' "$WORK_DIR/cmdline.txt.expected")"
        [[ "$original_lines" -le 1 ]] ||
            die "El respaldo original de cmdline.txt tiene un formato inesperado."
        if [[ "$original_lines" -eq 1 ]]; then
            sed -i "s/$/ $FBCON_PARAMETER/" "$WORK_DIR/cmdline.txt.expected"
        else
            printf ' %s' "$FBCON_PARAMETER" >>"$WORK_DIR/cmdline.txt.expected"
        fi
    fi

    if ! cmp -s -- "$WORK_DIR/cmdline.txt.expected" "$CMDLINE_FILE"; then
        die "cmdline.txt fue modificado después de la instalación o no coincide con el parámetro administrado. No se modificó ningún archivo. Revisa los cambios antes de desinstalar."
    fi
}

main() {
    require_command awk
    require_command chmod
    require_command cmp
    require_command cp
    require_command grep
    require_command mktemp
    require_command rm
    require_command sed

    [[ $EUID -eq 0 ]] || die "Ejecuta el desinstalador con sudo: sudo bash uninstall.sh"
    [[ -d /boot/firmware && -d /lib/firmware ]] ||
        die "No se encuentran las rutas esperadas de Raspberry Pi OS. No se modificará el sistema."

    printf '\nWaveshare 1.69\" ST7789V2 - Desinstalador\n\n'
    validate_state

    WORK_DIR="$(mktemp -d /tmp/${PROJECT}-uninstall.XXXXXX)"
    chmod 700 "$WORK_DIR"
    validate_current_installation

    # Copias de seguridad del estado actual para poder revertir una desinstalación fallida.
    cp -a -- "$CONFIG_FILE" "$WORK_DIR/config.txt.before-uninstall"
    cp -a -- "$CMDLINE_FILE" "$WORK_DIR/cmdline.txt.before-uninstall"
    if [[ -e "$FIRMWARE_TARGET" ]]; then
        cp -a -- "$FIRMWARE_TARGET" "$WORK_DIR/panel.bin.before-uninstall"
        HAD_CURRENT_FIRMWARE=1
    fi

    # Comenzar la transacción antes del primer cambio en el sistema.
    TRANSACTION_STARTED=1

    if (( ORIGINAL_FIRMWARE_PRESENT == 1 )); then
        cp -a -- "$STATE_DIR/panel.bin.original" "$FIRMWARE_TARGET"
        info "Firmware panel.bin original restaurado."
    else
        rm -f -- "$FIRMWARE_TARGET"
        info "panel.bin eliminado: no existía antes de la instalación."
    fi

    cp -a -- "$STATE_DIR/config.txt.before-install" "$CONFIG_FILE"
    info "config.txt original restaurado."

    cp -a -- "$STATE_DIR/cmdline.txt.before-install" "$CMDLINE_FILE"
    info "cmdline.txt original restaurado."

    # La restauración ya terminó. Desde aquí, un fallo al borrar el estado
    # no debe provocar que se revierta una desinstalación correcta.
    TRANSACTION_STARTED=0

    if rm -rf -- "$STATE_DIR"; then
        info "Respaldos del proyecto eliminados."
    else
        warning "El sistema fue restaurado, pero no se pudieron eliminar los respaldos: $STATE_DIR"
    fi

    printf '\n'
    info "Desinstalación completada. Se restauraron config.txt, cmdline.txt y el firmware original."
    info "Reinicia la Raspberry Pi para aplicar la restauración:"
    printf '  sudo reboot\n\n'
}

main "$@"
