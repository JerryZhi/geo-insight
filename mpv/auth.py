"""
用户认证和会话管理
"""
from functools import wraps
from flask import request, session, redirect, url_for, g
from database import db

def login_required(f):
    """登录验证装饰器"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        
        # 验证session是否有效
        user = db.get_user_by_id(session['user_id'])
        if not user:
            session.clear()
            return redirect(url_for('login'))
        
        g.current_user = user
        return f(*args, **kwargs)
    return decorated_function

def get_current_user():
    """获取当前登录用户"""
    if 'user_id' in session:
        return db.get_user_by_id(session['user_id'])
    return None

def create_user_directories(user_id):
    """为用户创建专属目录"""
    import os
    
    user_upload_dir = os.path.join('uploads', str(user_id))
    user_results_dir = os.path.join('results', str(user_id))
    
    os.makedirs(user_upload_dir, exist_ok=True)
    os.makedirs(user_results_dir, exist_ok=True)
    
    return user_upload_dir, user_results_dir

def get_user_file_path(user_id, filename, file_type='upload'):
    """获取用户文件的完整路径"""
    import os
    
    if file_type == 'upload':
        return os.path.join('uploads', str(user_id), filename)
    elif file_type == 'result':
        return os.path.join('results', str(user_id), filename)
    else:
        raise ValueError("file_type must be 'upload' or 'result'")
