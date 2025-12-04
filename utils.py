"""
General-purpose utility functions for data analysis.

This module provides reusable functions for data processing, validation,
and analysis tasks. While developed for 1980s delicensing analysis,
these utilities can be used for any data analysis project.
"""

import pandas as pd
import numpy as np
from typing import List, Dict, Any, Optional, Tuple
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class DataValidator:
    """Validates data integrity and quality for ASI firm data."""
    
    @staticmethod
    def check_missing_values(df: pd.DataFrame, threshold: float = 0.5) -> Dict[str, float]:
        """
        Check for missing values in the dataframe.
        
        Args:
            df: Input dataframe
            threshold: Proportion threshold for missing values warning (0-1)
            
        Returns:
            Dictionary with column names and their missing value proportions
        """
        missing_props = df.isnull().sum() / len(df)
        high_missing = missing_props[missing_props > threshold]
        
        if not high_missing.empty:
            logger.warning(f"Columns with >{threshold*100}% missing values: {high_missing.to_dict()}")
        
        return missing_props.to_dict()
    
    @staticmethod
    def validate_year_range(df: pd.DataFrame, year_col: str, 
                           start_year: int = 1976, end_year: int = 1990) -> bool:
        """
        Validate that years fall within expected range.
        
        Args:
            df: Input dataframe
            year_col: Name of the year column
            start_year: Minimum expected year
            end_year: Maximum expected year
            
        Returns:
            True if all years are valid, False otherwise
        """
        if year_col not in df.columns:
            logger.error(f"Year column '{year_col}' not found in dataframe")
            return False
        
        years = df[year_col].dropna()
        invalid_years = years[(years < start_year) | (years > end_year)]
        
        if not invalid_years.empty:
            logger.warning(f"Found {len(invalid_years)} records with years outside {start_year}-{end_year}")
            return False
        
        return True
    
    @staticmethod
    def check_duplicates(df: pd.DataFrame, id_cols: List[str]) -> int:
        """
        Check for duplicate records based on ID columns.
        
        Args:
            df: Input dataframe
            id_cols: List of columns that should uniquely identify records
            
        Returns:
            Number of duplicate records found
        """
        duplicates = df.duplicated(subset=id_cols, keep=False)
        n_duplicates = duplicates.sum()
        
        if n_duplicates > 0:
            logger.warning(f"Found {n_duplicates} duplicate records based on {id_cols}")
        
        return n_duplicates


class DataProcessor:
    """Process and transform ASI firm data."""
    
    @staticmethod
    def load_year_range(base_directory: str, start_year: int, end_year: int,
                       file_pattern: str = "{year}_{next_year}") -> pd.DataFrame:
        """
        Load data for a range of years and combine into single dataframe.
        
        Args:
            base_directory: Base directory containing year folders
            start_year: First year to load
            end_year: Last year to load (inclusive)
            file_pattern: Pattern for folder names
            
        Returns:
            Combined dataframe with all years
        """
        dfs = []
        
        for year in range(start_year, end_year + 1):
            folder_name = file_pattern.format(year=year, next_year=year+1)
            folder_path = os.path.join(base_directory, folder_name)
            
            if not os.path.exists(folder_path):
                logger.warning(f"Folder not found: {folder_path}")
                continue
            
            # TODO: Implement actual file loading based on your data format
            # Example implementations:
            # df = pd.read_csv(os.path.join(folder_path, 'data.csv'))
            # df = pd.read_stata(os.path.join(folder_path, 'data.dta'))
            # df = pyreadstat.read_sav(os.path.join(folder_path, 'data.sav'))
            logger.info(f"Loading data from {folder_path}")
            # dfs.append(df)
        
        if dfs:
            return pd.concat(dfs, ignore_index=True)
        else:
            logger.error("No data loaded")
            return pd.DataFrame()
    
    @staticmethod
    def clean_numeric_columns(df: pd.DataFrame, columns: List[str]) -> pd.DataFrame:
        """
        Clean numeric columns by removing invalid values and converting types.
        
        Args:
            df: Input dataframe
            columns: List of column names to clean
            
        Returns:
            Dataframe with cleaned numeric columns
        """
        df_clean = df.copy()
        
        for col in columns:
            if col not in df_clean.columns:
                logger.warning(f"Column '{col}' not found, skipping")
                continue
            
            # Convert to numeric, coercing errors to NaN
            df_clean[col] = pd.to_numeric(df_clean[col], errors='coerce')
            
            # Remove infinite values
            df_clean[col] = df_clean[col].replace([np.inf, -np.inf], np.nan)
        
        return df_clean
    
    @staticmethod
    def create_panel_structure(df: pd.DataFrame, firm_id: str, time_col: str) -> pd.DataFrame:
        """
        Create balanced panel structure for firm-level data.
        
        Args:
            df: Input dataframe
            firm_id: Column name for firm identifier
            time_col: Column name for time period
            
        Returns:
            Panel-structured dataframe
        """
        # Get unique firms and time periods
        firms = df[firm_id].unique()
        time_periods = df[time_col].unique()
        
        # Create all combinations
        panel_index = pd.MultiIndex.from_product(
            [firms, time_periods],
            names=[firm_id, time_col]
        )
        
        # Reindex to create balanced panel
        df_panel = df.set_index([firm_id, time_col]).reindex(panel_index).reset_index()
        
        logger.info(f"Created panel with {len(firms)} firms and {len(time_periods)} time periods")
        
        return df_panel


