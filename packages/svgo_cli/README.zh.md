<p align="center">
  <a href="https://pub.dev/packages/svgo_cli"><img src="https://img.shields.io/pub/v/svgo_cli.svg" alt="pub package"></a>
  <a href="https://github.com/fluttercandies/svgo/blob/main/LICENSE"><img src="https://img.shields.io/github/license/fluttercandies/svgo" alt="license"></a>
</p>

<p align="center">
  <a href="README.md">🇺🇸 English</a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/svgo_cli"><img src="https://img.shields.io/pub/v/svgo_cli.svg" alt="pub package"></a>
  <a href="https://github.com/fluttercandies/svgo/blob/main/LICENSE"><img src="https://img.shields.io/github/license/fluttercandies/svgo" alt="license"></a>
</p>

<p align="center">
<a href="https://pub.dev/packages/svgo">SVGO</a> 的命令行界面 - SVG 优化器。
</p>

## 安装

```bash
dart pub global activate svgo_cli
```

## 使用方法

```bash
# 优化单个文件（覆盖输入文件）
svgo input.svg

# 优化到输出目录
svgo -o dist input.svg

# 优化多个文件
svgo icon1.svg icon2.svg icon3.svg

# 优化目录中的所有 SVG（使用 glob 模式）
svgo "src/**/*.svg"

# 多遍优化
svgo -m input.svg

# 自定义精度（2 位小数）
svgo -p 2 input.svg

# 静默模式（不输出消息）
svgo -q input.svg

# 显示帮助
svgo --help

# 显示版本
svgo --version
```

## 选项

| 选项 | 简写 | 描述 |
|------|------|------|
| `--help` | `-h` | 显示帮助信息 |
| `--version` | `-v` | 显示版本信息 |
| `--output <DIR>` | `-o` | 输出目录（默认：覆盖输入文件） |
| `--quiet` | `-q` | 禁止输出消息 |
| `--recursive` | `-r` | 递归处理目录 |
| `--precision <NUM>` | `-p` | 浮点精度（默认：3） |
| `--multipass` | `-m` | 多次运行优化 |
| `--config <FILE>` | `-c` | 使用自定义配置文件 |
| `--no-config` | | 禁用自动配置文件加载 |

## 示例

### 优化单个文件

```bash
svgo logo.svg
```

输出：
```
logo.svg → logo.svg (1234 → 789 bytes, 36.1% saved)

Processed 1 file(s), saved 445 bytes total.
```

### 批量处理

```bash
svgo -o optimized "assets/**/*.svg"
```

### CI/CD 使用

```bash
# 脚本中使用静默模式
svgo -q -o dist *.svg
```

## 配置

SVGO CLI 支持 YAML 配置文件来自定义优化设置。

### 配置文件搜索

配置文件按以下优先级顺序加载：

1. **显式配置文件**（`--config` 参数）
2. **svgo.yaml**（当前目录）
3. **svgo.yml**（当前目录）
4. **pubspec.yaml**（读取 `svgo:` 键）

使用 `--no-config` 禁用自动配置文件加载。

### 配置文件格式

在项目根目录创建 `svgo.yaml` 文件：

```yaml
# 路径数据的浮点精度
precision: 3

# 运行多遍优化
multipass: true

# 输出格式
pretty: false
indent: 2
finalNewline: true
eol: lf  # 或 'crlf'
useShortTags: true

# 插件配置
plugins:
  # 禁用插件
  - name: removeViewBox
    enabled: false
  
  # 使用默认参数启用插件
  - name: removeDimensions
  
  # 使用自定义参数配置插件
  - name: cleanupNumericValues
    params:
      floatPrecision: 3
      leadingZero: true
      defaultPx: true
      convertToPx: true
  
  - name: convertColors
    params:
      currentColor: true
      names2hex: true
      rgb2hex: true
      convertCase: lower  # 或 'upper'
      shorthex: true
      shortname: true
  
  - name: convertPathData
    params:
      applyTransforms: true
      applyTransformsStroked: true
      makeArcs:
        threshold: 2.5
        tolerance: 0.5
      straightCurves: true
      convertToQ: true
      lineShorthands: true
      convertToZ: true
      curveSmoothShorthands: true
      floatPrecision: 3
      transformPrecision: 5
      smartArcRounding: true
      removeUseless: true
      collapseRepeated: true
      utilizeAbsolute: true
      negativeExtraSpace: true
      forceAbsolutePath: false
  
  - name: cleanupIds
    params:
      remove: true
      minify: true
      preserve:
        - id1
        - id2
      preservePrefixes:
        - icon-
      force: false
  
  - name: removeAttrs
    params:
      attrs:
        - fill
        - stroke
      elemSeparator: ':'
      preserveCurrentColor: false
  
  - name: addAttributesToSVGElement
    params:
      attributes:
        - xmlns:xlink=http://www.w3.org/1999/xlink
        - { role: img }
  
  - name: inlineStyles
    params:
      onlyMatchedOnce: true
      removeMatchedSelectors: true
      useMqs:
        - ""
        - screen
      usePseudos:
        - ""
  
  - name: removeUnknownsAndDefaults
    params:
      unknownContent: true
      unknownAttrs: true
      defaultAttrs: true
      defaultMarkupDeclarations: true
      uselessOverrides: true
      keepDataAttrs: true
      keepAriaAttrs: true
      keepRoleAttr: false
  
  - name: sortAttrs
    params:
      order:
        - id
        - width
        - height
        - viewBox
      xmlnsOrder: front  # 或 'alphabetical'
```

