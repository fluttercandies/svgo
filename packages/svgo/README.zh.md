<p align="center">
  <img src="https://raw.githubusercontent.com/fluttercandies/svgo/main/svgo.png" alt="SVGO Logo" width="160" height="160">
</p>

<h1 align="center">SVGO</h1>

<p align="center">
  <a href="README.md">🇺🇸 English</a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/svgo"><img src="https://img.shields.io/pub/v/svgo.svg" alt="pub package"></a>
  <a href="https://github.com/fluttercandies/svgo/blob/main/LICENSE"><img src="https://img.shields.io/github/license/fluttercandies/svgo" alt="license"></a>
</p>


<p align="center">
一个专为 Dart 设计的综合 SVG 优化库，灵感来源于生态系统中经过验证的优化技术。
</p>

## 特性

- 将 SVG 文件解析为抽象语法树 (XAST)
- 应用各种优化插件
- 将优化后的 AST 序列化回 SVG 字符串
- 完全可配置的插件系统
- 支持多遍优化
- 54 个内置优化插件，提供全面的优化覆盖
- 使用 csslib 进行 CSS 样式解析和计算
- 路径数据操作工具
- CSS 选择器匹配

## 安装

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  svgo: ^1.0.0
```

或运行：

```bash
dart pub add svgo
```

## 使用方法

### 基本使用

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

### 带配置使用

```dart
final result = optimize(input, SvgoConfig(
  multipass: true,        // 多遍优化
  floatPrecision: 2,      // 浮点精度
  plugins: ['preset-default'],
));
```

### 自定义插件

```dart
final result = optimize(input, SvgoConfig(
  plugins: [
    'removeComments',
    {
      'name': 'cleanupNumericValues',
      'params': {'floatPrecision': 2},
    },
  ],
));
```

### Data URI 输出

```dart
final result = optimize(input, SvgoConfig(
  datauri: DataUriType.base64,
));
// result.data: data:image/svg+xml;base64,...
```

### 操作 AST

```dart
// 将 SVG 解析为 AST
final ast = parseSvg(svgString);

// 遍历和修改 AST
for (final child in ast.children) {
  if (child is XastElement && child.name == 'rect') {
    child.attributes['fill'] = 'blue';
  }
}

// 将 AST 转换回字符串
final output = stringifySvg(ast);
```

### CSS 样式计算

```dart
final ast = parseSvg(svgWithStyles);
final stylesheet = collectStylesheet(ast);
final styles = computeStyle(stylesheet, element);

if (styles['fill'] case StaticStyle(:final value)) {
  print('Fill color: $value');
}
```

### 路径数据工具

```dart
// 解析路径数据
final pathData = parsePathData('M10 20 L30 40 Z');

// 转换为绝对坐标
final absolute = convertRelativeToAbsolute(pathData);

