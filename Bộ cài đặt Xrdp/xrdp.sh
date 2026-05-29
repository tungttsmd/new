#!/bin/bash

# ============================================
#  Trình cài đặt và Cấu hình XRDP cho Cinnamon
#  Hỗ trợ: Debian / Ubuntu
#  DevServerTP
# ============================================

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║                                                ║"
    echo "║      TRÌNH CÀI ĐẶT CẤU HÌNH MÁY CHỦ XRDP       ║"
    echo "║       Bộ gõ xrdp dành cho Debian/Ubuntu        ║"
    echo "║                                                ║"
    echo "║              -- DevServerTP --                 ║"
    echo "║                                                ║"
    echo "╚════════════════════════════════════════════════╝"
    echo "- Ngày cập nhật: 16/05/2026"
    echo -e "${NC}"
}

step() {
    echo ""
    echo -e "${BLUE}${BOLD}[BƯỚC $1/6]${NC} ${BOLD}$2${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
}

success() { echo -e "${GREEN}✓ THÀNH CÔNG:${NC} $1"; }
error()   { echo -e "${RED}✗ LỖI:${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}⚠ LƯU Ý:${NC} $1"; }
info()    { echo -e "${CYAN}ℹ THÔNG TIN:${NC} $1"; }

# ────────────────────────────────────────────────
# Bước 1: Kiểm tra quyền root (Thay cho lệnh su)
# ────────────────────────────────────────────────
print_banner
if [ "$EUID" -ne 0 ]; then
    error "Vui lòng chạy script với quyền root hoặc sudo. (Sử dụng: sudo ./install-xrdp-cinnamon.sh)"
fi
success "Đang chạy với quyền quản trị (Root/Sudo)."

# ────────────────────────────────────────────────
# Bước 2: Cập nhật danh sách gói (apt update)
# ────────────────────────────────────────────────
step 1 "Cập nhật danh sách kho lưu trữ hệ thống..."
info "Đang thực thi apt update..."
if apt update; then
    success "Cập nhật danh sách gói hoàn tất."
else
    error "Không thể cập nhật danh sách gói. Kiểm tra lại kết nối mạng."
fi

# ────────────────────────────────────────────────
# Bước 3: Cài đặt dịch vụ XRDP
# ────────────────────────────────────────────────
step 2 "Cài đặt máy chủ XRDP..."
info "Đang tải và cài đặt gói xrdp..."
if apt install xrdp -y; then
    success "Cài đặt XRDP thành công."
else
    error "Thất bại khi cài đặt XRDP."
fi

# ────────────────────────────────────────────────
# Bước 4: Thêm xrdp vào nhóm ssl-cert & kích hoạt dịch vụ
# ────────────────────────────────────────────────
step 3 "Cấu hình phân quyền và Khởi động dịch vụ..."

info "Thêm user xrdp vào nhóm ssl-cert để tránh lỗi màn hình đen..."
if adduser xrdp ssl-cert; then
    success "Đã thêm xrdp vào ssl-cert."
else
    warning "Không thể thêm hoặc user xrdp đã thuộc nhóm ssl-cert từ trước."
fi

info "Kích hoạt dịch vụ XRDP khởi động cùng hệ thống..."
systemctl enable --now xrdp
if [ $(systemctl is-active xrdp) = "active" ]; then
    success "Dịch vụ XRDP đã được bật và đang chạy."
else
    error "Không thể khởi động dịch vụ XRDP."
fi

# ────────────────────────────────────────────────
# Bước 5: Đổi Port XRDP (Tự động thay cho việc sửa bằng nano)
# ────────────────────────────────────────────────
step 4 "Cấu hình thay đổi Cổng kết nối (Port)..."
echo -e -n "${YELLOW}${BOLD}Nhập số Port mới bạn muốn đổi (Mặc định là 3389, nhấn Enter để giữ nguyên): ${NC}"
read NEW_PORT

if [ -z "$NEW_PORT" ]; then
    NEW_PORT="3389"
    info "Giữ nguyên port mặc định: 3389"
