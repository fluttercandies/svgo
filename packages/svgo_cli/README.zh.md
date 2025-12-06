<p align="center">
  <img src="https://raw.githubusercontent.com/fluttercandies/svgo-dart/main/svgo.png" alt="SVGO Logo" width="160" height="160">
</p>

<p align="center">
  <h1>SVGO CLI</h1>
</p>

[SVGO](https://pub.dev/packages/svgo) 的命令行界面 - SVG 优化器。

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

CLI 使用默认预设（`preset-default`）进行安全优化。未来版本将支持配置文件以自定义插件设置。

## 退出码

| 代码 | 描述 |
|------|------|
| 0 | 成功 |
| 1 | 错误（文件未找到、解析错误等） |

## 许可证

MIT 许可证 - 版权所有 (c) 2025 iota9star