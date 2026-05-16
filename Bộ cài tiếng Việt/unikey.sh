#!/bin/bash

# ============================================
#  Trình cài đặt Fcitx5 + Unikey
#  Hỗ trợ: Debian, Ubuntu và các bản phái sinh
#  DevServerTP
# ============================================

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║                                                ║"
    echo "║      TRÌNH CÀI ĐẶT FCITX5 + UNIKEY             ║"
    echo "║      Bộ gõ tiếng Việt cho Debian/Ubuntu        ║"
    echo "║                                                ║"
    echo "║              -- DevServerTP --                 ║"
    echo "║                                                ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

step() {
    echo ""
    echo -e "${BLUE}${BOLD}[BƯỚC $1/$2]${NC} ${BOLD}$3${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
}

success() { echo -e "${GREEN}✓${NC} $1"; }
error()   { echo -e "${RED}✗ LỖI:${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
info()    { echo -e "${CYAN}ℹ${NC} $1"; }
detect()  { echo -e "${MAGENTA}◆${NC} $1"; }

# ────────────────────────────────────────────────
# Kiểm tra quyền root
# ────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    error "Vui lòng chạy script với quyền root (sudo ./install-fcitx5.sh)"
fi

# ────────────────────────────────────────────────
# Phát hiện distro
# ────────────────────────────────────────────────
DISTRO_ID="unknown"
DISTRO_VERSION=""
DISTRO_NAME="Unknown Linux"
DISTRO_FAMILY="unknown"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_VERSION="${VERSION_ID:-}"
    DISTRO_NAME="${PRETTY_NAME:-Unknown Linux}"
    
    # Xác định họ distro (Debian-based hay không)
    if [ "$DISTRO_ID" = "debian" ] || [ "$DISTRO_ID" = "raspbian" ] || [ "$DISTRO_ID" = "kali" ]; then
        DISTRO_FAMILY="debian"
    elif [ "$DISTRO_ID" = "ubuntu" ] || [ "$DISTRO_ID" = "linuxmint" ] || [ "$DISTRO_ID" = "pop" ] || \
         [ "$DISTRO_ID" = "zorin" ] || [ "$DISTRO_ID" = "elementary" ] || [ "$DISTRO_ID" = "neon" ]; then
        DISTRO_FAMILY="ubuntu"
    elif [ -n "${ID_LIKE:-}" ]; then
        # Kiểm tra ID_LIKE để bắt các distro phái sinh
        case "$ID_LIKE" in
            *ubuntu*) DISTRO_FAMILY="ubuntu" ;;
            *debian*) DISTRO_FAMILY="debian" ;;
        esac
    fi
fi

# Fallback nếu chưa xác định được
if [ "$DISTRO_FAMILY" = "unknown" ] && [ -f /etc/debian_version ]; then
    DISTRO_FAMILY="debian"
fi

# Hiển thị banner
print_banner

# Kiểm tra hỗ trợ
detect "Hệ điều hành: ${BOLD}$DISTRO_NAME${NC}"
case "$DISTRO_FAMILY" in
    debian)
        detect "Họ distro: ${BOLD}Debian${NC}"
        ;;
    ubuntu)
        detect "Họ distro: ${BOLD}Ubuntu${NC}"
        ;;
    *)
        error "Script chỉ hỗ trợ Debian/Ubuntu và bản phái sinh. Distro hiện tại: $DISTRO_NAME"
        ;;
esac

# Xác định user thật để chạy GUI
REAL_USER="${SUDO_USER:-$USER}"
if [ "$REAL_USER" = "root" ]; then
    warning "Đang chạy trực tiếp dưới root, không phát hiện được user thường."
    warning "GUI configtool có thể không mở được. Khuyến nghị: sudo ./install-fcitx5.sh"
fi

USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
USER_ID=$(id -u "$REAL_USER")

# Phát hiện session type (X11 / Wayland)
SESSION_TYPE=$(sudo -u "$REAL_USER" bash -c 'echo $XDG_SESSION_TYPE' 2>/dev/null)
SESSION_TYPE="${SESSION_TYPE:-unknown}"
detect "Session type: ${BOLD}$SESSION_TYPE${NC}"