else
    # Kiểm tra xem port nhập vào có phải là số hợp lệ không
    if [[ "$NEW_PORT" =~ ^[0-9]+$ ]] && [ "$NEW_PORT" -ge 1 ] && [ "$NEW_PORT" -le 65535 ]; then
        info "Đang tiến hành đổi port sang: $NEW_PORT trong /etc/xrdp/xrdp.ini..."
        # Backup trước khi sửa
        cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak
        # Thay thế dòng port=3389 bằng port=NEW_PORT
        sed -i "s/^port=3389/port=$NEW_PORT/g" /etc/xrdp/xrdp.ini
        success "Đã cập nhật cấu hình port mới thành công."
    else
        warning "Port không hợp lệ (Phải từ 1-65535). Giữ nguyên port mặc định 3389."
        NEW_PORT="3389"
    fi
fi

# Cấu hình tối ưu riêng cho Cinnamon để tránh lỗi màn hình trống/treo khi remote
REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo ~$REAL_USER)
echo "cinnamon-session" > "$USER_HOME/.xsession"
chown "$REAL_USER:$REAL_USER" "$USER_HOME/.xsession"
chmod +x "$USER_HOME/.xsession"
info "Đã cấu hình file khởi chạy .xsession cho môi trường Cinnamon của user '$REAL_USER'."

info "Đang khởi động lại dịch vụ XRDP để áp dụng cài đặt..."
systemctl restart xrdp
success "Áp dụng cấu hình hoàn tất."

# ────────────────────────────────────────────────
# Bước 6: Hướng dẫn cấu hình IP tĩnh thủ công và Logout
# ────────────────────────────────────────────────
step 5 "HƯỚNG DẪN THIẾT LẬP IP TĨNH (STATIC IP)"
echo -e "${CYAN}Vui lòng thực hiện thủ công ngoài giao diện Desktop theo các bước sau:${NC}"
echo -e " 1. Mở ${BOLD}Network Settings${NC} (Cài đặt mạng) trên máy."
echo -e " 2. Chọn icon ${BOLD}Bánh răng${NC} cạnh mạng đang kết nối."
echo -e " 3. Chọn thẻ ${BOLD}IPv4${NC}."
echo -e " 4. Tại dòng Method (Phương thức), chọn ${BOLD}Manual${NC} (Thủ công) trong menu thả xuống."
echo -e " 5. Nhập các thông số mạng của bạn: ${BOLD}Address${NC} (IP máy), ${BOLD}Netmask${NC}, ${BOLD}Gateway${NC}."
echo -e " 6. Tại ô DNS, điền IP DNS của bạn vào mục ${BOLD}Preferred DNS Server${NC} (Ví dụ: 8.8.8.8)."
echo -e " 7. Nhấn ${GREEN}${BOLD}Apply${NC} để lưu lại."

step 6 "HOÀN TẤT VÀ KIỂM TRA"
echo -e "${RED}${BOLD}🚨 LƯU Ý BẮT BUỘC KHÔNG ĐƯỢC QUÊN: 🚨${NC}"
echo -e " Bạn ${RED}${BOLD}PHẢI LOGOUT (ĐĂNG XUẤT)${NC} tài khoản hiện tại ra khỏi máy chủ này trước."
echo -e " Nếu bạn vẫn đang đăng nhập trực tiếp trên máy, khi bạn dùng máy khác remote vào sẽ bị lỗi ${RED}Màn hình xanh/Đen/Tự văng${NC}."
echo ""
echo -e "👉 Địa chỉ kết nối từ máy khác: ${GREEN}${BOLD}IP_CỦA_BẠN:$NEW_PORT${NC}"
echo -e "-----------------------------------------------------------------"

read -p "Bạn có muốn ĐĂNG XUẤT (Logout) hệ thống ngay bây giờ để thử remote không? (y/N): " logout_now
if [[ "$logout_now" =~ ^[Yy]$ ]]; then
    info "Đang tiến hành đăng xuất người dùng..."
    sleep 1
    pkill -u "$REAL_USER"
fi
