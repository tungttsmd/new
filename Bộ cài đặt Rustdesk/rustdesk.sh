#!/bin/bash

# ============================================
#  Script Cài Đặt RustDesk Tự Động (Remote Desktop)
#  Định dạng chuẩn tích hợp hệ thống DevServerTP
# ============================================

# 1. Định nghĩa màu sắc hệ thống
RED='\033[0;31m'
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

# Giao diện Banner con đồng bộ
clear
echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════╗"
echo "║                                                ║"
echo "║           TRÌNH CÀI ĐẶT RUSTDESK CLIENT        ║"
echo "║       Hỗ trợ Điều khiển Máy tính Từ xa (P2P)   ║"
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
step 1 3 "Kiểm tra sự tồn tại của RustDesk trên hệ thống..."

if command -v rustdesk &> /dev/null; then
    RUSTDESK_VER=$(rustdesk --version 2>&1 | head -n 1)
    warning "RustDesk đã được cài đặt sẵn trên hệ thống ($RUSTDESK_VER)."
    REPORT_OK+=("Ứng dụng RustDesk Client (Đã cài sẵn từ trước)")
    
    # Hỏi người dùng xem có muốn cài đè/cập nhật không
    echo -e -n "${YELLOW}❓ Bạn có muốn cài đè/cập nhật lên phiên bản mới nhất không? (y/N): ${NC}"
    read -r REINSTALL
    if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
        info "Bỏ qua tiến trình cài đặt theo yêu cầu."
        exit 0
    fi
fi

# ────────────────────────────────────────────────
# BƯỚC 2: TỰ ĐỘNG TẢI FILE .DEB PHÙ HỢP KIẾN TRÚC CPU
# ────────────────────────────────────────────────
step 2 3 "Tải xuống gói cài đặt từ hệ thống chính thức..."

# Cập nhật danh sách gói bổ trợ trước
apt update -y &> /dev/null
apt install wget curl egrep -y &> /dev/null

# Nhận diện kiến trúc CPU (x86_64 hoặc ARM64)
ARCH=$(uname -m)
RUSTDESK_DEB="/tmp/rustdesk_current.deb"
[ -f "$RUSTDESK_DEB" ] && rm -f "$RUSTDESK_DEB"

if [ "$ARCH" = "x86_64" ]; then
    URL="https://github.com/rustdesk/rustdesk/releases/download/1.4.6/rustdesk-1.4.6-x86_64.deb"
    info "Phát hiện CPU 64-bit (x86_64). Đang tải gói cài đặt tương thích..."
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    URL="https://github.com/rustdesk/rustdesk/releases/download/1.4.6/rustdesk-1.4.6-0-x86_64.pkg.tar.zst"
    info "Phát hiện CPU ARM 64-bit (aarch64). Đang tải gói cài đặt tương thích..."
else
    error "Kiến trúc CPU ($ARCH) không được RustDesk hỗ trợ chính thức qua bộ cài này."
fi

# Thực hiện tải file với thanh tiến trình trực quan
wget --show-progress -O "$RUSTDESK_DEB" "$URL"

if [ -f "$RUSTDESK_DEB" ] && [ -s "$RUSTDESK_DEB" ]; then
    echo -e "${OK_TAG} Tải gói bộ cài .deb thành công."
else
    REPORT_ERR+=("Tải bộ cài RustDesk (Thất bại, lỗi kết nối mạng)")
    error "Không thể tải file .deb từ trang chủ RustDesk."
fi

# ────────────────────────────────────────────────
# BƯỚC 3: TIẾN HÀNH TRIỂN KHAI CÀI ĐẶT GÓI HỆ THỐNG
# ────────────────────────────────────────────────
step 3 3 "Cài đặt gói phần mềm và xử lý thư viện phụ thuộc..."

info "Đang giải nén và cấu hình dịch vụ RustDesk..."
apt install "$RUSTDESK_DEB" -y &> /dev/null

# Tự động sửa lỗi đứt gãy thư viện nếu có (như xdotool, libxdo3, v.v...)
if [ $? -ne 0 ]; then
    warning "Phát hiện thiếu thư viện liên kết, đang tự động sửa lỗi (apt install -f)..."
    apt install -f -y &> /dev/null
fi

# Xóa file cài đặt tạm thời
rm -f "$RUSTDESK_DEB"

# Kiểm tra cuối cùng để xuất báo cáo
if command -v rustdesk &> /dev/null; then
    success "Cài đặt và cấu hình hệ thống RustDesk thành công!"
    REPORT_OK+=("Ứng dụng RustDesk Client (Triển khai thành công via APT)")
else
    REPORT_ERR+=("Ứng dụng RustDesk Client (Cài đặt thất bại ở bước đóng gói)")
fi

# ────────────────────────────────────────────────
# 📊 BẢNG TỔNG KẾT TIẾN TRÌNH CÀI ĐẶT CỤC BỘ (GIỐNG REMMINA)
# ────────────────────────────────────────────────
echo ""
echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}📊 BẢNG TỔNG KẾT TIẾN TRÌNH CÀI ĐẶT RUSTDESK:${NC}"
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

# Trả trạng thái kết thúc logic cho script tổng system-manager.sh
if [ ${#REPORT_ERR[@]} -eq 0 ]; then
    success "CÀI ĐẶT HOÀN TẤT THÀNH CÔNG!"
    info "Khởi chạy ứng dụng bằng cách gõ lệnh: rustdesk (hoặc tìm trong Application Menu)"
    exit 0
else
    error "Quá trình triển khai RustDesk có lỗi phát sinh."
    exit 1
fi
