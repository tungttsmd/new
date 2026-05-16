#!/bin/bash

# ============================================
#  Script Tự Động Xác Thực Git & GitHub Toàn Cục
#  Sử dụng GitHub CLI chính thức (Bản mượt không lỗi Sudo)
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
ERR_TAG="[ ${RED}ERROR${NC} ]"

# Mảng lưu trữ trạng thái phục vụ bảng tổng kết cuối file
declare -a REPORT_OK
declare -a REPORT_ERR

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║                                                ║"
    echo "║       TRÌNH XÁC THỰC GITHUB OAUTH TOÀN CỤC     ║"
    echo "║    Cấu hình danh tính và xác thực thiết bị     ║"
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
# 1. KIỂM TRA PHÂN QUYỀN
# ────────────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
    print_banner
    echo -e "${RED}─────────────────────────────────────────────────────────────────${NC}"
    echo -e "${RED}${BOLD}📌 Không dùng lệnh sudo ./web-auth.sh cho file này :${NC}"
    echo -e "  * Bạn đang kích hoạt script này dưới quyền ${BOLD}'sudo' (root)${NC}."
    echo -e "  * Linux chặn 'root' tự ý khởi chạy trình duyệt Firefox/Chrome."
    echo -e "${GREEN}${BOLD}🚀 Khắc phục:${NC}"
    echo -e "  * Chạy trực tiếp (không sudo, không qua file.sh khác): ${CYAN}${BOLD}./web-auth.sh${NC}"
    echo -e "${RED}─────────────────────────────────────────────────────────────────${NC}"
    exit 1
fi

print_banner
REAL_USER="${SUDO_USER:-$USER}"
detect "Tài khoản thực thi: ${BOLD}$REAL_USER${NC}"

# ────────────────────────────────────────────────
# 2. CẤU HÌNH USERNAME VÀ EMAIL GIT
# ────────────────────────────────────────────────
step 1 3 "Cấu hình định danh danh tính Git (User & Email)..."

CURRENT_GIT_USER=$(git config --global user.name)
CURRENT_GIT_EMAIL=$(git config --global user.email)

if [ -z "$CURRENT_GIT_USER" ] || [ -z "$CURRENT_GIT_EMAIL" ]; then
    warning "Hệ thống chưa thiết lập danh tính cấu hình Git toàn cục."
    
    while [ -z "$GIT_EMAIL_INPUT" ]; do
        echo -e "${BOLD}📝 Nhập Email Git của bạn (Ví dụ: ban@example.com):${NC}"
        read -r GIT_EMAIL_INPUT
    done
    
    while [ -z "$GIT_NAME_INPUT" ]; do
        echo -e "${BOLD}📝 Nhập Tên hiển thị Git (Ví dụ: Nguyen Van A):${NC}"
        read -r GIT_NAME_INPUT
    done

    git config --global user.email "$GIT_EMAIL_INPUT"
    git config --global user.name "$GIT_NAME_INPUT"
    
    success "Đã cấu hình Git toàn cục: ${CYAN}$GIT_NAME_INPUT ($GIT_EMAIL_INPUT)${NC}"
    REPORT_OK+=("Cấu hình danh tính Git (Thiết lập mới global)")
else
    info "Danh tính Git toàn cục đã có sẵn trên thiết bị."
    detect "Email: ${BOLD}$CURRENT_GIT_EMAIL${NC} | Tên: ${BOLD}$CURRENT_GIT_USER${NC}"
    REPORT_OK+=("Cấu hình danh tính Git (Sử dụng lại cấu hình cũ)")
fi

# ────────────────────────────────────────────────
# 3. KIỂM TRA VÀ CÀI ĐẶT CÔNG CỤ PHỤ THUỘC
# ────────────────────────────────────────────────
step 2 3 "Kiểm tra môi trường hệ thống..."

if ! command -v gh &> /dev/null || ! command -v jq &> /dev/null; then
    warning "Thiếu công cụ 'gh' hoặc 'jq'. Đang tự động cài đặt..."
    sudo apt update && sudo apt install gh jq -y
    
    if ! command -v gh &> /dev/null || ! command -v jq &> /dev/null; then
        error "Không thể cài đặt tự động GitHub CLI. Vui lòng kiểm tra lại cấu hình APT."
    fi
    success "Cài đặt các gói phụ thuộc thành công!"
    REPORT_OK+=("Môi trường hệ thống (Cài đặt mới công cụ)")
else
    info "Các công cụ bắt buộc (gh, jq) đã sẵn sàng."
    REPORT_OK+=("Môi trường hệ thống (Công cụ có sẵn)")
fi

# ────────────────────────────────────────────────
# 4. TIẾN TRÌNH XÁC THỰC OAUTH WEB FLOW TOÀN CỤC
# ────────────────────────────────────────────────
step 3 3 "Xác thực tài khoản qua Trình duyệt Web..."

if ! gh auth status &> /dev/null; then
    info "Chưa có phiên đăng nhập. Đang gọi trình duyệt xác thực..."
    if gh auth login --web -h github.com -s repo; then
        # ĐÃ SỬA: Bỏ --global tại đây vì gh mặc định ghi vào cấu hình global toàn hệ thống
        gh auth setup-git
        success "Xác thực và ghi nhận Credential Helper toàn cục thành công!"
        REPORT_OK+=("Xác thực người dùng (Đăng nhập mới + Cấu hình Helper)")
    else
        error "Tiến trình xác thực bị hủy bỏ bởi người dùng."
    fi
else
    # ĐÃ SỬA: Bỏ --global tại đây để tránh lỗi 'unknown flag'
    gh auth setup-git
    success "Tài khoản đã đăng nhập từ trước. Đã kiểm tra cấu hình Helper toàn cục."
    REPORT_OK+=("Xác thực người dùng (Sử dụng phiên cũ + Ghim Helper)")
fi

GITHUB_USER=$(gh api user 2>/dev/null | jq -r '.login')
detect "Tài khoản GitHub hiện hành: ${BOLD}$GITHUB_USER${NC}"

# ────────────────────────────────────────────────
# BẢNG THỐNG KÊ TỔNG KẾT
# ────────────────────────────────────────────────
echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}📊 BẢNG TỔNG KẾT TIẾN TRÌNH THIẾT LẬP GITHUB:${NC}"
echo ""

# 1. Thành công
echo -e "${GREEN}${BOLD}[✓] CÁC THÀNH PHẦN HOẠT ĐỘNG TỐT (OK):${NC}"
for item in "${REPORT_OK[@]}"; do
    echo -e "  └── $OK_TAG $item"
done
echo ""

# 2. Thông báo trạng thái cuối
if [ ${#REPORT_ERR[@]} -eq 0 ]; then
    echo -e "${GREEN}🎉 Tuyệt vời! Máy tính đã được thiết lập Auth toàn cục.${NC}"
    echo -e "${CYAN}💡 Bây giờ bạn có thể di chuyển đến bất kỳ thư mục mã nguồn nào,${NC}"
    echo -e "${CYAN}   chạy 'git push/pull' hoặc 'git clone' bằng HTTPS mà không cần mật khẩu.${NC}"
fi

echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}${BOLD}✓ TOÀN BỘ TIẾN TRÌNH XỬ LÝ HOÀN TẤT!${NC}"
echo ""
