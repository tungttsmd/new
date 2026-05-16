#!/bin/bash

# ============================================
#  Trình cài đặt Driver NVIDIA GPU
#  Hỗ trợ: Debian Trixie (Testing) và các bản phái sinh
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
    echo "║       TRÌNH CÀI ĐẶT ĐỘC QUYỀN NVIDIA GPU       ║"
    echo "║       Cấu hình kho lưu trữ Debian Trixie       ║"
    echo "║                                                ║"
    echo "║              -- DevServerTP --                 ║"
    echo "║                                                ║"
    echo "╚════════════════════════════════════════════════╝"
    echo "- Ngày cập nhật: 16/05/2026
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
    error "Vui lòng chạy script với quyền root (Sử dụng: sudo ./install-nvidia-gpu.sh)"
fi

# ────────────────────────────────────────────────
# Phát hiện hệ điều hành
# ────────────────────────────────────────────────
DISTRO_ID="unknown"
DISTRO_NAME="Unknown Linux"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-Unknown Linux}"
fi

# Hiển thị banner thông tin
print_banner
detect "Hệ điều hành phát hiện: ${BOLD}$DISTRO_NAME${NC}"

if [ "$DISTRO_ID" != "debian" ]; then
    warning "Script này được tối ưu hóa đặc biệt cho cấu trúc Debian Trixie."
    read -p "Bạn có muốn tiếp tục trên hệ thống không phải Debian gốc? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        error "Đã hủy bỏ tiến trình cài đặt."
    fi
fi

# Lấy thông tin kiến trúc phần cứng và tài khoản người dùng
ARCH=$(dpkg --print-architecture)
REAL_USER="${SUDO_USER:-$USER}"
detect "Kiến trúc hệ thống: ${BOLD}$ARCH${NC}"
detect "Thực thi bởi tài khoản: ${BOLD}$REAL_USER${NC}"

echo ""
echo -e "${BOLD}Bắt đầu quá trình cấu hình và cài đặt driver GPU...${NC}"
sleep 2

# ────────────────────────────────────────────────
# Bước 1: Cấu hình kho lưu trữ sources.list sang Trixie (SỬA LỖI TẠI ĐÂY)
# ────────────────────────────────────────────────
step 1 5 "Cập nhật danh sách kho lưu trữ sang Debian Trixie (Sửa đổi thành phần firmware)..."

SOURCES_FILE="/etc/apt/sources.list"
BACKUP_SOURCES="/etc/apt/sources.list.bak.$(date +%Y%m%d_%H%M%S)"

info "Đang tạo bản sao lưu kho lưu trữ tại: $BACKUP_SOURCES"
cp "$SOURCES_FILE" "$BACKUP_SOURCES"

# Đã bổ sung thành phần 'non-free-firmware' bắt buộc cho Debian 13 trở lên
info "Đang ghi cấu hình mới bao gồm non-free-firmware vào $SOURCES_FILE..."
cat > "$SOURCES_FILE" <<'EOF'
deb http://deb.debian.org/debian/ trixie main non-free-remote-components contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ trixie main non-free-remote-components contrib non-free non-free-firmware

deb http://security.debian.org/debian-security trixie-security main non-free-remote-components contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security trixie-security main non-free-remote-components contrib non-free non-free-firmware

deb http://deb.debian.org/debian/ trixie-updates main non-free-remote-components contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ trixie-updates main non-free-remote-components contrib non-free non-free-firmware
EOF

if [ $? -eq 0 ]; then
    success "Đã cập nhật sources.list thành công (Đã bao gồm contrib, non-free và non-free-firmware)"
else
    error "Thất bại khi ghi dữ liệu vào $SOURCES_FILE"
fi

# ────────────────────────────────────────────────
# Bước 2: Đồng bộ hóa định dạng sources (Modernize-sources)
# ────────────────────────────────────────────────
step 2 5 "Đồng bộ hóa và hiện đại hóa định dạng kho lưu trữ..."

