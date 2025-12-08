<p align="center">
  <img src="https://raw.githubusercontent.com/fluttercandies/svgo/main/svgo.png" alt="SVGO Logo" width="160" height="160">
</p>

<h1 align="center">SVGO Hooks Example</h1>

<p align="center">
  <a href="README.md">🇺🇸 English</a>
</p>

<p align="center">
  演示如何使用 Dart Hooks 自动优化 SVG 资源的项目。
</p>

> **版本说明**: 构建钩子支持在 Dart 3.10 中引入。

这是一个演示项目，展示如何使用 Dart Hooks 在构建时自动优化 SVG 资源。钩子会在 SVG 文件打包到应用程序之前进行优化，确保更小的文件大小和更好的性能。

## Hook 示例

```dart
import 'dart:io';
import 'package:hooks/hooks.dart';
import 'package:svgo/svgo.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  await build(args, (input, output) async {
    final assetsDir = Directory('assets');
    if (!await assetsDir.exists()) return;

    final svgoConfig = SvgoConfig(
      plugins: [
        removeComments,
        removeMetadata,
        cleanupAttrs,
        mergeStyles,
        convertColors,
      ],
      multipass: true,
    );

    final svgFiles = assetsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.svg'))
        .toList();

    for (final svgFile in svgFiles) {
      final originalContent = await svgFile.readAsString();
      final result = optimize(originalContent, svgoConfig);
      
      final relativePath = path.relative(svgFile.path, from: 'assets');
      final outputFile = File(path.join(input.outputDirectory.path, relativePath));
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsString(result.data);
    }
  });
}
```

## 功能特性

- 🚀 **自动优化**: 在构建时自动优化所有 SVG 文件
- 📦 **零配置**: 使用合理的默认配置，无需手动设置
- 📊 **压缩统计**: 显示每个文件的压缩率和大小变化
- 🔧 **可配置**: 支持自定义 SVGO 插件和参数
- 🧪 **完整测试**: 包含完整的测试套件

## 项目结构

```
svgo_hooks_example/
├── assets/                  # 原始 SVG 文件
├── hooks/
│   └── build.dart           # 构建钩子脚本
├── lib/
│   └── svgo_hooks_example.dart  # 库文件
├── example/
│   └── usage_example.dart   # 使用示例
├── bin/
│   ├── svgo_hooks_example.dart  # 主程序入口
│   └── optimize_svgs.dart      # 直接优化脚本
└── pubspec.yaml
```

## 安装和使用

### 1. 添加依赖

在你的 `pubspec.yaml` 中添加：

```yaml
dependencies:
  svgo: any
  hooks: ^1.0.0
  path: ^1.8.0
```

### 2. 创建构建钩子

在 `hooks/build.dart` 中创建钩子脚本（参考上面的示例）。

### 3. 运行钩子

钩子会在以下命令时自动运行：

```bash
dart run              # 运行应用
dart build            # 构建应用  
dart test             # 运行测试
```

### 4. 在代码中使用

```dart
import 'package:svgo_hooks_example/svgo_hooks_example.dart';

// 获取优化后的 SVG
final optimizedSvg = await SvgOptimizer.getOptimizedSvg('icons/app_icon.svg');

// 列出所有可用的 SVG 文件
final availableSvgs = await SvgOptimizer.listAvailableSvgs();
```

## 工作原理

1. **钩子触发**: 当运行 `dart run`、`dart build` 或 `dart test` 时
2. **文件扫描**: 扫描 `assets/` 目录中的所有 `.svg` 文件
3. **SVG 优化**: 使用 SVGO 对每个文件进行优化
4. **输出保存**: 将优化后的文件保存到构建输出目录
5. **自动打包**: Dart SDK 自动将优化后的文件打包到应用中

## 优势

- **自动优化**: SVG 文件在构建时优化，无需手动步骤
- **一致结果**: 所有 SVG 使用相同的优化设置
- **更好性能**: 优化后的 SVG 更小，加载更快
- **零运行时开销**: 优化在构建时发生，而非运行时

## 许可证

本项目采用 BSD-3-Clause 许可证。