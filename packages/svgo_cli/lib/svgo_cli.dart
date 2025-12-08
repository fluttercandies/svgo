/// SVGO CLI - Command-line interface for SVG optimization.
///
/// This package provides the `svgo` command for optimizing SVG files from
/// the command line.
///
/// ## Configuration Files
///
/// The CLI supports configuration files in the following formats:
/// - `svgo.yaml` or `svgo.yml` (priority)
/// - `pubspec.yaml` with a `svgo:` key
///
/// See [SvgoFileConfig] for configuration options.
library;

export 'src/cli.dart' show run;
export 'src/config.dart'
    show SvgoFileConfig, PluginConfig, loadConfig, loadConfigFromFile;
