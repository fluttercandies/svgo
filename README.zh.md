<p align="center">
  <img src="svgo.png" alt="SVGO Logo" width="160" height="160">
</p>

<h1 align="center">SVGO Dart</h1>

<p align="center">
  <a href="README.md">🇺🇸 English</a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/svgo"><img src="https://img.shields.io/pub/v/svgo.svg" alt="pub package"></a>
  <a href="https://github.com/fluttercandies/svgo/blob/main/LICENSE"><img src="https://img.shields.io/github/license/fluttercandies/svgo" alt="license"></a>
</p>

<p align="center">
一个专为 Dart/Flutter 生态系统设计的综合 SVG 优化库，提供强大的工具来减小文件大小，同时保持视觉质量。灵感来源于流行 SVG 工具中使用的成熟优化技术。
</p>

## 包

| 包                                                 | 描述             | pub.dev                                                                                        |
|---------------------------------------------------|----------------|------------------------------------------------------------------------------------------------|
| [svgo](packages/svgo)                             | 核心 SVGO 库      | [![pub package](https://img.shields.io/pub/v/svgo.svg)](https://pub.dev/packages/svgo)         |
| [svgo_cli](packages/svgo_cli)                     | 命令行界面          | [![pub package](https://img.shields.io/pub/v/svgo_cli.svg)](https://pub.dev/packages/svgo_cli) |
| [svgo_hooks_example](packages/svgo_hooks_example) | Build hooks 示例 |                                                                                                |

## 特性

- ✅ 将 SVG 文件解析为抽象语法树 (XAST)
- ✅ 应用各种优化插件
- ✅ 将优化后的 AST 序列化回 SVG 字符串
- ✅ 完全可配置的插件系统
- ✅ 支持多遍优化
- ✅ 54 个内置优化插件（与 Node.js SVGO 完全兼容）
- ✅ CSS 样式解析和计算
- ✅ 路径数据操作工具
- ✅ 命令行界面

## 快速开始

### 作为库使用

在 `pubspec.yaml` 中添加 `svgo`：

```yaml
dependencies:
  svgo: any
```

然后在 Dart 代码中使用：

```dart
import 'package:svgo/svgo.dart';

void main() {
  final input = '''
    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
      <!-- A red rectangle -->
      <rect x="0" y="0" width="100" height="100" fill="red"/>
    </svg>
  ''';

  final result = optimize(input);
  print(result.data);
  // 输出: <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect width="100" height="100" fill="red"/></svg>
}
```

### 作为 CLI 工具

全局安装：

```bash
dart pub global activate svgo_cli
```

然后使用：

```bash
# 优化单个文件（覆盖输入文件）
svgo input.svg

# 优化到输出目录
svgo -o dist input.svg

# 优化目录中的所有 SVG
svgo "src/**/*.svg"

# 使用自定义精度进行多遍优化
svgo -m -p 2 icon.svg
```

## 配置

### 使用预设

```dart
final result = optimize(input, SvgoConfig(
  plugins: [presetDefault],
));
```

### 自定义插件配置

```dart
final result = optimize(input, SvgoConfig(
  plugins: [
    removeComments,
    removeMetadata,
    cleanupNumericValues.withParams(
      CleanupNumericValuesParams(floatPrecision: 2),
    ),
  ],
));
```

### 多遍优化

```dart
final result = optimize(input, SvgoConfig(
  multipass: true,
));
```

## 可用插件

### 清理插件
- `cleanupAttrs` - 从属性中清理换行符和尾随空格
- `cleanupNumericValues` - 四舍五入数值，移除默认单位

### 移除插件
- `removeComments` - 移除注释
- `removeDesc` - 移除 `<desc>` 元素
- `removeDoctype` - 移除 DOCTYPE 声明
- `removeEditorsNSData` - 移除编辑器特定的命名空间
- `removeEmptyAttrs` - 移除空属性
- `removeEmptyContainers` - 移除空容器元素
- `removeEmptyText` - 移除空文本元素
- `removeMetadata` - 移除 `<metadata>` 元素
- `removeTitle` - 移除 `<title>` 元素
- `removeUnusedNS` - 移除未使用的命名空间声明
- `removeUselessDefs` - 移除 `<defs>` 中没有 id 的元素
- `removeXMLProcInst` - 移除 XML 处理指令

### 转换插件
- `convertColors` - 将颜色值转换为更短的格式
- `convertEllipseToCircle` - 当 rx=ry 时将椭圆转换为圆
- `convertShapeToPath` - 将形状转换为路径元素

### 结构插件
- `collapseGroups` - 折叠无用的组
- `moveElemsAttrsToGroup` - 将公共属性移动到父组
- `moveGroupAttrsToElems` - 将组变换移动到子元素
- `sortAttrs` - 排序元素属性
- `sortDefsChildren` - 排序 `<defs>` 子元素以获得更好的压缩

### 样式插件
- `mergeStyles` - 合并多个样式元素

## 开发

本项目使用 [Melos](https://melos.invertase.dev/) 进行 monorepo 管理。

```bash
# 安装 melos
dart pub global activate melos

# 引导（为所有包安装依赖）
melos bootstrap

# 运行分析
melos analyze

# 运行测试
melos test

# 格式化代码
melos format
```

## 许可证

MIT 许可证 - 版权所有 (c) 2025 iota9star

详见 [LICENSE](LICENSE)。

## 致谢

感谢 [SVGO](https://github.com/svg/svgo) 提供的灵感和参考。