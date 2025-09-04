#!/usr/bin/env python3
"""
WSGI 入口文件
用于 Gunicorn 等 WSGI 服务器启动 Flask 应用
"""

import sys
import os

# 添加应用目录到 Python 路径
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, current_dir)

try:
    from app import app
    # 确保应用对象可用
    application = app
    
    if __name__ == "__main__":
        # 如果直接运行此文件，启动开发服务器
        port = int(os.environ.get('PORT', 5000))
        app.run(host='127.0.0.1', port=port, debug=False)
        
except ImportError as e:
    print(f"Failed to import Flask app: {e}")
    print(f"Current working directory: {os.getcwd()}")
    print(f"Python path: {sys.path}")
    sys.exit(1)
