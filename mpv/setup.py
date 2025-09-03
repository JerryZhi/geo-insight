#!/usr/bin/env python3
"""
GEO Insight 启动脚本
初始化数据库并启动Flask应用
"""
import os
import sys
from database import db

def init_database():
    """初始化数据库"""
    print("正在初始化数据库...")
    try:
        db.init_database()
        print("✓ 数据库初始化成功")
        return True
    except Exception as e:
        print(f"✗ 数据库初始化失败: {e}")
        return False

def create_sample_user():
    """创建示例用户账号"""
    print("创建示例用户账号...")
    try:
        user_id = db.create_user("admin", "admin@example.com", "123456")
        if user_id:
            print("✓ 示例用户创建成功")
            print("  用户名: admin")
            print("  密码: 123456")
            print("  邮箱: admin@example.com")
            
            # 创建用户目录
            from auth import create_user_directories
            create_user_directories(user_id)
            print("✓ 用户目录创建成功")
            
            return True
        else:
            print("! 用户可能已存在，跳过创建")
            return True
    except Exception as e:
        print(f"✗ 用户创建失败: {e}")
        return False

def main():
    """主函数"""
    print("="*50)
    print("GEO Insight 启动向导")
    print("="*50)
    
    # 检查必要目录
    directories = ['uploads', 'results', 'templates']
    for directory in directories:
        if not os.path.exists(directory):
            os.makedirs(directory)
            print(f"✓ 创建目录: {directory}")
    
    # 初始化数据库
    if not init_database():
        print("数据库初始化失败，无法继续")
        return False
    
    # 创建示例用户
    if not create_sample_user():
        print("用户创建失败，但可以继续运行")
    
    print("="*50)
    print("🎉 初始化完成！")
    print("")
    print("现在可以启动应用:")
    print("  python app.py")
    print("")
    print("或者使用批处理脚本:")
    print("  start.bat")
    print("")
    print("访问地址: http://localhost:5000")
    print("="*50)
    
    return True

if __name__ == "__main__":
    main()
