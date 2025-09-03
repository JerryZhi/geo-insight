# GEO Insight - 地理洞察分析平台

一个基于Flask的Web应用，用于批量分析文本提示中的品牌和域名提及情况。支持用户注册登录、API配置管理、查询历史记录等功能。

## 🚀 主要功能

- **用户系统**：注册、登录、个人资料管理
- **API配置**：支持多种LLM API（OpenAI、Claude、Gemini等）
- **品牌配置**：自定义品牌和域名监控列表
- **批量分析**：上传CSV文件进行批量文本分析
- **结果展示**：可视化图表展示分析结果
- **历史记录**：查询历史管理和结果下载
- **数据隔离**：用户数据完全隔离存储

## 🛠️ 技术架构

- **后端**：Flask + SQLite
- **前端**：HTML + Bootstrap + JavaScript
- **数据库**：SQLite（支持用户隔离）
- **认证**：Flask-Login + Session管理
- **部署**：支持多种部署方式

## 📋 系统要求

- Python 3.7+
- Flask及相关依赖（见requirements.txt）
- 支持的操作系统：Windows、Linux、macOS

## 🔧 快速开始

### 1. 安装依赖

```bash
cd mpv
pip install -r requirements.txt
```

### 2. 初始化数据库

```bash
python setup.py
```

### 3. 启动应用

**Linux/macOS:**
```bash
python app.py
```

**Windows:**
```bash
start.bat
```

### 4. 访问应用

打开浏览器访问：http://localhost:5000

## 📝 使用流程

1. **注册账号**：创建个人账户
2. **配置API**：设置LLM API密钥和端点
3. **配置品牌**：添加要监控的品牌和域名
4. **上传文件**：上传包含文本提示的CSV文件
5. **开始分析**：系统自动分析文本中的品牌/域名提及
6. **查看结果**：通过图表和表格查看分析结果
7. **下载结果**：将分析结果导出为CSV文件

## 🚀 部署指南

### 自动部署（推荐）

**Linux/Ubuntu:**
```bash
chmod +x deploy.sh
./deploy.sh
```

**本地配置:**
```bash
chmod +x configure.sh
./configure.sh
```

**Windows:**
```batch
configure.bat
```

### 手动部署

详细部署指南请参考：
- [Debian/Ubuntu部署指南](mpv/deployment-guide.md)
- [宝塔面板部署指南](mpv/deployment-bt-panel.md)

## 📁 项目结构

```
mpv/
├── app.py              # 主应用文件
├── auth.py             # 用户认证模块
├── database.py         # 数据库模型
├── requirements.txt    # Python依赖
├── setup.py           # 数据库初始化
├── start.bat          # Windows启动脚本
├── templates/         # HTML模板
├── static/           # 静态资源
├── uploads/          # 用户上传文件
└── results/          # 分析结果文件
```

## 🔐 安全特性

- 用户会话管理
- 密码哈希存储
- SQL注入防护
- 文件上传安全检查
- 用户数据隔离
- API密钥加密存储

## 📊 数据模型

- **users**: 用户账户信息
- **api_configs**: API配置管理
- **brand_configs**: 品牌配置管理
- **query_history**: 查询历史记录
- **user_sessions**: 用户会话管理

## 🤝 贡献指南

1. Fork本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启Pull Request

## 📄 许可证

本项目采用MIT许可证 - 详见 [LICENSE](LICENSE) 文件

## 📞 联系方式

如有问题或建议，欢迎通过以下方式联系：

- GitHub Issues: [提交问题](https://github.com/yourusername/geo-insight/issues)
- Email: your.email@example.com

## 🙏 致谢

感谢所有为本项目做出贡献的开发者和用户！

---

**注意**: 请确保在使用前正确配置API密钥，并遵循相关服务的使用条款。
