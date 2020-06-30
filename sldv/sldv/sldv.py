import matlab.engine
import pathlib
import logging
import yaml
import os
from datetime import datetime
from .constants import *
# from .test_fw import TestFw
__all__ = ['Sldv']

_logger = logging.getLogger(__name__)


# class Sldv(TestFw):
class Sldv:

    def __init__(self):
        self.eng = matlab.engine.start_matlab()
        _logger.debug("Starting MATLAB engine...")

    @classmethod
    def test_setup(cls):
        """Setup test environment for SLDV"""
        _logger.debug("Loading config...")
        package_directory = os.path.dirname(os.path.abspath(__file__))
        conf = os.path.join(package_directory, 'sldv_config.yaml')
        if os.path.exists(conf):
            with open(conf) as f:
                params = yaml.load(f, Loader=yaml.FullLoader)
        return params

    def test_teardown(self, system_under_test):
        """Clean up and close out"""
        self.eng.bdclose(system_under_test, nargout=0)  # Close without saving
        self.eng.quit()
        return 'Done'

    @classmethod
    def get_results(cls, model_results_dir: str):
        """Results"""
        files = list(pathlib.Path(model_results_dir).glob('*.html'))
        _logger.info("Results: " + model_results_dir)
        return files

    def run(self, *args, **kwargs):
        """Run Simulink Design Verifier on selected model"""
        start_time = datetime.now()
        pm = self.test_setup()
        system_under_test = pm['system_under_test']
        enable_range_limits = pm['enable_range_limits']
        unit_test_dir = pm['unit_test_dir']

        sut_base_name = os.path.basename(system_under_test)
        model_name = os.path.splitext(sut_base_name)[0]
        _logger.info("Model: " + model_name)
        results_parent_dir = pm['results_dir']
        model_results = os.path.join(results_parent_dir, model_name)
        if not os.path.exists(model_results):
            _logger.debug("Create folder: " + model_results)
        os.makedirs(model_results, exist_ok=True)

        pkg_dir = os.path.dirname(os.path.abspath(__file__))
        self.eng.addpath(self.eng.genpath(pkg_dir))
        self.eng.cd(pkg_dir, nargout=0)
        mdl = self.eng.load_system(system_under_test)
        opts = self.eng.sldvoptions()
        _logger.info("Mode: " + MODE)

        # ---------------------------------------------------------------------------------------------------------
        # Set test specific parameters for the system under test, e.g., range limits for input signals
        # ---------------------------------------------------------------------------------------------------------
        # TODO: Move this to test_setup()
        def _get_range_limits():
            test_dir = os.path.join(pm['unit_test_dir'], model_name)
            test_conf = os.path.join(test_dir, '{}_config.yaml'.format(model_name))
            if os.path.exists(test_conf):
                with open(test_conf) as f:
                    limits = yaml.load(f, Loader=yaml.FullLoader)
                    return limits

        if enable_range_limits:
            range_limits = _get_range_limits()
            self.eng.set_range_limits(mdl, range_limits, nargout=0)
            _logger.info("Range limits: Enabled")
        # ---------------------------------------------------------------------------------------------------------

        # TODO: Put this in constants.py, pass dict to func. Loaded from test config.
        self.eng.set(opts, 'Mode', MODE, 'AutomaticStubbing', AUTOMATIC_STUBBING, 'ModelCoverageObjectives',
                     MODEL_COVERAGE_OBJECTIVES, 'MaxProcessTime', MAX_PROCESS_TIME, 'SaveReport', SAVE_REPORT,
                     'SaveData', SAVE_DATA, 'DetectDeadLogic', DETECT_DEAD_LOGIC, 'ReportFileName',
                     '$ModelName$_' + MODE, 'MakeOutputFilesUnique', MAKE_OUTPUT_FILES_UNIQUE, 'SaveHarnessModel',
                     SAVE_HARNESS_MODEL, 'ModelReferenceHarness', MODEL_REFERENCE_HARNESS, 'DisplayReport',
                     DISPLAY_REPORT, 'OutputDir', model_results, nargout=0)

        (status, output_files) = self.eng.sldvrun(mdl, opts, nargout=2)  # returns type tuple
        _logger.info("status = " + str(status))
        sldv_data_file = output_files['DataFile']
        harness = output_files['HarnessModel']
        # test_gen_report = output_files['Report']

        if (status == 1) and (MODE == 'TestGeneration'):
            _logger.info(model_name + " is compatible with Simulink Design Verifier.")
            coverage_report = os.path.join(model_results, '{}_coverage_report.html'.format(model_name))
            self.eng.run_tests(mdl, sldv_data_file, coverage_report, model_results, model_name, harness,
                               system_under_test, unit_test_dir, opts, nargout=0)
        elif (status == 1) and (MODE == 'DesignErrorDetection'):
            _logger.info(model_name + " is compatible for test generation with Simulink Design Verifier.")
        else:  # status == 0
            _logger.info(model_name + " is not compatible with Simulink Design Verifier.")

        self.get_results(model_results)
        self.test_teardown(system_under_test)

        run_time = datetime.now() - start_time
        _logger.info("Total run time: " + str(run_time))

        return True
