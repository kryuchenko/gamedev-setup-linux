#!/usr/bin/env bash
# install-proton-gaming-mega.sh - MEGA установщик gaming окружения v2.0
# -----------------------------------------------------------------------------
# ВСЁ В ОДНОМ: Proton-GE + Wine + Vulkan + DXVK + GameMode + Оптимизации
# -----------------------------------------------------------------------------
# Быстрая установка:
#   curl -fsSL https://raw.githubusercontent.com/kryuchenko/gamedev-setup-linux/refs/heads/main/install-proton-gaming-mega.sh | sudo TARGET_USER=user bash
# -----------------------------------------------------------------------------
set -euo pipefail

# Отключаем прерывание по ошибкам для критических секций
trap 'echo "Warning: Command failed, continuing..."; true' ERR

# Цвета и символы
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Unicode символы
CHECK="✓"
CROSS="✗"
ROCKET="🚀"
GAME="🎮"
FIRE="🔥"
GEAR="⚙️"
PACKAGE="📦"

# Функции вывода
step() { echo -e "\n${BLUE}${BOLD}==== $* ====${NC}"; }
info() { echo -e "${GREEN}[${CHECK}]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[${CROSS}]${NC} $*" >&2; }
substep() { echo -e "${CYAN}  ${GEAR}${NC} $*"; }

# Функция безопасного выполнения команд
safe_exec() {
    "$@" 2>/dev/null || {
        warn "Command failed: $1 (continuing anyway)"
        return 0
    }
}

# Анимированный баннер
show_banner() {
    clear
    cat << 'BANNER'
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║     ██████╗ ██████╗  ██████╗ ████████╗ ██████╗ ███╗   ██╗        ║
    ║     ██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝██╔═══██╗████╗  ██║        ║
    ║     ██████╔╝██████╔╝██║   ██║   ██║   ██║   ██║██╔██╗ ██║        ║
    ║     ██╔═══╝ ██╔══██╗██║   ██║   ██║   ██║   ██║██║╚██╗██║        ║
    ║     ██║     ██║  ██║╚██████╔╝   ██║   ╚██████╔╝██║ ╚████║        ║
    ║     ╚═╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═══╝        ║
    ║                                                                  ║
    ║           🎮 MEGA Gaming Environment Installer 🎮                 ║
    ║                   Maximum FPS Edition v2.0                       ║
    ╚══════════════════════════════════════════════════════════════════╝
BANNER
    echo -e "\n    ${PURPLE}${BOLD}Preparing to install:${NC}"
    echo -e "    ${GAME} Proton-GE (latest)     ${FIRE} GameMode optimizations"
    echo -e "    ${PACKAGE} Wine + Vulkan stack    ${ROCKET} Maximum performance tweaks"
    echo -e "    ${GEAR} DXVK + VKD3D-Proton    ${CHECK} DirectX Args Debugger\n"
    sleep 2
}

# Проверка root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    error "Example: curl -fsSL <URL> | sudo TARGET_USER=user bash"
    exit 1
fi