# Phát hiện desktop environment
DESKTOP_ENV=$(sudo -u "$REAL_USER" bash -c 'echo $XDG_CURRENT_DESKTOP' 2>/dev/null)
DESKTOP_ENV="${DESKTOP_ENV:-unknown}"
detect "Desktop environment: ${BOLD}$DESKTOP_ENV${NC}"

echo ""
echo -e "${BOLD}Bắt đầu quá trình cài đặt...${NC}"
sleep 2

# ────────────────────────────────────────────────
# Bước 1: Cập nhật danh sách gói
# ────────────────────────────────────────────────
step 1 6 "Đang cập nhật danh sách gói..."
if apt update > /tmp/fcitx5_install.log 2>&1; then
    success "Đã cập nhật danh sách gói thành công"
else
    error "Không thể cập nhật. Xem /tmp/fcitx5_install.log"
fi

# ────────────────────────────────────────────────
# Bước 2: Cài đặt các gói fcitx5
# ────────────────────────────────────────────────
step 2 6 "Đang cài đặt Fcitx5 + Unikey + Configtool..."

# Gói cơ bản chung cho cả Debian và Ubuntu
PACKAGES="fcitx5 fcitx5-unikey fcitx5-configtool"
PACKAGES="$PACKAGES fcitx5-frontend-gtk2 fcitx5-frontend-gtk3 fcitx5-frontend-qt5"
PACKAGES="$PACKAGES libxcb-cursor0 im-config"

# Gói bổ sung tùy distro
if [ "$DISTRO_FAMILY" = "ubuntu" ]; then
    # Ubuntu thường có thêm fcitx5-frontend-gtk4 trên các bản mới
    if apt-cache show fcitx5-frontend-gtk4 > /dev/null 2>&1; then
        PACKAGES="$PACKAGES fcitx5-frontend-gtk4"
    fi
fi

info "Các gói sẽ cài: $PACKAGES"

if apt install -y $PACKAGES >> /tmp/fcitx5_install.log 2>&1; then
    success "Đã cài đặt tất cả các gói thành công"
else
    error "Không thể cài đặt. Xem /tmp/fcitx5_install.log"
fi

# ────────────────────────────────────────────────
# Bước 3: Gỡ IBus trên Ubuntu (tùy chọn an toàn)
# ────────────────────────────────────────────────
step 3 6 "Đang cấu hình input method system..."

if [ "$DISTRO_FAMILY" = "ubuntu" ]; then
    info "Ubuntu mặc định dùng IBus, đang chuyển sang Fcitx5..."
    
    # Không gỡ IBus mà chỉ disable, an toàn hơn
    if systemctl --user -M "$REAL_USER@" stop ibus-daemon.service > /dev/null 2>&1; then
        info "Đã dừng IBus daemon"
    fi
fi

# Đặt fcitx5 làm input method mặc định
if im-config -n fcitx5 >> /tmp/fcitx5_install.log 2>&1; then
    success "Đã đặt fcitx5 làm input method mặc định"
else
    warning "im-config chưa được cấu hình hoàn toàn"
fi

# Trên Ubuntu, cập nhật im-config cho user
if [ "$DISTRO_FAMILY" = "ubuntu" ]; then
    sudo -u "$REAL_USER" im-config -n fcitx5 >> /tmp/fcitx5_install.log 2>&1 || true
fi

# ────────────────────────────────────────────────
# Bước 4: Cấu hình biến môi trường
# ────────────────────────────────────────────────
step 4 6 "Đang cấu hình biến môi trường cho $REAL_USER..."

XPROFILE="$USER_HOME/.xprofile"

if [ -f "$XPROFILE" ] && grep -q "fcitx" "$XPROFILE"; then
    info "Biến môi trường fcitx đã có trong $XPROFILE, bỏ qua"
else
    cat >> "$XPROFILE" <<'EOF'

# Fcitx5 input method (added by DevServerTP installer)
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx
export GLFW_IM_MODULE=ibus
EOF
    chown "$REAL_USER:$REAL_USER" "$XPROFILE"
    success "Đã thêm biến môi trường vào $XPROFILE"
fi

