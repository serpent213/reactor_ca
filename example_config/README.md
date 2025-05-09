# Example Configuration

This directory contains example configuration files for ReactorCA. These files serve as reference examples and should not be used directly in your ReactorCA installation.

## Usage

To set up your own configuration, run the following command in your ReactorCA installation:

```bash
ca config init
```

This will create the necessary configuration files in the `config` directory with default values.

## Files

- **ca.yaml**: Configuration for your Certificate Authority including identity information, key settings, and password requirements
- **hosts.yaml**: Configuration for host certificates including common names, alternative names, and key settings

## Customization

After running `config init`, you should customize the generated configuration files to match your requirements by editing them in the `config` directory.
