<p align="center">
  <img src="https://raw.githubusercontent.com/fluttercandies/svgo/main/svgo.png" alt="SVGO Logo" width="160" height="160">
</p>

<h1 align="center">SVGO CLI</h1>

<p align="center">
  <a href="README.zh.md">🇨🇳 中文</a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/svgo_cli"><img src="https://img.shields.io/pub/v/svgo_cli.svg" alt="pub package"></a>
  <a href="https://github.com/fluttercandies/svgo/blob/main/LICENSE"><img src="https://img.shields.io/github/license/fluttercandies/svgo" alt="license"></a>
</p>

<p align="center">
  Command-line interface for <a href="https://pub.dev/packages/svgo">SVGO</a> - the SVG optimizer.
</p>

## Installation

```bash
dart pub global activate svgo_cli
```

## Usage

```bash
# Optimize a single file (overwrites input)
svgo input.svg

# Optimize to output directory
svgo -o dist input.svg

# Optimize multiple files
svgo icon1.svg icon2.svg icon3.svg

# Optimize all SVGs in a directory (using glob pattern)
svgo "src/**/*.svg"

# Multipass optimization
svgo -m input.svg

# Custom precision (2 decimal places)
svgo -p 2 input.svg

# Quiet mode (no output messages)
svgo -q input.svg

# Show help
svgo --help

# Show version
svgo --version
```

## Options

| Option | Short | Description |
|--------|-------|-------------|
| `--help` | `-h` | Show help message |
| `--version` | `-v` | Show version information |
| `--output <DIR>` | `-o` | Output directory (default: overwrite input) |
| `--quiet` | `-q` | Suppress output messages |
| `--recursive` | `-r` | Process directories recursively |
| `--precision <NUM>` | `-p` | Float precision (default: 3) |
| `--multipass` | `-m` | Run optimizations multiple times |

## Examples

### Optimize a single file

```bash
svgo logo.svg
```

Output:
```
logo.svg → logo.svg (1234 → 789 bytes, 36.1% saved)

Processed 1 file(s), saved 445 bytes total.
```

### Batch processing

```bash
svgo -o optimized "assets/**/*.svg"
```

### CI/CD Usage

```bash
# Quiet mode for scripts
svgo -q -o dist *.svg
```

## Configuration

The CLI uses the default preset (`preset-default`) with safe optimizations. Future versions will support configuration files for custom plugin settings.

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | Error (file not found, parse error, etc.) |

## License

MIT License - Copyright (c) 2025 iota9star
