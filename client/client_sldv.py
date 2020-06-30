import sldv
from sldv.sldv import Sldv
import logging
from sldv.sldv.logger import configure_logger

configure_logger(".", logging.INFO)
logger = logging.getLogger(__name__)


def main():
    slvd = Sldv()
    success = slvd.run()
    exit(0 if success else 1)


if __name__ == "__main__":
    main()