# Trên Ubuntu/GNOME hoặc Wayland, thêm vào ~/.profile để chắc chắn được load
if [ "$DISTRO_FAMILY" = "ubuntu" ] || [ "$SESSION_TYPE" = "wayland" ]; then
    PROFILE_FILE="$USER_HOME/.profile"
    if [ -f "$PROFILE_FILE" ] && grep -q "GTK_IM_MODULE=fcitx" "$PROFILE_FILE"; then
        info "Biến môi trường đã có trong .profile, bỏ qua"
    else
        cat >> "$PROFILE_FILE" <<'EOF'

# Fcitx5 input method (added by DevServerTP installer)
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx
export INPUT_METHOD=fcitx
EOF
        chown "$REAL_USER:$REAL_USER" "$PROFILE_FILE"
        success "Đã thêm biến môi trường vào ~/.profile (Ubuntu/Wayland)"
    fi
    
    # Tạo file environment.d cho systemd user session (Wayland/GNOME mới)
    ENV_DIR="$USER_HOME/.config/environment.d"
    sudo -u "$REAL_USER" mkdir -p "$ENV_DIR"
    cat > "$ENV_DIR/fcitx5.conf" <<'EOF'
# Fcitx5 input method (added by DevServerTP installer)
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
INPUT_METHOD=fcitx
EOF
    chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config/environment.d"
    success "Đã tạo systemd user environment config"
fi

# ────────────────────────────────────────────────
# Bước 5: Tự động cấu hình Unikey trong profile fcitx5
# ────────────────────────────────────────────────
step 5 6 "Đang cấu hình sẵn English + Unikey vào cột trái configtool..."

# QUAN TRỌNG: Kill fcitx5 trước khi ghi profile, nếu không daemon sẽ ghi đè lại
if sudo -u "$REAL_USER" pgrep -x fcitx5 > /dev/null 2>&1; then
    info "Tạm dừng fcitx5 daemon để ghi cấu hình..."
    sudo -u "$REAL_USER" pkill -x fcitx5 2>/dev/null || true
    sleep 1
fi

FCITX5_CONFIG_DIR="$USER_HOME/.config/fcitx5"
PROFILE_FCITX="$FCITX5_CONFIG_DIR/profile"

sudo -u "$REAL_USER" mkdir -p "$FCITX5_CONFIG_DIR"

# Backup profile cũ nếu có
if [ -f "$PROFILE_FCITX" ]; then
    BACKUP_FILE="$PROFILE_FCITX.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$PROFILE_FCITX" "$BACKUP_FILE"
    chown "$REAL_USER:$REAL_USER" "$BACKUP_FILE"
    info "Đã backup profile cũ: $BACKUP_FILE"
fi

# Luôn ghi đè profile để đảm bảo English (keyboard-us) + Unikey hiển thị bên trái
cat > "$PROFILE_FCITX" <<'EOF'
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=us
# Default Input Method
DefaultIM=unikey

[Groups/0/Items/0]
# Name
Name=keyboard-us
# Layout
Layout=

[Groups/0/Items/1]
# Name
Name=unikey
# Layout
Layout=

[GroupOrder]
0=Default
EOF
chown -R "$REAL_USER:$REAL_USER" "$FCITX5_CONFIG_DIR"
success "Đã tự động cấu hình: English (keyboard-us) + Unikey vào cột trái"

# ────────────────────────────────────────────────
# Bước 6: Khởi động fcitx5 và mở configtool
# ────────────────────────────────────────────────
step 6 6 "Đang khởi động Fcitx5 và mở giao diện cấu hình..."

# Lấy DISPLAY và DBUS của user
USER_DISPLAY=$(sudo -u "$REAL_USER" bash -c 'echo $DISPLAY' 2>/dev/null)
USER_DISPLAY="${USER_DISPLAY:-:0}"
USER_DBUS="unix:path=/run/user/$USER_ID/bus"

# Trên Wayland, set thêm WAYLAND_DISPLAY
USER_WAYLAND=$(sudo -u "$REAL_USER" bash -c 'echo $WAYLAND_DISPLAY' 2>/dev/null)

