# Sent Email Analysis

Cleanbox includes a powerful sent email analysis feature that helps you understand your communication patterns and optimize your whitelist configuration.

## What It Does

The sent-analysis feature:
- **Analyzes your sent emails** to identify who you correspond with most frequently
- **Compares sent recipients** with folder senders to find potential whitelist candidates
- **Suggests folder categorization** based on overlap between sent emails and folder contents
- **Provides detailed statistics** about your email communication patterns

## Commands

```bash
# Collect data from your sent emails and all folders
./cleanbox sent-analysis collect

# Analyze the collected data and show statistics
./cleanbox sent-analysis analyze

# Compare sent recipients with folder senders and show recommendations
./cleanbox sent-analysis compare

# Show help for sent-analysis commands
./cleanbox sent-analysis help
```

## Data Collection

The `collect` command:
- Analyzes up to 1000 of your most recent sent emails
- Examines up to 200 messages from each folder
- Saves detailed data to JSON and CSV files for analysis
- Uses progress meters to show collection progress

### Collection Process

```bash
# Start data collection
./cleanbox sent-analysis collect

# Output will show progress like:
# 📊 Collecting sent email data...
# ✅ Analyzed 1000 sent emails
# 📊 Collecting folder data...
# ✅ Analyzed Family folder (150 emails)
# ✅ Analyzed Work folder (200 emails)
# ✅ Analyzed Newsletters folder (200 emails)
# 📊 Saving data to files...
# ✅ Data collection complete!
```

### Data Files Created

The collection process creates several files:

- **`sent_analysis_data.json`** - Raw data in JSON format
- **`sent_analysis_summary.csv`** - Summary statistics in CSV format
- **`sent_recipients.csv`** - List of all sent email recipients
- **`folder_senders.csv`** - List of all folder senders

## Analysis Output

### Basic Analysis

The `analyze` command shows:
- **Top recipients** from your sent emails
- **Folder categorization** (whitelist vs list folders)
- **Message counts** and sender statistics for each folder

```bash
./cleanbox sent-analysis analyze

# Example output:
# 📊 SENT EMAIL ANALYSIS
# ============================================================
# Top 10 Sent Recipients:
# 1. family@example.com (15 emails)
# 2. colleague@company.com (12 emails)
# 3. client@client.com (8 emails)
# 4. friend@example.com (6 emails)
# 5. newsletter@example.com (3 emails)
# 
# Folder Statistics:
# Family (whitelist): 150 emails, 25 unique senders
# Work (whitelist): 200 emails, 45 unique senders
# Newsletters (list): 300 emails, 50 unique senders
```

### Comparison Analysis

The `compare` command shows:
- **Overlap analysis** between sent recipients and folder senders
- **Folder rankings** by overlap percentage
- **Recommendations** for whitelist vs list categorization
- **Summary statistics** for whitelist vs list folders

```bash
./cleanbox sent-analysis compare

# Example output:
# 📊 SENT vs FOLDER COMPARISON
# =============================================================
# Folders ranked by overlap with sent recipients:
# 
# 1. Family (whitelist)
#    Overlap: 9/9 (100.0%)
#    Overlapping emails: family@example.com, mom@example.com
# 
# 2. Work (whitelist)
#    Overlap: 4/16 (25.0%)
#    Overlapping emails: colleague@company.com, client@client.com
# 
# 3. Newsletters (list)
#    Overlap: 1/50 (2.0%)
#    Overlapping emails: newsletter@example.com
# 
# SUMMARY STATISTICS
# ==============================
# Whitelist folders average overlap: 49.24%
# List folders average overlap: 6.37%
# 
# RECOMMENDATIONS
# ====================
# Folders with high overlap (>50%) - consider whitelist:
#   - Family (100.0%)
#   - Friends (75.0%)
# 
# Folders with low overlap (<10%) - consider list:
#   - Newsletters (5.0%)
#   - Shopping (2.0%)
```

## Use Cases

### Optimizing Whitelist Configuration

**Scenario**: You want to ensure that people you frequently email stay in your inbox.

```bash
# Collect and analyze your data
./cleanbox sent-analysis collect
./cleanbox sent-analysis compare

# Based on recommendations, update your configuration
./cleanbox config add whitelist_folders "Friends"  # If Friends has high overlap
./cleanbox config remove whitelist_folders "Newsletters"  # If Newsletters has low overlap
```