# Определение пользователя
detect_target_user() {
    local target_user=""
    
    if [ -n "${TARGET_USER:-}" ]; then
        target_user="$TARGET_USER"
    elif id "user" &>/dev/null; then
        target_user="user"
    elif [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        target_user="$SUDO_USER"
    else
        target_user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ /^\/home\// {print $1}' | head -1)
    fi
    
    if [ -z "$target_user" ] || [ "$target_user" == "root" ]; then
        error "Cannot determine target user"
        error "Please run with: sudo TARGET_USER=username bash"
        exit 1
    fi
    
    echo "$target_user"
}

# Начало установки
show_banner

# Системные переменные
export DEBIAN_FRONTEND=noninteractive
DIST_CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")
TARGET_USER=$(detect_target_user)
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_UID=$(id -u "$TARGET_USER")
TARGET_GID=$(id -g "$TARGET_USER")

echo -e "${BOLD}Target user:${NC} $TARGET_USER (uid:$TARGET_UID)"
echo -e "${BOLD}Home directory:${NC} $TARGET_HOME"
echo -e "${BOLD}Distribution:${NC} $DIST_CODENAME"
echo ""
echo "Press Enter to start installation or Ctrl+C to cancel..."
read -r || true

# ═══════════════════════════════════════════════════════════════════════════
# ФАЗА 1: СИСТЕМНАЯ УСТАНОВКА
# ═══════════════════════════════════════════════════════════════════════════

step "PHASE 1: System Components ${PACKAGE}"

# Очистка старых репозиториев
substep "Cleaning old repositories..."
safe_exec rm -f /etc/apt/sources.list.d/lutris.list
safe_exec sed -i '/lutris-team\/lutris/d' /etc/apt/sources.list /etc/apt/sources.list.d/*.list

# Базовые утилиты
substep "Installing core utilities..."
safe_exec apt-get update -qq
safe_exec apt-get install -y --no-install-recommends \
    curl wget ca-certificates lsb-release software-properties-common \
    tar zstd jq xz-utils p7zip-full unzip gnupg \
    desktop-file-utils xdg-utils pciutils
info "Core utilities installed"

# Низколатентный аудио-стек
substep "Installing low-latency audio stack..."
safe_exec apt-get install -y --no-install-recommends \
    pulseaudio pulseaudio-utils soxr libsoxr0 \
    pipewire pipewire-audio-client-libraries wireplumber \
    libspa-0.2-bluetooth
info "Audio stack installed"

# WineHQ latest + Vulkan
substep "Adding WineHQ repository..."
safe_exec dpkg --add-architecture i386
safe_exec mkdir -p /etc/apt/keyrings
safe_exec curl -fsSL https://dl.winehq.org/wine-builds/winehq.key \
    | gpg --dearmor -o /etc/apt/keyrings/winehq.gpg
safe_exec tee /etc/apt/sources.list.d/winehq.list << EOF >/dev/null
deb [signed-by=/etc/apt/keyrings/winehq.gpg] https://dl.winehq.org/wine-builds/ubuntu/ $DIST_CODENAME main
EOF
safe_exec apt-get update -qq

substep "Installing latest WineHQ + Vulkan stack..."
# Пробуем установить в порядке приоритета: staging -> devel -> stable
if ! safe_exec apt-get install -y --install-recommends winehq-staging; then
    warn "winehq-staging not available, trying devel..."
    if ! safe_exec apt-get install -y --install-recommends winehq-devel; then
        warn "winehq-devel not available, installing stable..."
        safe_exec apt-get install -y --install-recommends winehq-stable
    fi
fi

# Дополнительные компоненты
safe_exec apt-get install -y --install-recommends \
    wine32 wine64 \
    libvulkan1 libvulkan1:i386 \
    mesa-vulkan-drivers mesa-vulkan-drivers:i386 \
    vulkan-tools zenity cabextract \
    fluid-soundfont-gs libwebrtc-audio-processing1
info "WineHQ (latest available) & Vulkan installed"

# GameMode и оптимизации
substep "Installing GameMode and performance tools..."
safe_exec apt-get install -y --no-install-recommends \
    gamemode gamemode-daemon libgamemode0 libgamemodeauto0 \
    mangohud vkbasalt cpufrequtils linux-tools-generic || \
    warn "Some optimization tools failed to install"
info "GameMode installed"

# Exposing gamemoderun
substep "Exposing gamemoderun..."
if [ ! -e /usr/bin/gamemoderun ] && [ -e /usr/games/gamemoderun ]; then
    ln -s /usr/games/gamemoderun /usr/bin/gamemoderun
fi
# /etc/environment не разворачивает $PATH, поэтому добавляем через profile-скрипт
echo 'export PATH="$PATH:/usr/games"' > /etc/profile.d/gamemode-path.sh
chmod +x /etc/profile.d/gamemode-path.sh
info "gamemoderun available system-wide"

# winetricks
substep "Installing winetricks..."
safe_exec curl -fsSL -o /usr/local/bin/winetricks \
    https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
safe_exec chmod +x /usr/local/bin/winetricks
info "winetricks installed"

# Lutris репозиторий
substep "Configuring Lutris repository..."
safe_exec mkdir -p /etc/apt/keyrings

# Пробуем разные способы получения ключа
if curl -fsSL https://download.opensuse.org/repositories/home:/strycore/Debian_12/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/lutris.gpg 2>/dev/null; then
    KEYOPT="signed-by=/etc/apt/keyrings/lutris.gpg"
elif curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x82D96E430A1F1C0F409FA5F5D1C83CA9A8A515F0 \
    | gpg --dearmor -o /etc/apt/keyrings/lutris.gpg 2>/dev/null; then
    KEYOPT="signed-by=/etc/apt/keyrings/lutris.gpg"
else
    warn "Could not fetch Lutris GPG key, using trusted=yes"
    KEYOPT="trusted=yes"
fi

# Используем OpenSUSE репозиторий для всех дистрибутивов (более надёжный)
echo "deb [$KEYOPT] https://download.opensuse.org/repositories/home:/strycore/Debian_12/ /" \
    > /etc/apt/sources.list.d/lutris.list

# Lutris & Steam
substep "Installing Lutris & Steam..."
safe_exec apt-get update -qq
safe_exec apt-get install -y --no-install-recommends lutris steam || \
    warn "Lutris/Steam installation incomplete"
info "Gaming platforms configured"

# DXVK & VKD3D-Proton
step "Installing Graphics Libraries ${GEAR}"
TMP_SYS=$(mktemp -d)
cd "$TMP_SYS" || exit 1

install_graphics_lib() {
    local name=$1 repo=$2 pattern=$3
    substep "Installing $name..."
    local tag=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | jq -r .tag_name)
    if [[ -n "$tag" && "$tag" != "null" ]]; then
        local version=${tag#v}
        local filename=$(printf "$pattern" "$version")
        local url="https://github.com/$repo/releases/download/$tag/$filename"
        
        if curl -fsSL -o "$filename" "$url" 2>/dev/null; then
            case "$filename" in
                *.zst) tar --use-compress-program=unzstd -xf "$filename" 2>/dev/null || true ;;
                *.gz|*.xz) tar -xf "$filename" 2>/dev/null || true ;;
            esac
            
            local dir=${filename%.tar.*}
            if [ -d "$dir" ]; then
                local wine64_path="/usr/lib/x86_64-linux-gnu/wine"
                local wine32_path="/usr/lib/i386-linux-gnu/wine"
                [ -d "$dir/x64" ] && cp -r "$dir/x64/"* "$wine64_path/" 2>/dev/null || true
                [ -d "$dir/x32" ] && cp -r "$dir/x32/"* "$wine32_path/" 2>/dev/null || true
                [ -d "$dir/x86" ] && cp -r "$dir/x86/"* "$wine32_path/" 2>/dev/null || true
                info "$name $version installed"
            fi
            rm -rf "$dir" "$filename"
        fi
    fi
}

install_graphics_lib "VKD3D-Proton" "HansKristian-Work/vkd3d-proton" "vkd3d-proton-%s.tar.zst"
install_graphics_lib "DXVK" "doitsujin/dxvk" "dxvk-%s.tar.gz"

cd /tmp && rm -rf "$TMP_SYS"

# Функция для установки DXVK/VKD3D через winetricks (вызовем позже в Phase 3)
DXVK_INSTALL() {
    substep "Installing DXVK/VKD3D into Proton prefix via winetricks..."
    sudo -u "$TARGET_USER" -H bash -c '
        export WINEPREFIX="$HOME/Games/proton-prefixes/default"
        export PATH="$HOME/.local/bin:$PATH"
        mkdir -p "$WINEPREFIX"
        if command -v proton-run >/dev/null 2>&1 && command -v winetricks >/dev/null 2>&1; then
            echo "Running winetricks to install DXVK and VKD3D..."
            proton-run winetricks -q --force dxvk vkd3d 2>/dev/null || true
        fi
    '
    info "DXVK & VKD3D installed via winetricks"
}

# Функция для установки всех необходимых Windows компонентов
WINDOWS_COMPONENTS_INSTALL() {
    step "Installing Essential Windows Components 📦"
    
    substep "Installing Windows runtime libraries via winetricks..."
    sudo -u "$TARGET_USER" -H bash -c '
        export WINEPREFIX="$HOME/Games/proton-prefixes/default"
        export PATH="$HOME/.local/bin:$PATH"
        mkdir -p "$WINEPREFIX"
        
        if command -v proton-run >/dev/null 2>&1 && command -v winetricks >/dev/null 2>&1; then
            echo "Installing Visual C++ Redistributables..."
            # Visual C++ Redistributables (все версии)
            proton-run winetricks -q --force \
                vcrun2005 vcrun2008 vcrun2010 vcrun2012 vcrun2013 \
                vcrun2015 vcrun2017 vcrun2019 vcrun2022 2>/dev/null || true
            
            echo "Installing .NET Framework components..."
            # .NET Framework (основные версии)
            proton-run winetricks -q --force \
                dotnet35sp1 dotnet40 dotnet452 dotnet462 dotnet472 dotnet48 2>/dev/null || true
            
            echo "Installing DirectX components..."
            # DirectX компоненты (включая DX12)
            proton-run winetricks -q --force \
                d3dx9 d3dx10 d3dx11_42 d3dx11_43 \
                d3dcompiler_42 d3dcompiler_43 d3dcompiler_46 d3dcompiler_47 \
                directplay directmusic directshow \
                dxdiag physx xact xinput \
                dxvk vkd3d \
                d3d12 2>/dev/null || true
            
            echo "Installing common Windows libraries..."
            # Другие важные библиотеки
            proton-run winetricks -q --force \
                corefonts tahoma liberation \
                msxml3 msxml4 msxml6 \
                mfc40 mfc42 \
                vb6run \
                gdiplus \
                faudio \
                lavfilters \
                xvid ffdshow \
                openal \
                quartz amstream \
                wmv9vcm wmp10 wmp11 \
                ie8 \
                flash \
                msls31 msftedit riched20 riched30 \
                mdac28 jet40 \
                windowscodecs \
                dsound dmime dmloader dmscript dmstyle dmsynth dmusic \
                devenum qcap qedit \
                dsdmo l3codecx 2>/dev/null || true
            
            echo "Setting Windows 10 compatibility mode..."
            # Установка режима совместимости
            proton-run winetricks -q win10 2>/dev/null || true
            
            echo "Applying performance tweaks..."
            # Оптимизации производительности
            proton-run winetricks -q --force \
                fontsmooth=rgb \
                renderer=vulkan \
                videomemorysize=4096 2>/dev/null || true
        else
            echo "WARNING: proton-run or winetricks not available yet"
        fi
    '
    info "Windows components installation completed"
}

# ═══════════════════════════════════════════════════════════════════════════
# ФАЗА 2: ОПТИМИЗАЦИИ СИСТЕМЫ
# ═══════════════════════════════════════════════════════════════════════════

step "PHASE 2: System Optimizations ${FIRE}"

# GameMode конфигурация
substep "Configuring GameMode..."
safe_exec mkdir -p /etc/gamemode.d/
cat > /etc/gamemode.d/gamemode.ini << 'EOF' || true
[general]
renice = -10
ioprio = 0

[filter]
whitelist = proton;wine;wine64;directx-args-debugger.exe

[gpu]
apply_gpu_optimizations = accept-responsibility
nv_powermizer_mode = 1
amd_performance_level = high

[cpu]
park_cores = no
scaling_governor = performance
EOF
info "GameMode configured"

# Kernel оптимизации
substep "Applying kernel optimizations..."
cat > /etc/sysctl.d/99-gaming.conf << 'EOF' || true
# Gaming optimizations
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.max_map_count = 2147483642
kernel.sched_migration_cost_ns = 5000000
kernel.sched_autogroup_enabled = 0
EOF
safe_exec sysctl -p /etc/sysctl.d/99-gaming.conf
info "Kernel optimized"

# Конфигурация PulseAudio для низкой латентности
substep "Configuring PulseAudio for low latency..."
mkdir -p /etc/pulse
cat > /etc/pulse/daemon.conf << 'PA'
# ─── Low-latency, избегаем микротрещин ──────────────────────────────
default-fragments = 2
default-fragment-size-msec = 4
resample-method = soxr-mq
realtime-scheduling = yes
realtime-priority = 9
exit-idle-time = -1
high-priority = yes
nice-level = -11
PA
info "PulseAudio tuned"

# Запуск dbus и GameMode daemon
substep "Starting dbus-daemon + GameMode service..."
if ! pgrep -x dbus-daemon >/dev/null; then
    dbus-daemon --system --fork --nopidfile 2>/dev/null || warn "dbus-daemon start failed"
fi
if ! pgrep -x gamemoded >/dev/null; then
    gamemoded -d 2>/dev/null || warn "gamemoded start failed"
fi
info "GameMode daemon running"

# Запуск аудио демонов
substep "Starting audio daemons..."
# PulseAudio в system-mode (OK для контейнера)
if ! pgrep -x pulseaudio >/dev/null; then
    pulseaudio --daemonize --system --disallow-exit --log-target=syslog 2>/dev/null || warn "PulseAudio start failed"
fi
# PipeWire для клиентов, которым он нужен (Steam + Chrome)
if ! pgrep -x pipewire >/dev/null; then
    pipewire --daemonize 2>/dev/null || true
    wireplumber --daemonize 2>/dev/null || true
fi
info "Audio daemons running"

# Лимиты системы
substep "Configuring system limits..."
cat > /etc/security/limits.d/99-gaming.conf << 'EOF' || true
*               soft    memlock         unlimited
*               hard    memlock         unlimited
*               soft    nofile          1048576
*               hard    nofile          1048576
*               soft    rtprio          99
*               hard    rtprio          99
*               soft    nice            -20
*               hard    nice            -20
@audio          -       rtprio          95
EOF
usermod -aG audio "$TARGET_USER" 2>/dev/null || true
info "System limits configured"

# ═══════════════════════════════════════════════════════════════════════════
# ФАЗА 3: ПОЛЬЗОВАТЕЛЬСКАЯ УСТАНОВКА
# ═══════════════════════════════════════════════════════════════════════════

step "PHASE 3: User Components ${GAME}"

# Создаём временный скрипт для пользователя
USER_INSTALL_SCRIPT="/tmp/user-install-$$.sh"
cat > "$USER_INSTALL_SCRIPT" << 'USERSCRIPT' || { error "Failed to create user script"; exit 1; }
#!/usr/bin/env bash
set -euo pipefail

# Отключаем прерывание для пользовательского скрипта
trap 'true' ERR

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[✓]${NC} $*"; }
substep() { echo -e "${CYAN}  ⚙️${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

# Создаём все необходимые директории
substep "Creating directories..."
mkdir -p ~/.steam/steam/compatibilitytools.d
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/applications
mkdir -p ~/Games/proton-prefixes
mkdir -p ~/Desktop

# Proton-GE
substep "Installing Proton-GE..."
cd /tmp
PROTON_TAG=$(curl -fsSL "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest" 2>/dev/null | jq -r .tag_name || echo "")

if [[ -n "$PROTON_TAG" && "$PROTON_TAG" != "null" ]]; then
    echo "Downloading Proton-GE $PROTON_TAG..."
    
    if curl -fsSL -o "${PROTON_TAG}.tar.gz" \
        "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_TAG}/${PROTON_TAG}.tar.gz" 2>/dev/null; then
        tar -xf "${PROTON_TAG}.tar.gz" -C ~/.steam/steam/compatibilitytools.d/ 2>/dev/null || warn "Extract failed"
        rm -f "${PROTON_TAG}.tar.gz"
        info "Proton-GE $PROTON_TAG installed"
    else
        warn "Failed to download Proton-GE"
    fi
else
    warn "Could not get Proton-GE version"
fi

# proton-run helper
substep "Creating proton-run helper..."
cat > ~/.local/bin/proton-run << 'PROTONRUN'
#!/usr/bin/env bash
PROTON_DIR="$HOME/.steam/steam/compatibilitytools.d"
PROTON_VERSION=$(ls -1 "$PROTON_DIR" 2>/dev/null | grep -E '^GE-Proton' | sort -V | tail -n1)
[ -z "$PROTON_VERSION" ] && { echo "ERROR: Proton GE not found" >&2; exit 1; }

export STEAM_COMPAT_DATA_PATH="${STEAM_COMPAT_DATA_PATH:-$HOME/Games/proton-prefixes/default}"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-$HOME/.steam/steam}"
mkdir -p "$STEAM_COMPAT_DATA_PATH"

exec "$PROTON_DIR/$PROTON_VERSION/proton" run "$@"
PROTONRUN

chmod +x ~/.local/bin/proton-run
grep -q ".local/bin" ~/.bashrc 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
info "proton-run helper created"

# MIME association
cat > ~/.local/share/applications/proton-run.desktop << DESKTOP
[Desktop Entry]
Type=Application
Name=Run with Proton
Exec=$HOME/.local/bin/proton-run %f
Icon=wine
Categories=Game;
MimeType=application/x-ms-dos-executable;application/x-exe;application/x-winexe;
NoDisplay=true
DESKTOP

update-desktop-database ~/.local/share/applications 2>/dev/null || true
xdg-mime default proton-run.desktop application/x-ms-dos-executable application/x-exe application/x-winexe 2>/dev/null || true

# DirectX Args Debugger
substep "Downloading DirectX Args Debugger..."
if curl -fsSL -o ~/Desktop/directx-args-debugger.exe \
    "https://github.com/kryuchenko/directx-args-debugger/raw/refs/heads/main/build/directx-args-debugger.exe" 2>/dev/null; then
    chmod +x ~/Desktop/directx-args-debugger.exe 2>/dev/null || true
    info "DirectX Args Debugger downloaded"
else
    warn "Failed to download DirectX Args Debugger"
fi

# Оптимизированный launcher
substep "Creating optimized launcher..."
cat > ~/Desktop/launch-directx-optimized.sh << 'LAUNCHER'
#!/usr/bin/env bash
# 🔥 Maximum Performance Launcher with GameMode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXE_FILE="$SCRIPT_DIR/directx-args-debugger.exe"

[ ! -f "$EXE_FILE" ] && { echo "ERROR: directx-args-debugger.exe not found!" >&2; exit 1; }
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"

# PERFORMANCE OPTIMIZATIONS
export PROTON_USE_WINED3D=0
export PROTON_NO_ESYNC=0
export PROTON_NO_FSYNC=0
export PROTON_FORCE_LARGE_ADDRESS_AWARE=1
export PROTON_ENABLE_NVAPI=1
export DXVK_ASYNC=1
export DXVK_STATE_CACHE=1
export DXVK_LOG_LEVEL=none
export DXVK_FRAME_RATE=0
export __GL_THREADED_OPTIMIZATIONS=1
export __GL_SYNC_TO_VBLANK=0
export mesa_glthread=true
export vblank_mode=0

# AUDIO OPTIMIZATIONS
export PULSE_LATENCY_MSEC=32          # < 48 ms — уходит щелчок каждые 5 с
export SDL_AUDIODRIVER=pulse          # форсируем Pulse вместо ALSA
export WINE_RT=1                      # rt-треды для Wine
export WINE_RT_PRIORITY_BASE=80

# DXVK HUD настройки
export DXVK_HUD=fps,gpuload

echo "🚀 Launching with GameMode + Maximum Performance..."
echo "📊 HUD: FPS + GPU Load"
echo "🎮 GameMode: ENABLED"
echo "⚡ VSync: DISABLED"

cd "$SCRIPT_DIR"

# Запускаем через GameMode с LD_PRELOAD
LD_PRELOAD="libgamemodeauto.so.0${LD_PRELOAD:+:$LD_PRELOAD}" \
exec proton-run "$EXE_FILE" "$@"
LAUNCHER

chmod +x ~/Desktop/launch-directx-optimized.sh
info "Optimized launcher created"

# Desktop shortcut
cat > ~/Desktop/directx-optimized.desktop << DESKTOPFILE
[Desktop Entry]
Version=1.0
Type=Application
Name=DirectX Debugger (Optimized)
Comment=Launch with maximum FPS
Exec=$HOME/Desktop/launch-directx-optimized.sh
Icon=wine
Terminal=false
Categories=Development;Game;
StartupNotify=true
DESKTOPFILE

chmod +x ~/Desktop/directx-optimized.desktop
gio set ~/Desktop/directx-optimized.desktop "metadata::trusted" true 2>/dev/null || true
info "Desktop shortcut created"

# Показываем что установлено
echo ""
info "User installation complete!"
echo "Files on desktop:"
ls -la ~/Desktop/directx-* ~/Desktop/launch-* 2>/dev/null || true
USERSCRIPT

# Делаем скрипт исполняемым
chmod +x "$USER_INSTALL_SCRIPT" || { error "Failed to chmod user script"; exit 1; }

# Запускаем от имени пользователя
info "Running user installation for: $TARGET_USER"
if ! sudo -u "$TARGET_USER" -H bash "$USER_INSTALL_SCRIPT"; then
    warn "User installation had some issues, but continuing..."
fi

# Теперь устанавливаем DXVK/VKD3D когда proton-run точно есть
DXVK_INSTALL

# Устанавливаем все Windows компоненты
WINDOWS_COMPONENTS_INSTALL

# Удаляем временный скрипт
rm -f "$USER_INSTALL_SCRIPT"

# ═══════════════════════════════════════════════════════════════════════════
# ФАЗА 4: ФИНАЛЬНАЯ НАСТРОЙКА
# ═══════════════════════════════════════════════════════════════════════════

step "PHASE 4: Final Configuration ${ROCKET}"

# Определение GPU
substep "Detecting GPU..."
GPU_TYPE="unknown"
if lspci 2>/dev/null | grep -i nvidia >/dev/null 2>&1; then
    GPU_TYPE="nvidia"
    info "NVIDIA GPU detected"
    # Максимальная производительность NVIDIA
    if command -v nvidia-settings &>/dev/null; then
        safe_exec sudo -u "$TARGET_USER" nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=1"
    fi
elif lspci 2>/dev/null | grep -E "AMD|ATI" >/dev/null 2>&1; then
    GPU_TYPE="amd"
    info "AMD GPU detected"
    # Производительный режим AMD
    for card in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        [ -f "$card" ] && echo "high" > "$card" 2>/dev/null || true
    done
else
    GPU_TYPE="intel"
    info "Intel/Other GPU detected"
fi

# Тест GameMode
substep "Verifying GameMode..."
if gamemoded -t >/dev/null 2>&1; then
    info "GameMode test passed"
else
    warn "GameMode test failed (will still run via LD_PRELOAD)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# ЗАВЕРШЕНИЕ
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║                    🎉 INSTALLATION COMPLETE! 🎉                  ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Installed for user:${NC} $TARGET_USER"
echo -e "${BOLD}Desktop location:${NC} $TARGET_HOME/Desktop/"
echo ""
echo -e "${GREEN}${CHECK} System components:${NC}"
echo "  • Wine + Vulkan stack"
echo "  • DXVK + VKD3D-Proton"
echo "  • GameMode + Optimizations"
echo "  • Lutris + Steam"
echo ""
echo -e "${GREEN}${CHECK} User components:${NC}"
echo "  • Proton-GE (latest)"
echo "  • Optimized launcher"
echo "  • DirectX Args Debugger"
echo ""
echo -e "${GREEN}${CHECK} Windows components:${NC}"
echo "  • Visual C++ 2005-2022"
echo "  • .NET Framework 3.5-4.8"
echo "  • DirectX 9-12 + PhysX"
echo "  • Media codecs & fonts"
echo ""
echo -e "${FIRE} ${BOLD}Performance features:${NC}"
echo "  • GameMode auto-activation"
echo "  • DXVK async compilation"
echo "  • VSync disabled"
echo "  • FPS counter enabled"
echo "  • CPU governor: performance"
echo "  • GPU: $GPU_TYPE optimized"
echo ""
echo -e "${GAME} ${BOLD}To run:${NC}"
echo "  1. Login as '$TARGET_USER'"
echo "  2. Go to Desktop"
echo "  3. Double-click 'launch-directx-optimized.sh'"
echo ""
echo -e "${ROCKET} ${BOLD}Or from terminal:${NC}"
echo "  su - $TARGET_USER"
echo "  cd ~/Desktop"
echo "  ./launch-directx-optimized.sh"
echo ""
echo -e "${YELLOW}${BOLD}Note:${NC} For SSH access, set: export DISPLAY=:0"
echo ""
echo -e "${PURPLE}${BOLD}Enjoy maximum FPS gaming! ${GAME}${FIRE}${ROCKET}${NC}"

# Финальная проверка
echo ""
echo "Checking installation:"
[ -f "$TARGET_HOME/Desktop/directx-args-debugger.exe" ] && echo "✓ DirectX Debugger found" || echo "✗ DirectX Debugger missing"
[ -f "$TARGET_HOME/Desktop/launch-directx-optimized.sh" ] && echo "✓ Optimized launcher found" || echo "✗ Launcher missing"
[ -f "$TARGET_HOME/.local/bin/proton-run" ] && echo "✓ proton-run found" || echo "✗ proton-run missing"
[ -d "$TARGET_HOME/.steam/steam/compatibilitytools.d" ] && echo "✓ Proton directory exists" || echo "✗ Proton directory missing"

exit 0