# Kill fcitx5 cũ nếu đang chạy (để load config mới)
if sudo -u "$REAL_USER" pgrep -x fcitx5 > /dev/null 2>&1; then
    info "Khởi động lại fcitx5 daemon để áp dụng cấu hình mới..."
    sudo -u "$REAL_USER" pkill -x fcitx5 2>/dev/null || true
    sleep 1
fi

info "Khởi động fcitx5 daemon..."
if [ -n "$USER_WAYLAND" ]; then
    sudo -u "$REAL_USER" \
        DISPLAY="$USER_DISPLAY" \
        WAYLAND_DISPLAY="$USER_WAYLAND" \
        DBUS_SESSION_BUS_ADDRESS="$USER_DBUS" \
        XDG_RUNTIME_DIR="/run/user/$USER_ID" \
        nohup fcitx5 -d > /dev/null 2>&1 &
else
    sudo -u "$REAL_USER" \
        DISPLAY="$USER_DISPLAY" \
        DBUS_SESSION_BUS_ADDRESS="$USER_DBUS" \
        XDG_RUNTIME_DIR="/run/user/$USER_ID" \
        nohup fcitx5 -d > /dev/null 2>&1 &
fi
sleep 2
success "Đã khởi động fcitx5 daemon"

# Mở configtool
info "Mở fcitx5-configtool..."
sudo -u "$REAL_USER" \
    DISPLAY="$USER_DISPLAY" \
    WAYLAND_DISPLAY="${USER_WAYLAND:-}" \
    DBUS_SESSION_BUS_ADDRESS="$USER_DBUS" \
    XDG_RUNTIME_DIR="/run/user/$USER_ID" \
    nohup fcitx5-configtool > /dev/null 2>&1 &

sleep 1
success "Đã mở giao diện cấu hình Fcitx5"

# ────────────────────────────────────────────────
# Hoàn tất
# ────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "╔════════════════════════════════════════════════╗"
echo "║                                                ║"
echo "║         ✓ CÀI ĐẶT HOÀN TẤT THÀNH CÔNG          ║"
echo "║                                                ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}Thông tin cài đặt:${NC}"
echo -e "  ${MAGENTA}◆${NC} Hệ điều hành: ${BOLD}$DISTRO_NAME${NC}"
echo -e "  ${MAGENTA}◆${NC} Session: ${BOLD}$SESSION_TYPE${NC} / Desktop: ${BOLD}$DESKTOP_ENV${NC}"
echo -e "  ${MAGENTA}◆${NC} User cấu hình: ${BOLD}$REAL_USER${NC}"
echo ""

echo -e "${BOLD}Trong cửa sổ cấu hình vừa mở (nếu Unikey chưa có sẵn):${NC}"
echo -e "  ${CYAN}1.${NC} Bấm dấu ${BOLD}+${NC} để thêm input method"
echo -e "  ${CYAN}2.${NC} Bỏ tick ${BOLD}'Only Show Current Language'${NC}"
echo -e "  ${CYAN}3.${NC} Tìm ${BOLD}'Unikey'${NC} → thêm vào"
echo -e "  ${CYAN}4.${NC} Bấm Apply / OK"
echo ""

echo -e "${BOLD}Lưu ý:${NC}"
if [ "$DISTRO_FAMILY" = "ubuntu" ]; then
    echo -e "  ${YELLOW}⚠${NC} Trên Ubuntu, ${BOLD}BẮT BUỘC đăng xuất và đăng nhập lại${NC} để chuyển từ IBus sang Fcitx5"
    if [ "$SESSION_TYPE" = "wayland" ]; then
        echo -e "  ${YELLOW}⚠${NC} Đang dùng ${BOLD}Wayland${NC} - một số app cũ có thể cần thêm cấu hình"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Nên ${BOLD}đăng xuất và đăng nhập lại${NC} để biến môi trường có hiệu lực đầy đủ"
fi
echo -e "  ${CYAN}ℹ${NC} Chuyển đổi gõ tiếng Việt: ${BOLD}Ctrl + Space${NC}"
echo -e "  ${CYAN}ℹ${NC} Log cài đặt: ${BOLD}/tmp/fcitx5_install.log${NC}"
echo ""
