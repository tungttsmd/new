#!/bin/bash

# ============================================
#  Script Quản Lý Hệ Thống & Cài Đặt Tự Động
#  Hỗ trợ: Kiểm tra trạng thái + Menu cài đặt + Git Push Production
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

# Tag trạng thái chuẩn 7 ký tự thuần khoảng trắng
OK_TAG="[  ${GREEN}OK${NC}  ]"
EMPTY_TAG="[${YELLOW}EMPTY${NC}]"
ERR_TAG="[${RED}ERROR${NC}]"

print_main_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║                                                ║"
    echo "║          HỆ THỐNG QUẢN LÝ & CÀI ĐẶT TỰ ĐỘNG     ║"
    echo "║                  -- DevServerTP --             ║"
    echo "║                                                ║"
    echo "╚════════════════════════════════════════════════╝"
    echo "- Ngày cập nhật: 16/05/2026"
    echo -e "${NC}"
}

print_install_banner() {
    clear
    echo -e "${MAGENTA}${BOLD}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║                                                ║"
    echo "║        MENU CẤP QUYỀN & CHẠY TỰ ĐỘNG SCRIPT    ║"
    echo "║          Tự động nhận diện theo Thư mục        ║"
    echo "║                                                ║"
    echo "╚════════════════════════════════════════════════╝"
    echo "- Hãy chọn thư mục phần mềm cần triển khai"
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

# Hàm cắt ngắn chuỗi nếu quá dài (Tối đa 50 ký tự) để tránh vỡ màn hình
truncate_msg() {
    local text="$1"
    local max_len=50
    if [ ${#text} -gt $max_len ]; then
        echo "${text:0:$max_len}..."
    else
        echo "$text"
    fi
}

# Kiểm tra quyền root bắt buộc ngay từ đầu
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ LỖI: Vui lòng chạy script với quyền root (Sử dụng: sudo ./system-manager.sh)${NC}"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo ~$REAL_USER)
CURRENT_DIR="$(pwd)"

# ────────────────────────────────────────────────
# HÀM XỬ LÝ 1: KIỂM TRA TRẠNG THÁI HỆ THỐNG
# ────────────────────────────────────────────────
check_system_status() {
    clear
    echo -e "${CYAN}${BOLD}⏳ ĐANG TIẾN HÀNH QUÉT CÁC THÀNH PHẦN HỆ THỐNG...${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"

    declare -a REPORT_OK
    declare -a REPORT_EMPTY
    declare -a REPORT_ERR

    # 1. Kiểm tra Driver NVIDIA
    if command -v nvidia-smi &> /dev/null; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -n 1)
        DRIVER_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -n 1)
        MSG="Driver NVIDIA ($GPU_NAME, Ver: $DRIVER_VER)"
        
        # Cắt ngắn nếu thông tin tên GPU + Driver quá dài
        PRINT_MSG=$(truncate_msg "$MSG")
        echo -e "$OK_TAG $PRINT_MSG"
        REPORT_OK+=("$PRINT_MSG")
    else
        NOTE="Driver NVIDIA (Chưa được cài đặt hoặc chưa nạp Kernel)"
        PRINT_NOTE=$(truncate_msg "$NOTE")
        echo -e "$ERR_TAG $PRINT_NOTE"
        REPORT_ERR+=("$PRINT_NOTE")
    fi

    # 2. Kiểm tra Môi trường Desktop Cinnamon
    if command -v cinnamon-session &> /dev/null || dpkg -l | grep -q "cinnamon-core"; then
        if command -v cinnamon --version &> /dev/null; then
            CINNAMON_VER=$(cinnamon --version)
            MSG="Cinnamon Desktop ($CINNAMON_VER)"
        else
            MSG="Cinnamon Desktop (Phát hiện qua gói core)"
        fi
        PRINT_MSG=$(truncate_msg "$MSG")
        echo -e "$OK_TAG $PRINT_MSG"
        REPORT_OK+=("$PRINT_MSG")
    else
        NOTE="Cinnamon Desktop (Chưa được cài đặt trên hệ thống)"
        PRINT_NOTE=$(truncate_msg "$NOTE")
        echo -e "$ERR_TAG $PRINT_NOTE"
        REPORT_ERR+=("$PRINT_NOTE")
    fi

    # 3. Kiểm tra Ứng dụng Remmina
    REMMINA_INSTALLED=false
    if command -v remmina &> /dev/null; then
        REMMINA_INSTALLED=true
        REMMINA_VER=$(remmina --version 2>&1 | head -n 1)
        MSG="Ứng dụng Remmina Client ($REMMINA_VER)"
        PRINT_MSG=$(truncate_msg "$MSG")
        echo -e "$OK_TAG $PRINT_MSG"
        REPORT_OK+=("$PRINT_MSG")
    elif command -v flatpak &> /dev/null && flatpak list | grep -iq remmina; then
        REMMINA_INSTALLED=true
        MSG="Ứng dụng Remmina Client (Cài qua Flatpak)"
        PRINT_MSG=$(truncate_msg "$MSG")
        echo -e "$OK_TAG $PRINT_MSG"
        REPORT_OK+=("$PRINT_MSG")
    else
        NOTE="Ứng dụng Remmina Client (Chưa được cài đặt)"
        PRINT_NOTE=$(truncate_msg "$NOTE")
        echo -e "$ERR_TAG $PRINT_NOTE"
        REPORT_ERR+=("$PRINT_NOTE")
    fi

    # 4. Kiểm tra các Plugin của Remmina
    if [ "$REMMINA_INSTALLED" = true ]; then
        REMMINA_PLUGINS=$(dpkg -l | grep remmina-plugin | awk '{print $2}' | tr '\n' ' ')
        if [[ -n "$REMMINA_PLUGINS" ]]; then
            if [[ "$REMMINA_PLUGINS" == *"rdp"* ]]; then
                MSG="Plugin Remmina RDP (Đã sẵn sàng)"
                PRINT_MSG=$(truncate_msg "$MSG")
                echo -e "$OK_TAG $PRINT_MSG"
                REPORT_OK+=("$PRINT_MSG")
            else
                NOTE="Plugin Remmina RDP (Thiếu gói remmina-plugin-rdp)"
                PRINT_NOTE=$(truncate_msg "$NOTE")
                echo -e "$ERR_TAG $PRINT_NOTE"
                REPORT_ERR+=("$PRINT_NOTE")
            fi
        else
            if command -v flatpak &> /dev/null && flatpak list | grep -iq remmina; then
                MSG="Plugin Remmina RDP (Tích hợp sẵn trong Flatpak)"
                PRINT_MSG=$(truncate_msg "$MSG")
                echo -e "$OK_TAG $PRINT_MSG"
                REPORT_OK+=("$PRINT_MSG")
            else
                NOTE="Plugin Remmina (Không tìm thấy plugin nào qua APT)"
                PRINT_NOTE=$(truncate_msg "$NOTE")
                echo -e "$EMPTY_TAG $PRINT_NOTE"
                REPORT_EMPTY+=("$PRINT_NOTE")
            fi
        fi
    else
        NOTE="Plugin Remmina (Bỏ qua do chưa cài app chính)"
        PRINT_NOTE=$(truncate_msg "$NOTE")
        echo -e "$EMPTY_TAG $PRINT_NOTE"
        REPORT_EMPTY+=("$PRINT_NOTE")
    fi

    # 5. Kiểm tra Hồ sơ kết nối (Profiles) trong Remmina
    REMMINA_CONF_DIR="$USER_HOME/.local/share/remmina"
    if [ -d "$REMMINA_CONF_DIR" ]; then
        PROFILE_COUNT=$(ls -1 "$REMMINA_CONF_DIR"/*.remmina 2>/dev/null | wc -l)
        if [ "$PROFILE_COUNT" -gt 0 ]; then
            MSG="Profile Remmina (Có $PROFILE_COUNT kết nối của '$REAL_USER')"
            PRINT_MSG=$(truncate_msg "$MSG")
            echo -e "$OK_TAG $PRINT_MSG"
            REPORT_OK+=("$PRINT_MSG")
        else
            NOTE="Profile Remmina (Thư mục trống, chưa lưu kết nối)"
            PRINT_NOTE=$(truncate_msg "$NOTE")
            echo -e "$EMPTY_TAG $PRINT_NOTE"
            REPORT_EMPTY+=("$PRINT_NOTE")
        fi
    else
        NOTE="Profile Remmina (User chưa từng khởi chạy app)"
        PRINT_NOTE=$(truncate_msg "$NOTE")
        echo -e "$EMPTY_TAG $PRINT_NOTE"
        REPORT_EMPTY+=("$PRINT_NOTE")
    fi

    # BẢNG THỐNG KÊ TỔNG KẾT HỆ THỐNG
    echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}📊 BẢNG TỔNG KẾT TRẠNG THÁI HỆ THỐNG:${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}[✓] CÁC THÀNH PHẦN HOẠT ĐỘNG TỐT (OK):${NC}"
    if [ ${#REPORT_OK[@]} -eq 0 ]; then echo -e "  (Không có)"; else
        for item in "${REPORT_OK[@]}"; do echo -e "  └── $OK_TAG $item"; done
    fi
    echo ""
    echo -e "${YELLOW}${BOLD}[⚠] CÁC THÀNH PHẦN CHƯA KHỞI TẠO (EMPTY):${NC}"
    if [ ${#REPORT_EMPTY[@]} -eq 0 ]; then echo -e "  (Không có)"; else
        for item in "${REPORT_EMPTY[@]}"; do echo -e "  └── $EMPTY_TAG $item"; done
    fi
    echo ""
    echo -e "${RED}${BOLD}[✗] CÁC THÀNH PHẦN LỖI / CHƯA CÀI ĐẶT (ERROR):${NC}"
    if [ ${#REPORT_ERR[@]} -eq 0 ]; then echo -e "  🎉 Tuyệt vời! Không phát hiện lỗi nào."; else
        for item in "${REPORT_ERR[@]}"; do echo -e "  └── $ERR_TAG $item"; done
    fi
    echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
    echo -e -n "${YELLOW}Nhấn [Enter] để quay lại Menu chính...${NC}"
    read -r
}

# ────────────────────────────────────────────────
# HÀM XỬ LÝ 2: CÀI ĐẶT PHẦN MỀM THEO THƯ MỤC TỰ ĐỘNG
# ────────────────────────────────────────────────
software_installer_menu() {
    while true; do
        print_install_banner
        detect "Thư mục gốc hiện tại: ${BOLD}$CURRENT_DIR${NC}"
        echo ""
        echo -e "${BOLD}DANH SÁCH THƯ MỤC CÓ THỂ CẤP QUYỀN & TRIỂN KHAI:${NC}"
        echo -e "${BLUE}────────────────────────────────────────────────${NC}"

        declare -a DIR_LIST
        DIR_COUNT=0
        
        while IFS= read -r -d '' dir; do
            DIR_NAME=$(basename "$dir")
            if [ "$DIR_NAME" != ".git" ]; then
                ((DIR_COUNT++))
                DIR_LIST[$DIR_COUNT]="$dir"
                echo -e "  ${CYAN}${BOLD}$DIR_COUNT.${NC} $DIR_NAME"
            fi
        done < <(find "$CURRENT_DIR" -maxdepth 1 -type d ! -path "$CURRENT_DIR" -print0 | sort -z)

        ALL_OPTION=$((DIR_COUNT + 1))
        BACK_OPTION=$((DIR_COUNT + 2))
        
        echo -e "  ${YELLOW}${BOLD}$ALL_OPTION.${NC} ${YELLOW}Chạy TẤT CẢ thư mục${NC}"
        echo -e "  ${RED}${BOLD}$BACK_OPTION.${NC} ${RED}Quay lại Menu chính${NC}"
        echo -e "${BLUE}────────────────────────────────────────────────${NC}"
        
        echo -e -n "👉 Nhập lựa chọn của bạn (1-$BACK_OPTION): "
        read TARGET_CHOICE

        if ! [[ "$TARGET_CHOICE" =~ ^[0-9]+$ ]] || [ "$TARGET_CHOICE" -lt 1 ] || [ "$TARGET_CHOICE" -gt "$BACK_OPTION" ]; then
            warning "Lựa chọn không hợp lệ! Vui lòng nhấn Enter để chọn lại."
            read -r
            continue
        fi

        if [ "$TARGET_CHOICE" -eq "$BACK_OPTION" ]; then
            return
        fi

        declare -a SCAN_TARGETS
        if [ "$TARGET_CHOICE" -eq "$ALL_OPTION" ]; then
            for i in "${!DIR_LIST[@]}"; do SCAN_TARGETS+=("${DIR_LIST[$i]}"); done
            TARGET_LABEL="TẤT CẢ các thư mục"
        else
            SCAN_TARGETS+=("${DIR_LIST[$TARGET_CHOICE]}")
            TARGET_LABEL=$(basename "${DIR_LIST[$TARGET_CHOICE]}")
        fi

        # Quét tệp tin .sh
        step 1 3 "Quét tìm kiếm các file thực thi .sh..."
        declare -a FILE_LIST
        TOTAL_FILES=0

        for target in "${SCAN_TARGETS[@]}"; do
            while IFS= read -r -d '' file; do
                if [[ "$file" == *"$0" ]]; then continue; fi
                FILE_LIST+=("$file")
                ((TOTAL_FILES++))
            done < <(find "$target" -type f -name "*.sh" -print0)
        done

        if [ $TOTAL_FILES -gt 0 ]; then
            success "Tìm thấy tổng cộng ${BOLD}$TOTAL_FILES${NC} tệp tin script đuôi .sh"
        else
            warning "Không tìm thấy file '.sh' nào trong mục tiêu đã chọn."
            echo -e -n "${YELLOW}Nhấn [Enter] để tiếp tục...${NC}"
            read -r
            continue
        fi

        # Cấp quyền chmod
        step 2 3 "Áp dụng quyền thực thi (chmod +x)..."
        for file in "${FILE_LIST[@]}"; do
            RELATIVE_PATH="${file#$CURRENT_DIR/}"
            info "Cấp quyền: ${CYAN}$RELATIVE_PATH${NC}"
            chmod +x "$file" 2>/dev/null
        done

        # Chạy file trực tiếp bằng Sudo
        step 3 3 "Kích hoạt thực thi script bằng quyền Root..."
        declare -a REPORT_OK
        declare -a REPORT_FAIL
        
        for file in "${FILE_LIST[@]}"; do
            RELATIVE_PATH="${file#$CURRENT_DIR/}"
            echo -e "${BLUE}────────────────────────────────────────────────${NC}"
            info "Bắt đầu khởi chạy dịch vụ: ${MAGENTA}${BOLD}$RELATIVE_PATH${NC}"
            echo -e "${BLUE}────────────────────────────────────────────────${NC}"
            
            START_RUN_DIR="$(pwd)"
            SCRIPT_DIR=$(dirname "$file")
            SCRIPT_NAME=$(basename "$file")
            
            cd "$SCRIPT_DIR" || continue
            ./"$SCRIPT_NAME"
            
            if [ $? -eq 0 ]; then
                REPORT_OK+=("$RELATIVE_PATH")
            else
                REPORT_FAIL+=("$RELATIVE_PATH")
            fi
            cd "$START_RUN_DIR" || exit
        done

        # Bảng tổng kết của lượt chạy cài đặt
        echo ""
        echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
        echo -e "${BOLD}📊 BẢNG TỔNG KẾT TIẾN TRÌNH CÀI ĐẶT:${NC}"
        echo ""
        echo -e "${GREEN}${BOLD}[✓] CÁC SCRIPT VẬN HÀNH THÀNH CÔNG (OK):${NC}"
        if [ ${#REPORT_OK[@]} -eq 0 ]; then echo -e "  (Không có)"; else
            for item in "${REPORT_OK[@]}"; do echo -e "  └── $OK_TAG $item"; done
        fi
        echo ""
        echo -e "${RED}${BOLD}[✗] CÁC SCRIPT GẶP LỖI THỰC THI (FAIL):${NC}"
        if [ ${#REPORT_FAIL[@]} -eq 0 ]; then echo -e "  🎉 Hoàn hảo! Không có script nào bị lỗi."; else
            for item in "${REPORT_FAIL[@]}"; do echo -e "  └── $ERR_TAG $item"; done
        fi
        echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
        echo -e -n "${YELLOW}Nhấn [Enter] để quay lại Menu quản lý...${NC}"
        read -r
    done
}

# ────────────────────────────────────────────────
# HÀM XỬ LÝ 3: ĐẨY MÃ NGUỒN LÊN PRODUCTION (QUY TRÌNH CHUẨN)
# ────────────────────────────────────────────────
git_push_production() {
    clear
    echo -e "${CYAN}${BOLD}🚀 TIẾN TRÌNH TỰ ĐỘNG HÓA GIT & PUSH PRODUCTION...${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"

    # 1. Kiểm tra thư mục có thuộc một Git Repository hay không
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        echo -e "${RED}✗ LỖI: Thư mục hiện tại chưa khởi tạo Git hoặc không nằm trong một kho lưu trữ Git nào.${NC}"
        echo -e -n "${YELLOW}Nhấn [Enter] để quay lại...${NC}"
        read -r
        return
    fi

    # 2. Tự động kiểm tra và thêm Remote URL nếu thiếu 'origin'
    if ! git remote | grep -q "^origin$"; then
        info "Không tìm thấy remote 'origin'. Tự động cấu hình liên kết đến kho chứa..."
        sudo -u "$REAL_USER" git remote add origin https://github.com/tungttsmd/new
        if [ $? -eq 0 ]; then
            success "Đã thiết lập Remote: origin -> https://github.com/tungttsmd/new"
        else
            error "Không thể cấu hình remote origin tự động."
        fi
    fi

    # 3. Hiển thị trạng thái Git Status hiện tại (Trước khi commit)
    echo ""
    echo -e "${BOLD}📊 TRẠNG THÁI TỆP TIN TRƯỚC KHI COMMIT (GIT STATUS):${NC}"
    echo -e "${BLUE}-----------------------------------------------------------------${NC}"
    sudo -u "$REAL_USER" git status -s
    echo -e "${BLUE}-----------------------------------------------------------------${NC}"

    # 4. Đọc commit gần nhất để parse phiên bản và tăng Patch version
    LAST_COMMIT=$(sudo -u "$REAL_USER" git log -1 --pretty=%B 2>/dev/null | xargs)
    NEW_COMMIT="linux-toolkit-1.0.0" # Mặc định ban đầu nếu chưa có commit nào đúng chuẩn

    if [[ "$LAST_COMMIT" =~ linux-toolkit-([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        MAJOR="${BASH_REMATCH[1]}"
        MINOR="${BASH_REMATCH[2]}"
        PATCH="${BASH_REMATCH[3]}"
        
        # Tăng phiên bản Patch lên 1 đơn vị
        NEXT_PATCH=$((PATCH + 1))
        NEW_COMMIT="linux-toolkit-${MAJOR}.${MINOR}.${NEXT_PATCH}"
        detect "Phát hiện commit cũ: ${YELLOW}$LAST_COMMIT${NC} -> Khởi tạo mã commit mới: ${GREEN}$NEW_COMMIT${NC}"
    else
        warning "Không tìm thấy commit cũ đúng định dạng. Hệ thống tự thiết lập: ${GREEN}$NEW_COMMIT${NC}"
    fi

    # 5. Thực hiện đóng gói dữ liệu (Git Add & Git Commit)
    if [[ -n $(sudo -u "$REAL_USER" git status --porcelain) ]]; then
        info "Phát hiện có sự thay đổi dữ liệu. Tiến hành tự động add và commit..."
        sudo -u "$REAL_USER" git add .
        sudo -u "$REAL_USER" git commit -m "$NEW_COMMIT"
        success "Đã tạo thành công phiên bản commit cục bộ!"
    else
        info "Không có tệp tin nào thay đổi mới. Giữ nguyên commit gần nhất."
    fi

    # 6. HIỂN THỊ CHI TIẾT (SHOW DETAIL) COMMIT CHUẨN BỊ PUSH
    echo ""
    echo -e "${BOLD}🔍 CHI TIẾT COMMIT SẼ ĐẨY LÊN PRODUCTION (GIT SHOW DETAIL):${NC}"
    echo -e "${BLUE}=================================================================${NC}"
    # Show log thu gọn và danh sách file thay đổi của commit hiện tại
    sudo -u "$REAL_USER" git show --stat --oneline HEAD
    echo -e "${BLUE}=================================================================${NC}"

    # 7. Hỏi xác nhận cuối cùng để thực hiện Push Production
    echo ""
    echo -e -n "${YELLOW}❓ Xác nhận hiển thị OK. Bạn có muốn PUSH commit này lên Production không? (y/N): ${NC}"
    read -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        warning "Tiến trình đẩy mã nguồn Git Push đã bị hủy bỏ bởi người dùng."
        echo -e -n "${YELLOW}Nhấn [Enter] để quay lại...${NC}"
        read -r
        return
    fi

    echo ""
    echo -e "${BLUE}⏳ Đang thực thi lệnh: git push origin production:production...${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"

    # Thực hiện lệnh đẩy chính xác sử dụng tài khoản thực thi gốc
    sudo -u "$REAL_USER" git push origin production:production

    if [ $? -eq 0 ]; then
        echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
        success "Đồng bộ đồng nhất nhánh production lên máy chủ GitHub hoàn tất hoàn hảo!"
    else
        echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
        echo -e "${RED}✗ LỖI: Tiến trình Git Push thất bại. Vui lòng kiểm tra lại quyền truy cập hoặc cấu hình nhánh.${NC}"
    fi

    echo -e -n "${YELLOW}Nhấn [Enter] để quay lại Menu chính...${NC}"
    read -r
}

# ────────────────────────────────────────────────
# VÒNG LẶP MENU CHÍNH (MỚI VÀO)
# ────────────────────────────────────────────────
while true; do
    print_main_banner
    echo -e "${BOLD}VUI LÒNG CHỌN PHƯƠNG THỨC TRIỂN KHAI:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}${BOLD}1.${NC} Kiểm tra trạng thái cài đặt hệ thống"
    echo -e "  ${CYAN}${BOLD}2.${NC} Cài đặt phần mềm (Quét theo thư mục con)"
    echo -e "  ${CYAN}${BOLD}3.${NC} Đẩy mã nguồn lên Git (Push to Production)"
    echo -e "  ${RED}${BOLD}4.${NC} Thoát chương trình"
    echo -e "${BLUE}────────────────────────────────────────────────${NC}"
    echo -e -n "👉 Nhập lựa chọn của bạn (1-4): "
    read MAIN_CHOICE

    case "$MAIN_CHOICE" in
        1)
            check_system_status
            ;;
        2)
            software_installer_menu
            ;;
        3)
            git_push_production
            ;;
        4)
            echo -e "${GREEN}Tạm biệt! Cảm ơn bạn đã sử dụng script của DevServerTP.${NC}"
            exit 0
            ;;
        *)
            warning "Lựa chọn không hợp lệ! Vui lòng nhấn Enter để chọn lại."
            read -r
            ;;
    esac
done
