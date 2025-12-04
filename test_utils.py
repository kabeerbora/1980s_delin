"""
Unit tests for utility functions.

Run with: python -m pytest test_utils.py
"""

import pandas as pd
import numpy as np
import pytest
from utils import DataValidator, DataProcessor, AnalysisTools


class TestDataValidator:
    """Test cases for DataValidator class."""
    
    def test_check_missing_values(self):
        """Test missing value detection."""
        # Create test dataframe with missing values
        df = pd.DataFrame({
            'col1': [1, 2, 3, 4, 5],
            'col2': [1, None, None, None, 5],  # 60% missing
            'col3': [1, 2, 3, 4, 5]
        })
        
        validator = DataValidator()
        missing = validator.check_missing_values(df, threshold=0.5)
        
        assert 'col2' in missing
        assert missing['col2'] == 0.6
        assert missing['col1'] == 0.0
    
    def test_validate_year_range(self):
        """Test year range validation."""
        df = pd.DataFrame({
            'year': [1980, 1981, 1982, 1983],
            'value': [100, 200, 300, 400]
        })
        
        validator = DataValidator()
        assert validator.validate_year_range(df, 'year', 1976, 1990) == True
        
        # Test with invalid years
        df_invalid = pd.DataFrame({
            'year': [1970, 1995],
            'value': [100, 200]
        })
        assert validator.validate_year_range(df_invalid, 'year', 1976, 1990) == False
    
    def test_check_duplicates(self):
        """Test duplicate detection."""
        df = pd.DataFrame({
            'firm_id': [1, 1, 2, 3],
            'year': [1980, 1980, 1980, 1980],  # Duplicate (1, 1980)
            'value': [100, 100, 200, 300]
        })
        
        validator = DataValidator()
        n_dups = validator.check_duplicates(df, ['firm_id', 'year'])
        
        assert n_dups == 2  # Both duplicate rows are counted


class TestDataProcessor:
    """Test cases for DataProcessor class."""
    
    def test_clean_numeric_columns(self):
        """Test numeric column cleaning."""
        df = pd.DataFrame({
            'col1': ['1', '2', 'invalid', '4'],
            'col2': [1.0, np.inf, -np.inf, 4.0],
            'col3': [1, 2, 3, 4]
        })
        
        processor = DataProcessor()
        df_clean = processor.clean_numeric_columns(df, ['col1', 'col2'])
        
        # Check that invalid values are converted to NaN
        assert pd.isna(df_clean.loc[2, 'col1'])
        assert pd.isna(df_clean.loc[1, 'col2'])
        assert pd.isna(df_clean.loc[2, 'col2'])
        
        # Check that valid values are preserved
        assert df_clean.loc[0, 'col1'] == 1.0
        assert df_clean.loc[0, 'col2'] == 1.0
    
    def test_create_panel_structure(self):
        """Test panel structure creation."""
        df = pd.DataFrame({
            'firm_id': [1, 1, 2, 2],
            'year': [1980, 1981, 1980, 1982],
            'value': [100, 200, 300, 400]
        })
        
        processor = DataProcessor()
        df_panel = processor.create_panel_structure(df, 'firm_id', 'year')
        
        # Should have all combinations of firms and years
        assert len(df_panel) == 6  # 2 firms * 3 years
        
        # Check that missing combinations have NaN values
        firm2_1981 = df_panel[(df_panel['firm_id'] == 2) & (df_panel['year'] == 1981)]
        assert pd.isna(firm2_1981['value'].values[0])


