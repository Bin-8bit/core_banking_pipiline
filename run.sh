set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

VENV_DIR="venv"
PYTHON_BIN="${PYTHON_BIN:-python3}"

# Màu cho output
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------------------------------------------------------------------
activate_venv() {
  if [[ ! -d "${VENV_DIR}" ]]; then
    err "Chưa có virtual environment. Chạy trước: ./run.sh setup"
    exit 1
  fi
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
}

check_env_file() {
  if [[ ! -f ".env" ]]; then
    err "Không tìm thấy file .env"
    err "Chạy: cp .env.example .env  rồi điền thông tin đăng nhập vào đó."
    exit 1
  fi
}

# ---------------------------------------------------------------------
cmd_setup() {
  info "Bắt đầu setup project..."

  if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
    err "Không tìm thấy ${PYTHON_BIN}. Hãy cài Python 3.9+ trước."
    exit 1
  fi
  info "Python: $(${PYTHON_BIN} --version)"

  if [[ ! -d "${VENV_DIR}" ]]; then
    info "Tạo virtual environment tại ./${VENV_DIR}"
    "${PYTHON_BIN}" -m venv "${VENV_DIR}"
    ok "Đã tạo venv."
  else
    warn "venv đã tồn tại, bỏ qua bước tạo."
  fi

  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"

  info "Cài đặt dependencies từ requirements.txt..."
  pip install --upgrade pip --quiet
  pip install -r requirements.txt --quiet
  ok "Đã cài xong dependencies."

  if [[ ! -f ".env" ]]; then
    cp .env.example .env
    ok "Đã tạo file .env từ .env.example"
    warn "HÃY MỞ FILE .env VÀ ĐIỀN: PG_USER, PG_PASSWORD, GCP_PROJECT_ID"
  else
    warn "File .env đã tồn tại, không ghi đè."
  fi

  mkdir -p logs

  echo ""
  ok "Setup hoàn tất."
  echo ""
  echo "Các bước tiếp theo:"
  echo "  1. Điền thông tin vào file .env"
  echo "  2. Đăng nhập Google Cloud (cho thư viện Python):"
  echo "       gcloud auth application-default login"
  echo "  3. Kiểm tra kết nối:  ./run.sh check"
  echo "  4. Chạy pipeline:     ./run.sh run"
}

cmd_check() {
  activate_venv
  check_env_file
  info "Chạy chế độ dry-run: kiểm tra kết nối + đếm dòng, KHÔNG ghi lên BigQuery"
  python main.py --dry-run
}

cmd_tables() {
  activate_venv
  check_env_file
  info "Tạo dataset + bảng Bronze trên BigQuery..."
  python main.py --create-tables-only
}

cmd_run() {
  activate_venv
  check_env_file
  info "Chạy pipeline đầy đủ: tạo bảng + full load dữ liệu"
  python main.py "$@"
}

cmd_logs() {
  local latest
  latest=$(ls -t logs/pipeline_*.log 2>/dev/null | head -n 1 || true)
  if [[ -z "${latest}" ]]; then
    warn "Chưa có file log nào trong logs/"
    exit 0
  fi
  info "Log gần nhất: ${latest}"
  echo ""
  cat "${latest}"
}

cmd_clean() {
  info "Xoá venv và cache Python..."
  rm -rf "${VENV_DIR}"
  find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
  find . -type f -name "*.pyc" -delete 2>/dev/null || true
  ok "Đã dọn dẹp. File .env và logs/ được giữ nguyên."
}

usage() {
  sed -n '3,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------------
case "${1:-}" in
  setup)  cmd_setup ;;
  check)  cmd_check ;;
  tables) cmd_tables ;;
  run)    shift; cmd_run "$@" ;;
  logs)   cmd_logs ;;
  clean)  cmd_clean ;;
  *)      usage; exit 1 ;;
esac
