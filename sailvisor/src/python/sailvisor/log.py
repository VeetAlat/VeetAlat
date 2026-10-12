"""Application logging: a rotating file in the data dir, optionally mirrored to stderr."""

import logging
import logging.handlers
import os

from . import paths

_configured = False


def app_log_path():
    return os.path.join(paths.logs_dir(), "sailvisor.log")


def setup(verbose=False, stderr=False):
    """Configure the 'sailvisor' logger once. SAILVISOR_DEBUG=1 forces debug level."""
    global _configured
    logger = logging.getLogger("sailvisor")
    if os.environ.get("SAILVISOR_DEBUG") == "1":
        verbose = True
    level = logging.DEBUG if verbose else logging.INFO
    if _configured:
        logger.setLevel(min(logger.level, level))
        return logger
    logger.setLevel(level)
    fmt = logging.Formatter("%(asctime)s %(levelname)-7s [%(process)d] %(name)s: %(message)s")
    fh = logging.handlers.RotatingFileHandler(app_log_path(), maxBytes=512 * 1024, backupCount=3)
    fh.setFormatter(fmt)
    logger.addHandler(fh)
    if stderr:
        sh = logging.StreamHandler()
        sh.setFormatter(logging.Formatter("%(levelname)s: %(message)s"))
        sh.setLevel(level)
        logger.addHandler(sh)
    _configured = True
    return logger


def get(name):
    return logging.getLogger("sailvisor." + name)