class TestAnalysisTools:
    """Test cases for AnalysisTools class."""
    
    def test_calculate_growth_rate(self):
        """Test growth rate calculation."""
        df = pd.DataFrame({
            'firm_id': [1, 1, 1, 2, 2, 2],
            'year': [1980, 1981, 1982, 1980, 1981, 1982],
            'value': [100, 110, 121, 200, 220, 242]
        })
        
        tools = AnalysisTools()
        df_growth = tools.calculate_growth_rate(df, 'value', ['firm_id'])
        
        # Check growth rates (should be approximately 0.1 or 10%)
        growth_values = df_growth['value_growth'].dropna()
        assert len(growth_values) == 4  # First value for each firm is NaN
        
        # Check approximate growth rates
        for g in growth_values:
            assert 0.09 < g < 0.11  # Allow small floating point differences
    
    def test_create_summary_stats(self):
        """Test summary statistics generation."""
        df = pd.DataFrame({
            'col1': [1, 2, 3, 4, 5],
            'col2': [10, 20, None, 40, 50],
            'col3': ['a', 'b', 'c', 'd', 'e']  # Non-numeric
        })
        
        tools = AnalysisTools()
        summary = tools.create_summary_stats(df)
        
        # Should only include numeric columns
        assert 'col1' in summary.columns
        assert 'col2' in summary.columns
        assert 'col3' not in summary.columns
        
        # Check that missing values are counted
        assert summary.loc['missing', 'col1'] == 0
        assert summary.loc['missing', 'col2'] == 1
    
    def test_filter_by_conditions(self):
        """Test filtering by conditions."""
        df = pd.DataFrame({
            'year': [1980, 1981, 1982, 1983, 1984],
            'sector': ['A', 'B', 'A', 'B', 'A'],
            'value': [100, 200, 300, 400, 500]
        })
        
        tools = AnalysisTools()
        
        # Test simple equality condition
        df_filtered = tools.filter_by_conditions(df, {'sector': 'A'})
        assert len(df_filtered) == 3
        assert all(df_filtered['sector'] == 'A')
        
        # Test comparison operator
        df_filtered = tools.filter_by_conditions(df, {'year': ('>=', 1982)})
        assert len(df_filtered) == 3
        assert all(df_filtered['year'] >= 1982)
        
        # Test multiple conditions
        df_filtered = tools.filter_by_conditions(df, {
            'year': ('>=', 1982),
            'sector': 'A'
        })
        assert len(df_filtered) == 2
        assert all(df_filtered['sector'] == 'A')
        assert all(df_filtered['year'] >= 1982)


# Pytest fixtures for reusable test data
@pytest.fixture
def sample_firm_data():
    """Create sample firm data for testing."""
    return pd.DataFrame({
        'firm_id': [1, 1, 1, 2, 2, 2, 3, 3, 3],
        'year': [1980, 1981, 1982, 1980, 1981, 1982, 1980, 1981, 1982],
        'output': [100, 110, 121, 200, 220, 242, 150, 165, 181.5],
        'employees': [10, 11, 12, 20, 22, 24, 15, 16, 17],
        'licensed': [True, True, False, True, True, True, False, False, False]
    })


@pytest.fixture
def sample_data_with_missing():
    """Create sample data with missing values for testing."""
    return pd.DataFrame({
        'col1': [1, 2, None, 4, 5],
        'col2': [10, None, 30, None, 50],
        'col3': [100, 200, 300, 400, 500]
    })


def test_integration_validation_and_cleaning(sample_data_with_missing):
    """Integration test: validate and clean data."""
    validator = DataValidator()
    processor = DataProcessor()
    
    # Validate
    missing = validator.check_missing_values(sample_data_with_missing)
    assert missing['col2'] == 0.4  # 40% missing
    
    # Clean
    df_clean = processor.clean_numeric_columns(
        sample_data_with_missing, 
        ['col1', 'col2', 'col3']
    )
    
    # Verify cleaning preserved numeric types
    assert df_clean['col1'].dtype in [np.float64, np.int64]
    assert df_clean['col2'].dtype in [np.float64, np.int64]


def test_integration_panel_and_analysis(sample_firm_data):
    """Integration test: create panel and calculate statistics."""
    processor = DataProcessor()
    tools = AnalysisTools()
    
    # Create panel
    df_panel = processor.create_panel_structure(sample_firm_data, 'firm_id', 'year')
    
    # Calculate growth rates
    df_growth = tools.calculate_growth_rate(df_panel, 'output', ['firm_id'])
    
    # Generate summary
    summary = tools.create_summary_stats(df_growth, ['output', 'employees'])
    
    assert 'output' in summary.columns
    assert 'employees' in summary.columns
    assert summary.loc['count', 'output'] > 0


if __name__ == "__main__":
    pytest.main([__file__, '-v'])