// 转换回字符串
final pathString = stringifyPathData(absolute);
```

## 可用插件

### 清理插件

| 插件 | 描述 |
|--------|------|
| `cleanupAttrs` | 从属性中移除换行符和尾随空格 |
| `cleanupEnableBackground` | 移除或修复已废弃的 enable-background 属性 |
| `cleanupIds` | 移除或压缩未使用的 ID |
| `cleanupListOfValues` | 四舍五入列表类属性中的数值 |
| `cleanupNumericValues` | 四舍五入数值，移除默认单位 |

### 移除插件

| 插件 | 描述 |
|--------|------|
| `removeAttrs` | 移除指定属性 |
| `removeAttributesBySelector` | 通过 CSS 选择器移除属性 |
| `removeComments` | 移除 XML 注释 |
| `removeDeprecatedAttrs` | 移除已废弃的 SVG 属性 |
| `removeDesc` | 移除 `<desc>` 元素 |
| `removeDimensions` | 移除 width/height，如果缺少则添加 viewBox |
| `removeDoctype` | 移除 DOCTYPE 声明 |
| `removeEditorsNSData` | 移除编辑器命名空间和元素 |
| `removeElementsByAttr` | 通过属性值移除元素 |
| `removeEmptyAttrs` | 移除空属性 |
| `removeEmptyContainers` | 移除空容器元素 |
| `removeEmptyText` | 移除空文本元素 |
| `removeHiddenElems` | 移除隐藏元素 |
| `removeMetadata` | 移除 `<metadata>` 元素 |
| `removeNonInheritableGroupAttrs` | 移除不可继承的组属性 |
| `removeOffCanvasPaths` | 移除 viewBox 外部的路径 |
| `removeRasterImages` | 移除光栅图像元素 |
| `removeScripts` | 移除脚本元素和事件处理程序 |
| `removeStyleElement` | 移除 `<style>` 元素 |
| `removeTitle` | 移除 `<title>` 元素 |
| `removeUnknownsAndDefaults` | 移除未知元素和默认值 |
| `removeUnusedNS` | 移除未使用的命名空间声明 |
| `removeUselessDefs` | 移除 `<defs>` 中没有 id 的元素 |
| `removeUselessStrokeAndFill` | 移除无用的 stroke 和 fill 属性 |
| `removeViewBox` | 当存在 width/height 时移除 viewBox |
| `removeXlink` | 移除已废弃的 xlink 命名空间 |
| `removeXMLNS` | 移除 xmlns 属性（用于嵌入式 SVG）|
| `removeXMLProcInst` | 移除 XML 处理指令 |

### 转换插件

| 插件 | 描述 |
|--------|------|
| `convertColors` | 将颜色转换为更短的格式 |
| `convertEllipseToCircle` | 在可能时将椭圆转换为圆 |
| `convertOneStopGradients` | 将单停止点渐变转换为纯色 |
| `convertPathData` | 优化路径数据 |
| `convertShapeToPath` | 将基本形状转换为路径 |
| `convertStyleToAttrs` | 将样式转换为呈现属性 |
| `convertTransform` | 优化变换属性 |

### 合并和移动插件

| 插件 | 描述 |
|--------|------|
| `collapseGroups` | 折叠无用的组 |
| `mergePaths` | 合并相邻的路径元素 |
| `mergeStyles` | 合并多个样式元素 |
| `moveElemsAttrsToGroup` | 将公共属性移动到组 |
| `moveGroupAttrsToElems` | 将组属性移动到子元素 |

### 排序插件

| 插件 | 描述 |
|--------|------|
| `sortAttrs` | 排序属性以获得更好的压缩 |
| `sortDefsChildren` | 排序 defs 子元素以获得更好的压缩 |

### 样式插件

| 插件 | 描述 |
|--------|------|
| `inlineStyles` | 将 CSS 样式内联到元素 |
| `minifyStyles` | 压缩样式元素中的 CSS |

### 其他插件

| 插件 | 描述 |
|--------|------|
| `addAttributesToSVGElement` | 向 SVG 元素添加属性 |
| `addClassesToSVGElement` | 向 SVG 元素添加类 |
| `applyTransforms` | 将变换应用到路径数据 |
| `prefixIds` | 为 ID 添加前缀 |
| `reusePaths` | 用 `<use>` 替换重复的路径 |

## 预设

### preset-default

默认预设包含安全的优化：

```dart
final result = optimize(input, SvgoConfig(
  plugins: ['preset-default'],
));
```

您可以覆盖特定的插件设置：

```dart
final result = optimize(input, SvgoConfig(
  plugins: [
    {
      'name': 'preset-default',
      'params': {
        'overrides': {
          'removeComments': false,  // 禁用
          'cleanupNumericValues': {
            'floatPrecision': 2,
          },
        },
      },
    },
  ],
));
```

## API 参考

### optimize(input, [config])

优化 SVG 字符串。

**参数：**
- `input` (String): 要优化的 SVG 字符串
- `config` (SvgoConfig?): 可选配置

**返回：** `SvgoOutput`，包含：
- `data` (String): 优化后的 SVG 字符串

### parseSvg(input, [path])

将 SVG 字符串解析为 XAST。

**参数：**
- `input` (String): 要解析的 SVG 字符串
- `path` (String?): 用于错误消息的可选文件路径

**返回：** `XastRoot`

### stringifySvg(ast, [options])

将 XAST 转换回 SVG 字符串。

**参数：**
- `ast` (XastRoot): 要字符串化的 AST
- `options` (StringifyOptions?): 格式化选项

**返回：** String

### collectStylesheet(root)

从样式元素收集 CSS 规则。

**参数：**
- `root` (XastRoot): 解析后的 SVG AST

**返回：** `Stylesheet`

### computeStyle(stylesheet, element)

计算元素的样式。

**参数：**
- `stylesheet` (Stylesheet): 收集的样式表
- `element` (XastElement): 目标元素

**返回：** `Map<String, ComputedStyle>`

## 许可证

MIT 许可证 - 版权所有 (c) 2025 iota9star

详见 [LICENSE](LICENSE)。

## 致谢

感谢 [SVGO](https://github.com/svg/svgo) 提供的灵感和参考。