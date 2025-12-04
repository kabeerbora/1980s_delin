#!/usr/bin/env python3
"""
Command-line interface for 1980s delicensing analysis tools.

Usage:
    python cli.py validate --file data.csv
    python cli.py process --input data.csv --output cleaned.csv
    python cli.py analyze --file data.csv --year 1985
"""

import argparse
import sys
import pandas as pd
from pathlib import Path
from utils import DataValidator, DataProcessor, AnalysisTools
from config import Config


def validate_command(args):
    """Run data validation."""
    print(f"Validating file: {args.file}")
    
    try:
        df = pd.read_csv(args.file)
        validator = DataValidator()
        
        print(f"\nLoaded {len(df)} records with {len(df.columns)} columns")
        
        # Check missing values
        print("\n--- Missing Values Check ---")
        missing = validator.check_missing_values(df, threshold=args.threshold)
        for col, prop in missing.items():
            if prop > 0:
                print(f"  {col}: {prop*100:.1f}% missing")
        
        # Validate year range if year column exists
        if args.year_col and args.year_col in df.columns:
            print("\n--- Year Range Validation ---")
            is_valid = validator.validate_year_range(
                df, args.year_col, 
                Config.START_YEAR, Config.END_YEAR
            )
            if is_valid:
                print(f"  ✓ All years within {Config.START_YEAR}-{Config.END_YEAR}")
            else:
                print(f"  ✗ Some years outside {Config.START_YEAR}-{Config.END_YEAR}")
        
        # Check duplicates if ID columns specified
        if args.id_cols:
            print("\n--- Duplicate Check ---")
            id_cols = args.id_cols.split(',')
            n_dups = validator.check_duplicates(df, id_cols)
            if n_dups == 0:
                print(f"  ✓ No duplicates found on {id_cols}")
            else:
                print(f"  ✗ Found {n_dups} duplicate records")
        
        print("\n✓ Validation complete")
        return 0
        
    except Exception as e:
        print(f"Error during validation: {str(e)}", file=sys.stderr)
        return 1


def process_command(args):
    """Run data processing."""
    print(f"Processing file: {args.input}")
    
    try:
        df = pd.read_csv(args.input)
        processor = DataProcessor()
        
        print(f"Loaded {len(df)} records")
        
        # Clean numeric columns if specified
        if args.numeric_cols:
            print("\n--- Cleaning Numeric Columns ---")
            cols = args.numeric_cols.split(',')
            df = processor.clean_numeric_columns(df, cols)
            print(f"  Cleaned columns: {', '.join(cols)}")
        
        # Create panel structure if specified
        if args.panel and args.firm_col and args.time_col:
            print("\n--- Creating Panel Structure ---")
            df = processor.create_panel_structure(df, args.firm_col, args.time_col)
            print(f"  Created panel: {len(df)} observations")
        
        # Save output
        output_path = args.output or args.input.replace('.csv', '_processed.csv')
        df.to_csv(output_path, index=False)
        print(f"\n✓ Saved processed data to: {output_path}")
        return 0
        
    except Exception as e:
        print(f"Error during processing: {str(e)}", file=sys.stderr)
        return 1


def analyze_command(args):
    """Run analysis."""
    print(f"Analyzing file: {args.file}")
    
    try:
        df = pd.read_csv(args.file)
        tools = AnalysisTools()
        
        print(f"Loaded {len(df)} records")
        
        # Generate summary statistics
        if args.summary:
            print("\n--- Summary Statistics ---")
            cols = args.columns.split(',') if args.columns else None
            summary = tools.create_summary_stats(df, cols)
            print(summary)
        
        # Calculate growth rates
        if args.growth and args.value_col and args.group_cols:
            print("\n--- Growth Rate Analysis ---")
            group_cols = args.group_cols.split(',')
            df_growth = tools.calculate_growth_rate(df, args.value_col, group_cols)
            
            # Show sample results
            print("\nSample growth rates:")
            print(df_growth[[*group_cols, args.value_col, f'{args.value_col}_growth']].head(10))
            
            if args.output:
                df_growth.to_csv(args.output, index=False)
                print(f"\n✓ Saved growth rates to: {args.output}")
        
        # Apply filters
        if args.filter:
            print("\n--- Applying Filters ---")
            # Parse filter string (format: col1=value1,col2>=value2)
            conditions = {}
            for f in args.filter.split(','):
                if '=' in f:
                    parts = f.split('=')
                    col = parts[0]
                    val = parts[1]
                    conditions[col] = val
            
            df_filtered = tools.filter_by_conditions(df, conditions)
            print(f"  Filtered to {len(df_filtered)} records")
        
        print("\n✓ Analysis complete")
        return 0
        
    except Exception as e:
        print(f"Error during analysis: {str(e)}", file=sys.stderr)
        return 1


def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description='1980s Delicensing Analysis Tools',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Validate command
    validate_parser = subparsers.add_parser('validate', help='Validate data quality')
    validate_parser.add_argument('--file', required=True, help='Input CSV file')
    validate_parser.add_argument('--threshold', type=float, default=0.5, 
                                help='Missing value threshold (default: 0.5)')
    validate_parser.add_argument('--year-col', help='Year column name')
    validate_parser.add_argument('--id-cols', help='Comma-separated ID columns for duplicate check')
    
    # Process command
    process_parser = subparsers.add_parser('process', help='Process and clean data')
    process_parser.add_argument('--input', required=True, help='Input CSV file')
    process_parser.add_argument('--output', help='Output CSV file (optional)')
    process_parser.add_argument('--numeric-cols', help='Comma-separated numeric columns to clean')
    process_parser.add_argument('--panel', action='store_true', help='Create panel structure')
    process_parser.add_argument('--firm-col', help='Firm ID column (for panel)')
    process_parser.add_argument('--time-col', help='Time column (for panel)')
    
    # Analyze command
    analyze_parser = subparsers.add_parser('analyze', help='Run analysis')
    analyze_parser.add_argument('--file', required=True, help='Input CSV file')
    analyze_parser.add_argument('--summary', action='store_true', help='Generate summary statistics')
    analyze_parser.add_argument('--columns', help='Comma-separated columns for summary')
    analyze_parser.add_argument('--growth', action='store_true', help='Calculate growth rates')
    analyze_parser.add_argument('--value-col', help='Value column for growth calculation')
    analyze_parser.add_argument('--group-cols', help='Comma-separated grouping columns')
    analyze_parser.add_argument('--filter', help='Filter conditions (format: col=val,col2>=val2)')
    analyze_parser.add_argument('--output', help='Output file for results')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    # Route to appropriate command handler
    if args.command == 'validate':
        return validate_command(args)
    elif args.command == 'process':
        return process_command(args)
    elif args.command == 'analyze':
        return analyze_command(args)
    else:
        print(f"Unknown command: {args.command}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
