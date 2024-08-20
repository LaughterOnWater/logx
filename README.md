# LOGX - DreamHost Log Analysis Tool

LOGX offers a rapid overview of server logs and resources, designed for DreamHost shared servers. It's a handy tool for quick checks and basic monitoring of log activity and server status.

**Version: 1.0.1**

## Author

**LaughterOnWater**

- GitHub: [@LaughterOnWater](https://github.com/LaughterOnWater)
- Website: https://low.li
- Social: @laughteronwater, everywhere

## Features

- Access log analysis
- Error log analysis
- Disk usage analysis
- Current resource usage monitoring
- Flexible domain selection

## Prerequisites

- Bash shell
- Access to a DreamHost shared server (can be adapted for other environments)
- Proper permissions to read log files and execute the script

## Installation

1. Clone this repository or download the script to your DreamHost shared server.
2. Make the script executable:
   ```
   chmod +x logx.sh
   ```
3. Add the appropriate alias to your aliases in .bash_profile:
   ```
   alias logx="/home/<user>/path/to/logx/logx.sh"
   ```
4. Refresh the .bash_profile:
   ```
   source .bash_profile
   ```
5. Test the script:
   ```
   logx
   ``` 
## Project Structure

```
logx/
├── logx.sh         # Main script
├── logx.conf       # Configuration file
├── README.md       # This file
└── LICENSE         # License information
```

## Usage

```
logx [OPTION]
```

Options:
- `-a, --access`: Analyze the access log
- `-e, --error`: Analyze the error log
- `-d, --disk`: Analyze disk usage
- `-r, --resources`: Check current resource usage
- `-h, --help`: Display help message
- `-v, --version`: Display logx version

Examples:
```
logx -a
logx --error
logx --disk
logx --resources
```

## Configuration

Edit the `logx.conf` file in the same directory as the script to customize settings. Available settings:

- `HOME_DIR`: Home directory (default: $HOME)
- `LOGS_DIR`: Logs directory (default: $HOME_DIR/logs)
- `TOP_N`: Number of top items to display in analysis (default: 10)
- `TOP_IPS_N`: Number of top IPs to display in analysis (default: 10)
- `selected_domain`: Pre-selected domain (if not set, user will be prompted to choose)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Changes

1.0.1 - Edited directions and methodology so the logx can be available from anywhere in shell via .bash_profile alias.

1.0.0 - Earliest version
