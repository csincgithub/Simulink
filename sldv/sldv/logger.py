"""
Module providing helper function(s) for configuring the root logger
"""
import logging
import os
import sys
from datetime import datetime
from logging import FileHandler


def configure_logger(workspace: str, root_log_level: int = logging.INFO) -> str:
    """
    Configure the console and file logger
    :param workspace: workspace path that should be used to save the log file
    :param root_log_level: the level of logging
    :returns path to the log file
    """
    log_folder = os.path.join(workspace, "logs")
    log_file_path = os.path.join(
        log_folder, "log_{0}.log".format(datetime.now().strftime("%m%d%Y_%H%M%S"))
    )
    os.makedirs(log_folder, exist_ok=True)

    # log_format = "%(asctime)s %(levelname)-s:%(module)-s:%(funcName)-s: %(message)s"
    log_format = "%(message)s"
    logger = logging.getLogger()
    formatter = logging.Formatter(log_format, datefmt="%H:%M:%S")

    # Configure root console logger
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    # Configure root file logger
    handler = FileHandler(log_file_path)
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    # Set logger level
    logger.setLevel(root_log_level)

    return log_file_path