class AnalysisTools:
    """Statistical analysis tools for delicensing research."""
    
    @staticmethod
    def calculate_growth_rate(df: pd.DataFrame, value_col: str, 
                             group_cols: List[str]) -> pd.DataFrame:
        """
        Calculate growth rates for a variable.
        
        Args:
            df: Input dataframe
            value_col: Column to calculate growth for
            group_cols: Columns to group by (e.g., firm ID)
            
        Returns:
            Dataframe with growth rate column added
        """
        df_growth = df.copy()
        
        # Sort by group and time
        df_growth = df_growth.sort_values(group_cols + [value_col])
        
        # Calculate percentage change within groups
        df_growth[f'{value_col}_growth'] = df_growth.groupby(group_cols)[value_col].pct_change()
        
        return df_growth
    
    @staticmethod
    def create_summary_stats(df: pd.DataFrame, 
                            numeric_cols: Optional[List[str]] = None) -> pd.DataFrame:
        """
        Generate summary statistics for numeric columns.
        
        Args:
            df: Input dataframe
            numeric_cols: Specific columns to summarize (None = all numeric)
            
        Returns:
            Summary statistics dataframe
        """
        if numeric_cols is None:
            numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
        
        summary = df[numeric_cols].describe()
        
        # Add additional statistics
        summary.loc['missing'] = df[numeric_cols].isnull().sum()
        summary.loc['missing_pct'] = (df[numeric_cols].isnull().sum() / len(df)) * 100
        
        return summary
    
    @staticmethod
    def filter_by_conditions(df: pd.DataFrame, conditions: Dict[str, Any]) -> pd.DataFrame:
        """
        Filter dataframe by multiple conditions.
        
        Args:
            df: Input dataframe
            conditions: Dictionary of column: value or column: (operator, value)
            
        Returns:
            Filtered dataframe
            
        Example:
            conditions = {
                'year': ('>=' , 1980),
                'sector': 'manufacturing',
                'licensed': True
            }
        """
        df_filtered = df.copy()
        
        for col, condition in conditions.items():
            if col not in df_filtered.columns:
                logger.warning(f"Column '{col}' not found, skipping condition")
                continue
            
            if isinstance(condition, tuple):
                operator, value = condition
                if operator == '>=':
                    df_filtered = df_filtered[df_filtered[col] >= value]
                elif operator == '<=':
                    df_filtered = df_filtered[df_filtered[col] <= value]
                elif operator == '>':
                    df_filtered = df_filtered[df_filtered[col] > value]
                elif operator == '<':
                    df_filtered = df_filtered[df_filtered[col] < value]
                elif operator == '!=':
                    df_filtered = df_filtered[df_filtered[col] != value]
                else:
                    logger.warning(f"Unknown operator '{operator}'")
            else:
                df_filtered = df_filtered[df_filtered[col] == condition]
        
        logger.info(f"Filtered from {len(df)} to {len(df_filtered)} records")
        
        return df_filtered


def export_to_multiple_formats(df: pd.DataFrame, base_filename: str, 
                               formats: List[str] = ['csv', 'excel', 'stata']) -> None:
    """
    Export dataframe to multiple file formats.
    
    Args:
        df: Dataframe to export
        base_filename: Base filename (without extension)
        formats: List of formats to export to
    """
    for fmt in formats:
        try:
            if fmt == 'csv':
                df.to_csv(f"{base_filename}.csv", index=False)
                logger.info(f"Exported to {base_filename}.csv")
            elif fmt == 'excel':
                df.to_excel(f"{base_filename}.xlsx", index=False)
                logger.info(f"Exported to {base_filename}.xlsx")
            elif fmt == 'stata':
                df.to_stata(f"{base_filename}.dta", write_index=False)
                logger.info(f"Exported to {base_filename}.dta")
            elif fmt == 'parquet':
                df.to_parquet(f"{base_filename}.parquet", index=False)
                logger.info(f"Exported to {base_filename}.parquet")
        except Exception as e:
            logger.error(f"Error exporting to {fmt}: {str(e)}")


if __name__ == "__main__":
    # Example usage
    print("Utility module loaded successfully")
    print("\nAvailable classes:")
    print("  - DataValidator: Validate data integrity")
    print("  - DataProcessor: Process and transform data")
    print("  - AnalysisTools: Statistical analysis tools")
