"""
LLM Integration Module - UV布局智能分析
使用OpenAI API进行分析和建议
"""

import json
import os
import configparser
from typing import Dict, Any, Optional

# 尝试导入OpenAI
try:
    from openai import OpenAI

    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False
    print("警告: openai库未安装，LLM功能不可用。请运行: pip install openai")


def load_config():
    """加载配置文件"""
    config = configparser.ConfigParser()
    config_path = os.path.join(os.path.dirname(__file__), "config.ini")
    if os.path.exists(config_path):
        config.read(config_path)
    return config


class LLMIntegration:
    """LLM集成类"""

    def __init__(self, config: Dict[str, Any] = None):
        self.config = config or {}
        self.model = self.config.get("llm_model", "gpt-3.5-turbo")
        self.enabled = self.config.get("llm_enabled", False)

        # 从环境变量或配置获取API密钥
        self.api_key = os.environ.get("OPENAI_API_KEY") or self.config.get("api_key", "")

        if self.enabled and OPENAI_AVAILABLE and self.api_key:
            self.client = OpenAI(api_key=self.api_key)
        else:
            self.client = None

    def analyze_report(self, report_text: str) -> Optional[str]:
        """分析UV报告"""
        if not self.client:
            return "LLM功能未配置。请设置OPENAI_API_KEY环境变量或安装openai库。"

        prompt = f"""
你是一位资深的3D技术美术专家，专门负责审查和优化游戏建模的UV布局。

请分析以下UV合规报告，并提供：

1. **问题优先级排序**：哪些问题必须立即修复，哪些可以延后
2. **影响评估**：这些问题对最终渲染效果和游戏性能的潜在影响
3. **具体操作步骤**：在3ds Max UV编辑器中如何修复这些问题
4. **预防建议**：如何避免类似问题再次发生

报告内容：
{report_text}

请用中文回复，格式清晰易读。
"""

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "你是专业的3D技术美术专家。"},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3,
                max_tokens=1000
            )
            return response.choices[0].message.content
        except Exception as e:
            return f"LLM分析失败: {str(e)}"

    def generate_fix_plan(self, issues: list) -> Dict[str, Any]:
        """生成修复计划"""
        plan = {
            "priority_high": [],
            "priority_medium": [],
            "priority_low": [],
            "estimated_time_minutes": 0,
            "steps": []
        }

        for issue in issues:
            severity = issue[1]  # INFO, WARNING, ERROR
            description = issue[3]

            item = {"description": description, "suggestion": issue[7]}

            if severity == "ERROR":
                plan["priority_high"].append(item)
                plan["estimated_time_minutes"] += 15
            elif severity == "WARNING":
                plan["priority_medium"].append(item)
                plan["estimated_time_minutes"] += 5
            else:
                plan["priority_low"].append(item)
                plan["estimated_time_minutes"] += 2

        # 生成步骤
        if plan["priority_high"]:
            plan["steps"].append("1. 首先修复ERROR级别的问题")
        if [i for i in issues if i[1] == "ERROR"]:
            plan["steps"].append("2. 使用Unwrap UVW修改器的Pack功能重新打包UV")
        plan["steps"].append("3. 应用棋盘格纹理验证修复效果")
        plan["steps"].append("4. 重新导出并测试")

        return plan


# 创建全局实例
_config = load_config()
llm_config = {
    "llm_enabled": _config.getboolean("LLM", "enabled", fallback=False),
    "llm_model": _config.get("LLM", "model", fallback="gpt-3.5-turbo"),
    "api_key": _config.get("LLM", "api_key", fallback="")
}
llm_integration = LLMIntegration(llm_config)