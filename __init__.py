"""
UV Layout Compliance Agent for 3ds Max
基于 3ds Max API + MaxScript + LLM 的 UV 布局合规性检测与修复工具
"""

__version__ = "1.0.0"
__author__ = "ChenXiaoXiao233"
__description__ = "UV layout compliance detection and auto-fix tool for 3ds Max"

from .llm_integration import LLMIntegration

__all__ = ["LLMIntegration"]
