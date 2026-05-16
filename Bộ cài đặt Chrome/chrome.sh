#!/bin/bash

# ============================================
#  Script Cài Đặt Google Chrome Tự Động
#  Định dạng chuẩn tích hợp hệ thống DevServerTP
# ============================================

# Màu sắc đồng bộ hệ thống chính
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Tag trạng thái chuẩn
OK_TAG="[  ${GREEN}OK${NC}  ]"
ERR_TAG="[${RED}ERROR${NC}]"

step() {
    echo ""
    echo -e "${BLUE}${BOLD}[BƯỚC $1/$2]${NC} ${BOLD}$3${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
}

success() { echo -e "${GREEN}✓ THÀNH CÔNG:${NC} $1"; }
error()   { echo -e "${RED}✗ LỖI:${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}⚠ LƯU Ý:${NC} $1"; }
info()    { echo -e "${CYAN}ℹ THÔNG TIN:${NC} $1"; }

# Kiểm tra quyền root (bắt buộc vì cài đặt gói hệ thống)
if [ "$EUID" -ne 0 ]; then
    error "Vui lòng chạy script bằng quyền root hoặc qua kịch bản quản lý tổng."
fi

echo -e "${CYAN}${BOLD}⏳ KHỞI ĐỘNG TIẾN TRÌNH CÀI ĐẶT GOOGLE CHROME...${NC}"

# ────────────────────────────────────────────────
# BƯỚC 1: KIỂM TRA TRẠNG THÁI HIỆN TẠI
# ────────────────────────────────────────────────
step 1 4 "Kiểm tra Google Chrome trên hệ thống..."

if command -v google-chrome &> /dev/null; then
    CHROME_VER=$(google-chrome --version)
    echo -e "$OK_TAG Google Chrome đã được cài đặt trước đó ($CHROME_VER)"
    warning "Hệ thống sẽ tiến hành cập nhật/cài đè để đảm bảo phiên bản mới nhất."
else
    info "Chưa phát hiện Google Chrome trên máy này. Bắt đầu quy trình cài mới."
fi

# ────────────────────────────────────────────────
# BƯỚC 2: CÀI ĐẶT CÁC GÓI PHỤ TRỢ CẦN THIẾT
# ────────────────────────────────────────────────
step 2 4 "Cập nhật kho ứng dụng & Cài đặt công cụ tải (wget/curl)..."

info "Đang cập nhật danh sách gói hệ thống (apt update)..."
apt update -y &> /dev/null

info "Đang đảm bảo các gói phụ trợ (wget, curl, apt-transport-https) được cài đặt..."
apt install wget curl apt-transport-https ca-certificates gnupg2 -y &> /dev/null

if [ $? -eq 0 ]; then
    echo -e "$OK_TAG Các công cụ phụ trợ đã sẵn sàng."
else
    error "Không thể cập nhật hoặc cài đặt các gói phụ trợ cần thiết."
fi

# ────────────────────────────────────────────────
# BƯỚC 3: TẢI VÀ THIẾT LẬP BỘ CÀI CHROME CHÍNH THỨC
# ────────────────────────────────────────────────
step 3 4 "Tải xuống gói cài đặt Google Chrome Stable (.deb)..."

CHROME_DEB="/tmp/google-chrome-stable_current_amd64.deb"

# Xóa file cũ nếu có để tránh lỗi bộ nhớ đệm
[ -f "$CHROME_DEB" ] && rm -f "$CHROME_DEB"

info "Đang tải bộ cài (.deb) trực tiếp từ máy chủ Google..."
wget -q --show-progress -O "$CHROME_DEB" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

if [ -f "$CHROME_DEB" ] && [ -s "$CHROME_DEB" ]; then
    echo -e "$OK_TAG Tải bộ cài Chrome thành công công đoạn lưu tạm."
else
    error "Tải xuống thất bại. Vui lòng kiểm tra lại kết nối mạng Internet."
fi

# ────────────────────────────────────────────────
# BƯỚC 4: TIẾN HÀNH TRIỂN KHAI CÀI ĐẶT VÀ HOÀN TẤT
# ────────────────────────────────────────────────
step 4 4 "Cài đặt gói ứng dụng vào hệ thống..."

info "Đang giải nén và cấu hình Google Chrome..."
apt install "$CHROME_DEB" -y &> /dev/null

# Xử lý sửa lỗi nếu dính thiếu thư viện phụ thuộc (dependency) phụ
if [ $? -ne 0 ]; then
    warning "Phát hiện thiếu thư viện liên kết, đang tự động sửa lỗi (apt install -f)..."
    apt install -f -y &> /dev/null
fi

# Dọn dẹp file cài đặt tạm thời sau khi xử lý xong
rm -f "$CHROME_DEB"

# Kiểm tra cuối cùng để xuất báo cáo
if command -v google-chrome &> /dev/null; then
    FINAL_VER=$(google-chrome --version)
    echo -e "$OK_TAG $FINAL_VER"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
    success "Cài đặt thành công Google Chrome phiên bản mới nhất!"
    info "Bạn có thể khởi chạy bằng lệnh 'google-chrome' hoặc tìm trong Menu ứng dụng."
else
    echo -e "$ERR_TAG Tiến trình cài đặt hoàn tất nhưng không tìm thấy thực thi."
    error "Cài đặt Google Chrome thất bại."
fi
