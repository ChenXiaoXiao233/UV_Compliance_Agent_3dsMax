"""
LLM Integration Module for UV Compliance Agent
支持小米 MiMo API（兼容 OpenAI 接口格式）
"""

import os
import json
import logging
import configparser
from typing import Dict, Any, Optional, List

try:
    from openai import OpenAI
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False
    print("⚠️ 警告: openai库未安装。请运行: pip install openai")

logger = logging.getLogger(__name__)


def load_config(config_path: str = None) -> configparser.ConfigParser:
    if config_path is None:
        config_path = os.path.join(os.path.dirname(__file__), "config.ini")
    config = configparser.ConfigParser()
    if os.path.exists(config_path):
        config.read(config_path, encoding='utf-8')
    else:
        config['LLM'] = {
            'enabled': 'false',
            'provider': 'xiaomimimo',
            'xiaomimimo_api_key': '',
            'xiaomimimo_base_url': 'https://api.xiaomimimo.com/v1',
            'xiaomimimo_model': 'MiMo-7B-Instruct',
            'request_timeout': '60',
            'max_retries': '3'
        }
    return config


class LLMIntegration:
    def __init__(self, config: Dict[str, Any] = None):
        self.config = config or {}
        file_config = load_config()
        llm_section = file_config['LLM']
        
        self.enabled = self.config.get('enabled', llm_section.getboolean('enabled', fallback=False))
        self.provider = self.config.get('provider', llm_section.get('provider', fallback='xiaomimimo'))
        
        if self.provider == 'xiaomimimo':
            self.api_key = self.config.get('api_key', llm_section.get('xiaomimimo_api_key', fallback=''))
            self.base_url = self.config.get('base_url', llm_section.get('xiaomimimo_base_url', fallback='https://api.xiaomimimo.com/v1'))
            self.model = self.config.get('model', llm_section.get('xiaomimimo_model', fallback='MiMo-7B-Instruct'))
        elif self.provider == 'openrouter':
            self.api_key = self.config.get('api_key', llm_section.get('openrouter_api_key', fallback=''))
            self.base_url = self.config.get('base_url', llm_section.get('openrouter_base_url', fallback='https://openrouter.ai/api/v1'))
            self.model = self.config.get('model', llm_section.get('openrouter_model', fallback='xiaomimimo/mimo-7b-instruct'))
        else:
            self.api_key = self.config.get('api_key', '')
            self.base_url = self.config.get('base_url', None)
            self.model = self.config.get('model', 'gpt-3.5-turbo')
        
        self.timeout = int(self.config.get('timeout', llm_section.get('request_timeout', fallback='60')))
        self.max_retries = int(self.config.get('max_retries', llm_section.get('max_retries', fallback='3')))
        
        if not self.api_key:
            self.api_key = os.environ.get('XIAOMI_MIMO_API_KEY') or os.environ.get('OPENROUTER_API_KEY') or os.environ.get('OPENAI_API_KEY')
        
        self.client = None
        if self.enabled and OPENAI_AVAILABLE and self.api_key:
            try:
                if self.base_url:
                    self.client = OpenAI(api_key=self.api_key, base_url=self.base_url, timeout=self.timeout, max_retries=self.max_retries)
                else:
                    self.client = OpenAI(api_key=self.api_key, timeout=self.timeout, max_retries=self.max_retries)
                logger.info(f"LLM客户端初始化成功 - Provider: {self.provider}, Model: {self.model}")
            except Exception as e:
                logger.error(f"LLM客户端初始化失败: {e}")
                self.client = None
        elif not OPENAI_AVAILABLE:
            logger.warning("openai库未安装，LLM功能不可用")
        elif not self.api_key:
            logger.warning("未设置API密钥，LLM功能不可用")
    
    def is_available(self) -> bool:
        return self.enabled and self.client is not None
    
    def analyze_report(self, report_text: str) -> Optional[str]:
        if not self.is_available():
            return "LLM功能未配置。请检查：\n1. config.ini中LLM.enabled设为true\n2. 已安装openai库 (pip install openai)\n3. 已设置有效的API密钥"
        
        prompt = f"""你是一位资深的3D技术美术专家，专门负责审查和优化游戏建模的UV布局。

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
                    {"role": "system", "content": "你是专业的3D技术美术专家，擅长UV布局和纹理优化。"},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3,
                max_tokens=1500,
                top_p=0.9
            )
            result = response.choices[0].message.content
            logger.info("LLM分析完成")
            return result
        except Exception as e:
            error_msg = f"LLM分析失败: {str(e)}"
            logger.error(error_msg)
            return error_msg
    
    def generate_fix_plan(self, issues: List[Any]) -> Dict[str, Any]:
        plan = {
            "priority_high": [],
            "priority_medium": [],
            "priority_low": [],
            "estimated_time_minutes": 0,
            "steps": [],
            "llm_suggestions": ""
        }
        if not issues:
            return plan
        
        issues_text = ""
        for issue in issues:
            if isinstance(issue, (list, tuple)) and len(issue) >= 4:
                severity = issue[1] if len(issue) > 1 else "UNKNOWN"
                description = issue[3] if len(issue) > 3 else str(issue)
                issues_text += f"[{severity}] {description}\n"
            elif isinstance(issue, dict):
                severity = issue.get('severity', 'UNKNOWN')
                description = issue.get('description', '')
                issues_text += f"[{severity}] {description}\n"
            else:
                issues_text += f"{issue}\n"
        
        if self.is_available():
            prompt = f"""根据以下UV问题列表，生成一个结构化的修复计划。

