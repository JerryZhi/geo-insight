# GEO Insight MVP

一个简化版的AI时代品牌监测工具，用于监测品牌在大语言模型回复中的可见度和提及情况。

## 功能特性

- 📊 **批量Prompt测试**: 支持CSV/Excel格式的prompt清单上传
- 🎯 **品牌监测**: 自动识别品牌名称和域名在AI回复中的提及
- 🤖 **多LLM支持**: 支持OpenAI、Claude等主流LLM API
- 📈 **结果分析**: 提供详细的统计分析和可视化图表
- 💾 **数据导出**: 支持CSV格式的结果导出

## 快速开始

### 环境要求
- Python 3.7+
- 网络连接（用于调用LLM API）

### 安装运行

1. **Windows用户（推荐）**:
   ```bash
   # 双击运行 start.bat 文件
   start.bat
   ```

2. **手动安装**:
   ```bash
   # 创建虚拟环境
   python -m venv venv
   
   # 激活虚拟环境
   # Windows
   venv\Scripts\activate
   # Linux/Mac
   source venv/bin/activate
   
   # 安装依赖
   pip install -r requirements.txt
   
   # 启动应用
   python app.py
   ```

3. 打开浏览器访问: http://localhost:5000

## 使用说明

### 1. 准备Prompt文件
创建CSV或Excel文件，第一列包含要测试的提示词。项目提供了 `sample_prompts.csv` 作为示例。

### 2. 配置监测参数
- **品牌名称**: 要监测的品牌，多个用逗号分隔
- **网站域名**: 要监测的域名（可选）
- **LLM API配置**: 
  - OpenAI: `https://api.openai.com/v1/chat/completions`
  - Claude: `https://api.anthropic.com/v1/messages`
  - 或自定义API端点

### 3. 运行分析
系统会自动:
- 批量向LLM发送queries
- 分析回复中的品牌提及情况
- 生成统计报告和可视化图表

### 4. 查看结果
- 在线查看详细的分析结果
- 下载CSV格式的完整报告

## API支持

目前支持以下LLM API格式:
- **OpenAI** (GPT-3.5, GPT-4)
- **Anthropic Claude**
- **通用REST API格式**

## MVP版本限制

- 最多处理20个prompts
- 本地文件存储
- 基础的品牌提及检测算法
- 简化的错误处理

## 项目结构

```
geo-insight-mvp/
├── app.py                 # Flask主应用
├── requirements.txt       # Python依赖
├── start.bat             # Windows启动脚本
├── sample_prompts.csv    # 示例prompt文件
├── templates/            # HTML模板
│   ├── index.html       # 主页
│   ├── configure.html   # 配置页面
│   └── results.html     # 结果页面
├── uploads/             # 上传文件存储
└── results/             # 分析结果存储
```

## 技术栈

- **后端**: Python Flask
- **前端**: Bootstrap 5 + Chart.js
- **数据处理**: Pandas
- **HTTP客户端**: aiohttp (异步)
- **文件支持**: CSV, Excel (xlsx/xls)

## 注意事项

1. 请确保LLM API密钥有足够的调用额度
2. 网络连接稳定，API调用可能需要一些时间
3. 结果文件保存在本地 `results/` 目录
4. 敏感数据请谨慎处理，不要上传到公共环境

## 后续发展

这是一个MVP版本，后续可以扩展:
- 更多LLM API支持
- 高级品牌检测算法
- 数据库存储
- 用户管理系统
- 定时任务和监控
- API接口开放

## 许可证

本项目为演示用途，请遵守相关LLM服务的使用条款。
