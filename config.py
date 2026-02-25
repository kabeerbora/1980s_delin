"""
Configuration module for 1980s delicensing analysis.

This module contains configurable parameters for data processing and analysis.
"""

import os
from pathlib import Path
from typing import List, Dict


class Config:
    """Configuration class for analysis parameters."""
    
    # Project paths
    PROJECT_ROOT = Path(__file__).parent
    DATA_DIR = PROJECT_ROOT / "data"
    OUTPUT_DIR = PROJECT_ROOT / "output"
    
    # Analysis parameters
    START_YEAR = 1976
    END_YEAR = 1990
    
    # Data validation thresholds
    MISSING_VALUE_THRESHOLD = 0.5  # Maximum proportion of missing values allowed
    
    # Column names (standardized)
    FIRM_ID_COL = 'firm_id'
    YEAR_COL = 'year'
    OUTPUT_COL = 'output'
    EMPLOYEES_COL = 'employees'
    LICENSED_COL = 'licensed'
    
    # File formats
    DEFAULT_EXPORT_FORMATS = ['csv', 'excel']
    
    # Logging
    LOG_LEVEL = 'INFO'
    LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    
    @classmethod
    def get_year_folders(cls, start_year: int = None, end_year: int = None) -> List[str]:
        """
        Generate list of year folder names.
        
        Args:
            start_year: Starting year (default: from config)
            end_year: Ending year (default: from config)
            
        Returns:
            List of folder names in format 'YYYY_YYYY+1'
        """
        start = start_year or cls.START_YEAR
        end = end_year or cls.END_YEAR
        
        return [f"{year}_{year+1}" for year in range(start, end + 1)]
    
    @classmethod
    def ensure_directories(cls):
        """Create necessary directories if they don't exist."""
        cls.DATA_DIR.mkdir(exist_ok=True, parents=True)
        cls.OUTPUT_DIR.mkdir(exist_ok=True, parents=True)


class AnalysisConfig:
    """Configuration for specific analysis tasks."""
    
    # Delicensing analysis parameters
    DELICENSING_YEAR = 1985  # Key policy change year
    
    # Industry classifications
    MANUFACTURING_SECTORS = [
        'textiles',
        'chemicals',
        'machinery',
        'electronics',
        'automobiles'
    ]
    
    # Statistical parameters
    SIGNIFICANCE_LEVEL = 0.05
    CONFIDENCE_LEVEL = 0.95
    
    # Visualization settings
    FIGURE_SIZE = (12, 8)
    DPI = 300
    COLOR_PALETTE = 'Set2'
    
    @staticmethod
    def get_treatment_control_split(year: int) -> str:
        """
        Determine if a year is pre or post delicensing.
        
        Args:
            year: Year to classify
            
        Returns:
            'pre' or 'post' treatment period
        """
        return 'pre' if year < AnalysisConfig.DELICENSING_YEAR else 'post'


# Example usage and environment-specific overrides
def load_config(env: str = 'development') -> Dict:
    """
    Load configuration based on environment.
    
    Args:
        env: Environment name ('development', 'production', 'testing')
        
    Returns:
        Dictionary of configuration values
    """
    base_config = {
        'start_year': Config.START_YEAR,
        'end_year': Config.END_YEAR,
        'missing_threshold': Config.MISSING_VALUE_THRESHOLD,
        'significance_level': AnalysisConfig.SIGNIFICANCE_LEVEL
    }
    
    if env == 'testing':
        # Use smaller date range for testing
        base_config.update({
            'start_year': 1980,
            'end_year': 1985
        })
    elif env == 'production':
        # Production-specific settings
        base_config.update({
            'log_level': 'WARNING'
        })
    
    return base_config


if __name__ == "__main__":
    # Display configuration
    print("=== Project Configuration ===")
    print(f"Project Root: {Config.PROJECT_ROOT}")
    print(f"Data Directory: {Config.DATA_DIR}")
    print(f"Output Directory: {Config.OUTPUT_DIR}")
    print(f"Analysis Period: {Config.START_YEAR}-{Config.END_YEAR}")
    print(f"\nYear Folders: {', '.join(Config.get_year_folders()[:5])} ...")
    print(f"\nDelicensing Year: {AnalysisConfig.DELICENSING_YEAR}")
    print(f"Manufacturing Sectors: {len(AnalysisConfig.MANUFACTURING_SECTORS)}")