### 使用 pubspec.yaml

您也可以在 `pubspec.yaml` 中添加配置：

```yaml
name: my_app
version: 1.0.0

svgo:
  precision: 3
  multipass: true
  plugins:
    - name: removeViewBox
      enabled: false
    - name: cleanupNumericValues
      params:
        floatPrecision: 3
```

### 所有可用插件

| 插件 | 描述 |
|------|------|
| `addAttributesToSVGElement` | 向根 SVG 元素添加属性 |
| `addClassesToSVGElement` | 向根 SVG 元素添加类 |
| `cleanupAttrs` | 清理属性空白 |
| `cleanupEnableBackground` | 移除 enable-background 属性 |
| `cleanupIds` | 移除或压缩 ID |
| `cleanupListOfValues` | 清理列表值属性 |
| `cleanupNumericValues` | 清理数值 |
| `collapseGroups` | 折叠无用的组 |
| `convertColors` | 转换颜色格式 |
| `convertEllipseToCircle` | 将椭圆转换为圆（如果可能） |
| `convertOneStopGradients` | 转换单停止点渐变 |
| `convertPathData` | 优化路径数据 |
| `convertShapeToPath` | 将形状转换为路径 |
| `convertStyleToAttrs` | 将样式转换为属性 |
| `convertTransform` | 优化变换 |
| `inlineStyles` | 内联 CSS 样式 |
| `mergePaths` | 合并多个路径为一个 |
| `mergeStyles` | 合并样式元素 |
| `minifyStyles` | 压缩样式元素中的 CSS |
| `moveElemsAttrsToGroup` | 将元素属性移动到组 |
| `moveGroupAttrsToElems` | 将组属性移动到元素 |
| `prefixIds` | 为 ID 和引用添加前缀 |
| `removeAttributesBySelector` | 按 CSS 选择器移除属性 |
| `removeAttrs` | 移除指定属性 |
| `removeComments` | 移除注释 |
| `removeDesc` | 移除 desc 元素 |
| `removeDimensions` | 移除 width/height，添加 viewBox |
| `removeDoctype` | 移除 DOCTYPE |
| `removeEditorsNSData` | 移除编辑器命名空间 |
| `removeElementsByAttr` | 按属性移除元素 |
| `removeEmptyAttrs` | 移除空属性 |
| `removeEmptyContainers` | 移除空容器 |
| `removeEmptyText` | 移除空文本元素 |
| `removeHiddenElems` | 移除隐藏元素 |
| `removeMetadata` | 移除元数据 |
| `removeNonInheritableGroupAttrs` | 移除不可继承的组属性 |
| `removeOffCanvasPaths` | 移除画布外的路径 |
| `removeRasterImages` | 移除光栅图像 |
| `removeScripts` | 移除脚本元素 |
| `removeStyleElement` | 移除样式元素 |
| `removeTitle` | 移除标题元素 |
| `removeUnknownsAndDefaults` | 移除未知和默认值 |
| `removeUnusedNS` | 移除未使用的命名空间 |
| `removeUselessDefs` | 移除无用的 defs |
| `removeUselessStrokeAndFill` | 移除无用的描边/填充 |
| `removeViewBox` | 移除 viewBox 属性 |
| `removeXlink` | 移除 xlink 命名空间 |
| `removeXMLNS` | 移除 xmlns 属性 |
| `removeXMLProcInst` | 移除 XML 处理指令 |
| `reusePaths` | 用 use 替换重复路径 |
| `sortAttrs` | 排序属性 |
| `sortDefsChildren` | 排序 defs 子元素 |

## 退出码

| 代码 | 描述 |
|------|------|
| 0 | 成功 |
| 1 | 错误（文件未找到、解析错误等） |

## 许可证

MIT 许可证 - 版权所有 (c) 2025 iota9star