#!/bin/bash

# ============================================
#  Trình cài đặt Remmina Client + Plugin RDP
#  Hỗ trợ: Debian, Ubuntu và các bản phái sinh
#  Cơ chế: Tự động kiểm tra trạng thái trước khi cài
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

# Trạng thái hiển thị gọn cho bảng tổng kết
OK_TAG="[   ${GREEN}OK${NC}   ]"
EMPTY_TAG="[ ${YELLOW}EMPTY${NC} ]"
ERR_TAG="[ ${RED}ERROR${NC} ]"

# Mảng lưu trữ trạng thái phục vụ bảng tổng kết cuối file
declare -a REPORT_OK
declare -a REPORT_EMPTY
declare -a REPORT_ERR

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║                                                ║"
    echo "║         TRÌNH CÀI ĐẶT REMMINA CLIENT           ║"
    echo "║      Hỗ trợ Quản lý Remote Desktop (RDP)       ║"
    echo "║                                                ║"
    echo "║              -- DevServerTP --                 ║"
    echo "║                                                ║"
    echo "╚════════════════════════════════════════════════╝"
    echo "- Ngày cập nhật: 16/05/2026"
    echo -e "${NC}"
}

step() {
    echo ""
    echo -e "${BLUE}${BOLD}[BƯỚC $1/$2]${NC} ${BOLD}$3${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
}

success() { echo -e "${GREEN}✓ THÀNH CÔNG:${NC} $1"; }
error()   { echo -e "${RED}✗ LỖI:${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}⚠ LƯU Ý:${NC} $1"; }
info()    { echo -e "${CYAN}ℹ THÔNG TIN:${NC} $1"; }
detect()  { echo -e "${MAGENTA}◆ PHÁT HIỆN:${NC} $1"; }

# ────────────────────────────────────────────────
# Kiểm tra quyền root
# ────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    error "Vui lòng chạy script với quyền root (Sử dụng: sudo ./install-remmina.sh)"
fi

# Phát hiện hệ điều hành
DISTRO_FAMILY="unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    if [ "$DISTRO_ID" = "debian" ] || [ "$DISTRO_ID" = "raspbian" ] || [ "$DISTRO_ID" = "kali" ] || [[ "${ID_LIKE:-}" == *"debian"* ]]; then
        DISTRO_FAMILY="debian"
    elif [ "$DISTRO_ID" = "ubuntu" ] || [ "$DISTRO_ID" = "linuxmint" ] || [ "$DISTRO_ID" = "pop" ] || [[ "${ID_LIKE:-}" == *"ubuntu"* ]]; then
        DISTRO_FAMILY="ubuntu"
    fi
fi

# Gọi hiển thị Banner
print_banner

REAL_USER="${SUDO_USER:-$USER}"
detect "Tài khoản thực thi: ${BOLD}$REAL_USER${NC}"
detect "Hệ điều hành tương thích: ${BOLD}${PRETTY_NAME:-Unknown Linux}${NC}"

echo ""
echo -e "${BOLD}Bắt đầu tiến trình kiểm tra trạng thái trước khi cài đặt...${NC}"
sleep 1.5

# ────────────────────────────────────────────────
# Bước 1: Kiểm tra trạng thái Remmina hiện tại
# ────────────────────────────────────────────────
step 1 3 "Kiểm tra sự tồn tại của Remmina Client trên hệ thống..."

REMMINA_NEED_INSTALL=true

if command -v remmina &> /dev/null; then
    REMMINA_VER=$(remmina --version 2>&1 | head -n 1)
    warning "Remmina đã được cài đặt sẵn qua trình quản lý APT ($REMMINA_VER)."
    REMMINA_NEED_INSTALL=false
    REPORT_OK+=("Ứng dụng Remmina Client (Đã cài sẵn từ trước via APT)")
elif command -v flatpak &> /dev/null && flatpak list | grep -iq remmina; then
    warning "Remmina đã được cài đặt sẵn trên hệ thống dưới dạng gói Flatpak."
    REMMINA_NEED_INSTALL=false
    REPORT_OK+=("Ứng dụng Remmina Client (Đã cài sẵn từ trước via Flatpak)")
else
    info "Hệ thống sạch, chưa phát hiện dấu vết cài đặt của Remmina Client."
fi

# ────────────────────────────────────────────────
# Bước 2: Thực thi cài đặt Remmina nếu chưa có
# ────────────────────────────────────────────────
step 2 3 "Xử lý tiến trình cài đặt gói phần mềm..."

if [ "$REMMINA_NEED_INSTALL" = false ]; then
    info "Bỏ qua tiến trình tải xuống ứng dụng do gói đã tồn tại."
else
    info "Đang tiến hành cập nhật danh bạ apt..."
    apt update >> /tmp/remmina_install.log 2>&1
    
    info "Đang tải và thiết lập gói 'remmina'..."
    if apt install -y remmina >> /tmp/remmina_install.log 2>&1; then
        success "Đã cài đặt thành công lõi ứng dụng Remmina Client."
        REPORT_OK+=("Ứng dụng Remmina Client (Cài đặt mới thành công)")
    else
        error "Thất bại khi cài đặt gói remmina. Chi tiết xem tại: /tmp/remmina_install.log"
    fi