问题列表：
{issues_text}

请以JSON格式输出，包含：
{{
    "priority_high": ["问题描述1", "问题描述2"],
    "priority_medium": ["..."],
    "priority_low": ["..."],
    "estimated_time_minutes": 数字,
    "steps": ["步骤1", "步骤2", ...],
    "llm_suggestions": "额外建议文本"
}}
"""
            try:
                response = self.client.chat.completions.create(
                    model=self.model,
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.2,
                    max_tokens=800
                )
                content = response.choices[0].message.content
                import re
                json_match = re.search(r'\{.*\}', content, re.DOTALL)
                if json_match:
                    llm_plan = json.loads(json_match.group())
                    plan.update(llm_plan)
            except Exception as e:
                logger.warning(f"LLM生成修复计划失败，使用默认规则: {e}")
        
        if not plan["priority_high"] and not plan["priority_medium"]:
            for issue in issues:
                sev = issue[1] if isinstance(issue, (list, tuple)) and len(issue) > 1 else ""
                desc = issue[3] if isinstance(issue, (list, tuple)) and len(issue) > 3 else str(issue)
                if sev == "ERROR":
                    plan["priority_high"].append({"description": desc, "suggestion": "立即修复"})
                    plan["estimated_time_minutes"] += 15
                elif sev == "WARNING":
                    plan["priority_medium"].append({"description": desc, "suggestion": "建议修复"})
                    plan["estimated_time_minutes"] += 5
                else:
                    plan["priority_low"].append({"description": desc, "suggestion": "可选修复"})
                    plan["estimated_time_minutes"] += 2
        
        if not plan["steps"]:
            plan["steps"] = [
                "1. 使用Unwrap UVW修改器的Pack功能重新打包UV",
                "2. 检查并修复翻转的面（Flip功能）",
                "3. 应用棋盘格纹理验证效果",
                "4. 重新导出并测试"
            ]
        return plan
    
    def test_connection(self) -> bool:
        if not self.is_available():
            print("LLM未配置或不可用")
            return False
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": "测试连接，请回复'OK'"}],
                max_tokens=10,
                temperature=0
            )
            print(f"连接成功！响应: {response.choices[0].message.content}")
            return True
        except Exception as e:
            print(f"连接失败: {e}")
            return False


_config = load_config()
llm_integration = LLMIntegration()


if __name__ == "__main__":
    print("=== 测试LLM集成模块 ===")
    if llm_integration.is_available():
        print(f"✅ LLM已启用 - Provider: {llm_integration.provider}, Model: {llm_integration.model}")
        llm_integration.test_connection()
    else:
        print("❌ LLM未启用，请检查配置")