### Understanding Communication Patterns

**Scenario**: You want to understand who you correspond with most frequently.

```bash
# Analyze your sent emails
./cleanbox sent-analysis collect
./cleanbox sent-analysis analyze

# Look at the top recipients to understand your communication patterns
# This can help you decide which folders should be whitelisted
```

### Data-Driven Folder Organization

**Scenario**: You want to use data to decide how to categorize your folders.

```bash
# Compare sent emails with folder contents
./cleanbox sent-analysis collect
./cleanbox sent-analysis compare

# Use the overlap analysis to decide:
# - High overlap folders → whitelist (keep in inbox)
# - Low overlap folders → list (move to folders)
```

### Finding Whitelist Candidates

**Scenario**: You want to find people you email frequently who might be in list folders.

```bash
# Run the comparison analysis
./cleanbox sent-analysis compare

# Look for folders with high overlap that are currently in list_folders
# These might be candidates for moving to whitelist_folders
```

## Data Directory Support

Sent analysis data is saved to the same data directory as other Cleanbox files:
- **With `--data-dir`**: Files saved to specified directory
- **Without `--data-dir`**: Files saved to current working directory
- **From config**: Uses `data_dir` setting from `~/.cleanbox.yml`

### Example with Data Directory

```bash
# Use custom data directory
./cleanbox --data-dir /path/to/data sent-analysis collect

# Files will be saved to:
# - /path/to/data/sent_analysis_data.json
# - /path/to/data/sent_analysis_summary.csv
# - /path/to/data/sent_recipients.csv
# - /path/to/data/folder_senders.csv
```

## Interpreting Results

### Overlap Percentages

- **100% overlap**: Everyone you email from this folder is also in your sent emails
- **50-99% overlap**: High overlap - consider whitelisting
- **10-49% overlap**: Moderate overlap - evaluate based on importance
- **0-9% overlap**: Low overlap - likely safe to keep as list folder

### Recommendations

**High overlap folders (>50%):**
- These folders contain people you actively correspond with
- Consider moving them to `whitelist_folders`
- Examples: Family, Close Friends, Important Work Contacts

**Low overlap folders (<10%):**
- These folders contain mostly one-way communication
- Safe to keep in `list_folders`
- Examples: Newsletters, Marketing, Notifications

**Moderate overlap folders (10-49%):**
- Evaluate based on importance and communication frequency
- Consider the nature of the relationship
- Examples: Work colleagues, occasional contacts

## Advanced Analysis

### Custom Analysis

You can analyze the generated CSV files for custom insights:

```bash
# View the raw data
cat sent_analysis_summary.csv

# Use tools like awk, grep, or spreadsheet software for custom analysis
grep "Family" sent_analysis_summary.csv
```

### Regular Analysis

For ongoing optimization:

```bash
# Weekly analysis
./cleanbox sent-analysis collect
./cleanbox sent-analysis compare

# Monthly review
# Review the recommendations and update your configuration accordingly
```

## Troubleshooting

### Common Issues

**"No sent emails found"**
- Check that your sent folder is correctly configured
- Verify that you have sent emails in the specified time period
- Use `--verbose` flag for more details

**"No folders found"**
- Ensure your folder names match your configuration
- Check that folders exist in your email account
- Use `./cleanbox folders` to see available folders

**"Data collection failed"**
- Check your authentication and connection
- Ensure you have sufficient permissions to access sent emails
- Try with `--verbose` flag for detailed error messages

### Debug Mode

```bash
# Enable debug logging for sent analysis
./cleanbox sent-analysis collect --verbose --level debug
```

## Integration with Configuration

### Updating Configuration Based on Analysis

```bash
# After running analysis and reviewing recommendations
./cleanbox config add whitelist_folders "HighOverlapFolder"
./cleanbox config remove list_folders "HighOverlapFolder"

# Verify the changes
./cleanbox config show
```

### Automated Optimization

You can create scripts to automate the optimization process:

```bash
#!/bin/bash
# Collect and analyze data
./cleanbox sent-analysis collect
./cleanbox sent-analysis compare

# Based on recommendations, update configuration
# (This would require parsing the output and making decisions)
```

## Next Steps

After understanding sent analysis:

1. **[Usage](usage.md)** - Learn more about Cleanbox commands
2. **[Configuration](configuration.md)** - Advanced configuration options
3. **[Troubleshooting](troubleshooting.md)** - Common issues and solutions 