info "Đang chạy lệnh hiện đại hóa cấu trúc apt..."
if apt modernize-sources -y > /tmp/nvidia_install.log 2>&1; then
    success "Đã đồng bộ định dạng sources thành công"
else
    warning "Lệnh 'apt modernize-sources' không khả dụng hoặc có cảnh báo. Bỏ qua..."
fi

# Kiểm tra file cấu hình mới debian.sources nếu có tạo ra
if [ -f "/etc/apt/sources.list.d/debian.sources" ]; then
    info "Đã phát hiện file cấu hình mới: /etc/apt/sources.list.d/debian.sources"
    echo -e "${CYAN}--- Nội dung debian.sources ---${NC}"
    cat /etc/apt/sources.list.d/debian.sources | grep -E "URIs|Suites|Components" || true
    echo -e "${CYAN}────────────────────────────────${NC}"
fi

# ────────────────────────────────────────────────
# Bước 3: Cập nhật cơ sở dữ liệu gói và cài đặt Linux Headers
# ────────────────────────────────────────────────
step 3 5 "Cập nhật hệ thống & cài đặt Linux Headers..."

info "Đang chạy apt update..."
apt update >> /tmp/nvidia_install.log 2>&1

info "Đang cài đặt linux-headers cho kiến trúc: $ARCH..."
if apt install linux-headers-$ARCH -y >> /tmp/nvidia_install.log 2>&1; then
    success "Cài đặt Linux Headers thành công"
else
    error "Không thể cài đặt Linux Headers. Vui lòng kiểm tra file log: /tmp/nvidia_install.log"
fi

# ────────────────────────────────────────────────
# Bước 4: Cài đặt Driver NVIDIA và bộ vi chương trình (Firmware)
# ────────────────────────────────────────────────
step 4 5 "Cài đặt Driver NVIDIA độc quyền & Firmware..."

info "Hệ thống bắt đầu tải và biên dịch driver (Quá trình này có thể mất vài phút)..."
PACKAGES="nvidia-kernel-dkms nvidia-driver firmware-misc-nonfree"

if apt install -y $PACKAGES >> /tmp/nvidia_install.log 2>&1; then
    success "Đã cài đặt thành công Core Driver NVIDIA và thành phần Firmware liên quan"
else
    error "Lỗi trong quá trình build driver kernel dkms hoặc thiếu gói. Xem log: /tmp/nvidia_install.log"
fi

# ────────────────────────────────────────────────
# Bước 5: Khởi động lại hệ thống để kích hoạt Module Kernel
# ────────────────────────────────────────────────
step 5 5 "Hoàn tất và chuẩn bị khởi động lại máy..."

echo -e "${GREEN}${BOLD}"
echo "╔════════════════════════════════════════════════╗"
echo "║                                                ║"
echo "║     ✓ TIẾN TRÌNH CÀI ĐẶT HOÀN THÀNH SƠ BỘ      ║"
echo "║                                                ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}Hướng dẫn kiểm tra sau khi máy khởi động lại:${NC}"
echo -e "  Sau khi hệ thống Reboot, hãy mở Terminal và chạy lệnh sau để xác nhận VGA:"
echo -e "  ${GREEN}${BOLD}nvidia-smi${NC}"
echo ""
warning "Hệ thống cần được khởi động lại ngay để nạp driver NVIDIA vào nhân Linux."

read -p "Bạn có muốn thực hiện khởi động lại (Reboot) hệ thống ngay bây giờ không? (Y/n): " reboot_now
if [[ ! "$reboot_now" =~ ^[Nn]$ ]]; then
    info "Hệ thống đang khởi động lại..."
    sleep 2
    reboot
else
    info "Vui lòng nhớ tự khởi động lại máy bằng lệnh 'sudo reboot' để driver có hiệu lực!"
fi
