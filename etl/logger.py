import logging
import sys
from datetime import datetime

from etl.config import LOG_DIR

#Tạo logger
def setup_logger(run_id: str, name: str = "pipeline") -> logging.Logger:
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = LOG_DIR / f"pipeline_{timestamp}.log"

    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)
    logger.handlers.clear()  # tránh log bị lặp khi gọi setup nhiều lần

    fmt = logging.Formatter(
        fmt="%(asctime)s | %(levelname)-7s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # Ghi ra file
    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setFormatter(fmt)
    logger.addHandler(file_handler)

    # In ra console
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(fmt)
    logger.addHandler(console_handler)

    logger.info("=" * 70)
    logger.info("Log file: %s", log_file)
    logger.info("Run ID  : %s", run_id)
    logger.info("=" * 70)

    return logger
