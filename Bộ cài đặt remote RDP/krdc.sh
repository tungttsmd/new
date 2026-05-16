#!/bin/bash

# ============================================
#  Script Cài Đặt KRDC Tự Động (KDE Remote Client)
#  Định dạng chuẩn tích hợp hệ thống DevServerTP
# ============================================

# 1. Định nghĩa màu sắc hệ thống
RED='\033;0/31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Tag trạng thái chuẩn 7 ký tự thuần khoảng trắng
OK_TAG="[   ${GREEN}OK${NC}   ]"
EMPTY_TAG="[ ${YELLOW}EMPTY${NC} ]"
ERR_TAG="[ ${RED}ERROR${NC} ]"

# Khởi tạo mảng lưu trữ báo cáo cục bộ
declare -a REPORT_OK
declare -a REPORT_EMPTY
declare -a REPORT_ERR

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

# Giao diện Banner con giống Remmina
clear
echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════╗"
echo "║                                                ║"
echo "║            TRÌNH CÀI ĐẶT KRDC CLIENT           ║"
echo "║       Hỗ trợ Quản lý Remote Desktop (RDP/VNC)  ║"
echo "║                                                ║"
echo "║               -- DevServerTP --                ║"
echo "║                                                ║"
echo "╚════════════════════════════════════════════════╝"
echo "- Ngày cập nhật: 16/05/2026"
echo -e "${NC}"

# Nhận diện thông tin môi trường
REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo ~$REAL_USER)
detect "Tài khoản thực thi: ${BOLD}$REAL_USER${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    detect "Hệ điều hành tương thích: ${BOLD}$PRETTY_NAME${NC}"
fi

echo ""
info "Bắt đầu tiến trình kiểm tra trạng thái trước khi cài đặt..."

# ────────────────────────────────────────────────
# BƯỚC 1: KIỂM TRA SỰ TỒN TẠI CỦA ỨNG DỤNG LỆNH
# ────────────────────────────────────────────────
step 1 3 "Kiểm tra sự tồn tại của KRDC Client trên hệ thống..."

if command -v krdc &> /dev/null; then
    KRDC_VER=$(krdc --version 2>&1 | head -n 1)
    warning "KRDC đã được cài đặt sẵn trên hệ thống ($KRDC_VER)."
    REPORT_OK+=("Ứng dụng KRDC Client (Đã cài sẵn từ trước via APT)")
else
    info "Chưa phát hiện KRDC. Tiến hành chuẩn bị cài đặt mới..."
    info "Đang cập nhật danh sách gói hệ thống (apt update)..."
    apt update -y &> /dev/null
    
    info "Đang tải và cấu hình cài đặt gói krdc..."
    apt install krdc -y &> /dev/null
    
    if command -v krdc &> /dev/null; then
        success "Đã cài đặt thành công gói krdc core."
        REPORT_OK+=("Ứng dụng KRDC Client (Cài mới thành công via APT)")
    else
        REPORT_ERR+=("Ứng dụng KRDC Client (Cài đặt thất bại, lỗi apt)")
    fi
fi

# ────────────────────────────────────────────────
# BƯỚC 2: XỬ LÝ VÀ KIỂM TRA THƯ VIỆN PHỤ THUỘC (PLUGINS)
# ────────────────────────────────────────────────
step 2 3 "Kiểm tra và cấu hình giao thức Plugin RDP/VNC..."

# KRDC cần gói freerdp để chạy mượt RDP
info "Đang kiểm tra gói thư viện hỗ trợ freerdp2-x11..."
if dpkg -l | grep -q "freerdp2-x11"; then
    echo -e "${OK_TAG} Plugin FreeRDP đã tích hợp sẵn, hoạt động bình thường."
    REPORT_OK+=("Plugin RDP Backend (Đã sẵn sàng hoạt động)")
else
    info "Đang cài bổ sung freerdp2-x11 để kích hoạt giao thức RDP..."
    apt install freerdp2-x11 -y &> /dev/null
    if [ $? -eq 0 ]; then
        success "Tích hợp Plugin RDP thành công."
        REPORT_OK+=("Plugin RDP Backend (Đã bổ sung thành công)")
    else
        warning "Không thể cài đặt freerdp2-x11. Kết nối RDP có thể bị hạn chế."
        REPORT_EMPTY+=("Plugin RDP Backend (Chưa được kích hoạt tối ưu)")
    fi
fi

# ────────────────────────────────────────────────
# BƯỚC 3: KIỂM TRA HỒ SƠ DỮ LIỆU CẤU HÌNH (PROFILES)
# ────────────────────────────────────────────────
step 3 3 "Kiểm tra dữ liệu cấu hình người dùng..."

KRDC_CONFIG_DIR="$USER_HOME/.config/krdcrc"
if [ -f "$KRDC_CONFIG_DIR" ]; then
    echo -e "${OK_TAG} Tìm thấy tệp cấu hình krdcrc của user '$REAL_USER'."
    REPORT_OK+=("Hồ sơ dữ liệu (Phát hiện file cấu hình krdcrc hiện hữu)")
else
    echo -e "${EMPTY_TAG} Chưa tìm thấy dữ liệu kết nối cũ."
    REPORT_EMPTY+=("Hồ sơ dữ liệu (Chưa khởi tạo kết nối nào)")
fi

# ────────────────────────────────────────────────
# 📊 BẢNG TỔNG KẾT TIẾN TRÌNH CÀI ĐẶT CỤC BỘ (GIỐNG REMMINA)
# ────────────────────────────────────────────────
echo ""
echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}📊 BẢNG TỔNG KẾT TIẾN TRÌNH CÀI ĐẶT KRDC:${NC}"
echo ""
echo -e "${GREEN}${BOLD}[✓] CÁC THÀNH PHẦN HOẠT ĐỘNG TỐT (OK):${NC}"
if [ ${#REPORT_OK[@]} -eq 0 ]; then echo -e "  (Không có)"; else
    for item in "${REPORT_OK[@]}"; do echo -e "  └── $OK_TAG $item"; done
fi
echo ""
echo -e "${YELLOW}${BOLD}[⚠] CÁC THÀNH PHẦN CHƯA KHỞI TẠO (EMPTY):${NC}"
if [ ${#REPORT_EMPTY[@]} -eq 0 ]; then echo -e "  (Không có hạng mục nào trống)"; else
    for item in "${REPORT_EMPTY[@]}"; do echo -e "  └── $EMPTY_TAG $item"; done
fi
echo ""
echo -e "${RED}${BOLD}[✗] CÁC THÀNH PHẦN LỖI PHÁT SINH (ERROR):${NC}"
if [ ${#REPORT_ERR[@]} -eq 0 ]; then 
    echo -e "  🎉 Tuyệt vời! Bộ cài hoạt động mượt mà, không phát sinh lỗi."
else
    for item in "${REPORT_ERR[@]}"; do echo -e "  └── $ERR_TAG $item"; done
fi
echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"

# Trả trạng thái kết thúc logic cho script tổng
if [ ${#REPORT_ERR[@]} -eq 0 ]; then
    success "CÀI ĐẶT HOÀN TẤT THÀNH CÔNG!"
    info "Khởi chạy ứng dụng bằng cách gõ lệnh: krdc (hoặc tìm trong Application Menu)"
    exit 0
else
    error "Quá trình triển khai KRDC có lỗi phát sinh."
    exit 1
fi