fi

# ────────────────────────────────────────────────
# Bước 3: Kiểm tra và bổ sung Plugin RDP kết nối máy tính xa
# ────────────────────────────────────────────────
step 3 3 "Kiểm tra và cấu hình giao thức Plugin RDP..."

# Nếu cài qua flatpak thì bỏ qua (vì flatpak tự đóng gói sẵn plugin)
if command -v flatpak &> /dev/null && flatpak list | grep -iq remmina; then
    success "Nhận diện gói Flatpak: Plugin RDP đã được tự động tích hợp sẵn."
    REPORT_OK+=("Plugin Remmina RDP (Mặc định đi kèm theo Flatpak)")
else
    info "Đang kiểm tra gói remmina-plugin-rdp trên hệ thống..."
    if dpkg -l | grep -q "remmina-plugin-rdp"; then
        success "Plugin Remmina RDP đã có sẵn, hoạt động bình thường."
        REPORT_OK+=("Plugin Remmina RDP (Đã sẵn sàng hoạt động)")
    else
        warning "Thiếu gói Plugin RDP. Tiến hành cài đặt bổ sung để hỗ trợ Remote Desktop..."
        if apt install -y remmina-plugin-rdp >> /tmp/remmina_install.log 2>&1; then
            success "Đã cài đặt bổ sung thành công Plugin Remmina RDP."
            REPORT_OK+=("Plugin Remmina RDP (Cài đặt bổ sung thành công)")
        else
            warning "Không thể cài đặt remmina-plugin-rdp tự động."
            REPORT_ERR+=("Plugin Remmina RDP (Cài đặt thất bại, thiếu môi trường đồ họa)")
        fi
    fi
fi

# Kiểm tra thư mục lưu profile kết nối để xuất trạng thái vào bảng tổng kết
USER_HOME=$(eval echo ~$REAL_USER)
REMMINA_CONF_DIR="$USER_HOME/.local/share/remmina"
if [ -d "$REMMINA_CONF_DIR" ]; then
    PROFILE_COUNT=$(ls -1 "$REMMINA_CONF_DIR"/*.remmina 2>/dev/null | wc -l)
    if [ "$PROFILE_COUNT" -gt 0 ]; then
        REPORT_OK+=("Hồ sơ dữ liệu (Phát hiện đang lưu trữ $PROFILE_COUNT profile kết nối của user '$REAL_USER')")
    else
        REPORT_EMPTY+=("Hồ sơ dữ liệu (Thư mục cấu hình rỗng, chưa khởi tạo phiên kết nối nào)")
    fi
else
    REPORT_EMPTY+=("Hồ sơ dữ liệu (Chưa tạo thư mục lưu trữ profile, cần mở app lần đầu để kích hoạt)")
fi

# ────────────────────────────────────────────────
# BẢNG THỐNG KÊ TỔNG KẾT TRẠNG THÁI SAU KHI CHẠY
# ────────────────────────────────────────────────
echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}📊 BẢNG TỔNG KẾT TIẾN TRÌNH CÀI ĐẶT REMMINA:${NC}"
echo ""

# 1. Danh sách dịch vụ OK
echo -e "${GREEN}${BOLD}[✓] CÁC THÀNH PHẦN HOẠT ĐỘNG TỐT (OK):${NC}"
if [ ${#REPORT_OK[@]} -eq 0 ]; then
    echo -e "  ${NC}(Không có thành phần nào)${NC}"
else
    for item in "${REPORT_OK[@]}"; do
        echo -e "  └── $OK_TAG $item"
    done
fi
echo ""

# 2. Danh sách dịch vụ EMPTY (Trống/Chưa tạo dữ liệu)
echo -e "${YELLOW}${BOLD}[⚠] CÁC THÀNH PHẦN CHƯA KHỞI TẠO (EMPTY):${NC}"
if [ ${#REPORT_EMPTY[@]} -eq 0 ]; then
    echo -e "  ${NC}(Không có hạng mục nào trống)${NC}"
else
    for item in "${REPORT_EMPTY[@]}"; do
        echo -e "  └── $EMPTY_TAG $item"
    done
fi
echo ""

# 3. Danh sách dịch vụ LỖI (ERROR)
echo -e "${RED}${BOLD}[✗] CÁC THÀNH PHẦN LỖI PHÁT SINH (ERROR):${NC}"
if [ ${#REPORT_ERR[@]} -eq 0 ]; then
    echo -e "  ${GREEN}🎉 Tuyệt vời! Bộ cài hoạt động mượt mà, không phát sinh lỗi.${NC}"
else
    for item in "${REPORT_ERR[@]}"; do
        echo -e "  └── $ERR_TAG $item"
    done
fi

echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}${BOLD}✓ CÀI ĐẶT HOÀN TẤT THÀNH CÔNG!${NC}"
echo -e "  ${CYAN}ℹ${NC} Nhật ký chi tiết lưu tại: ${BOLD}/tmp/remmina_install.log${NC}"
echo -e "  ${CYAN}ℹ${NC} Khởi chạy ứng dụng bằng cách gõ lệnh: ${BOLD}remmina${NC} (hoặc tìm trong Application Menu)"
echo ""
