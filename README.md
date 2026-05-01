# UV布局合规性Agent for 3ds Max

基于3ds Max API + MaxScript + LLM的UV布局合规性检测与修复工具。

## 功能特性

- ✅ UV翻转检测 (`selectInvertedFaces`)
- ✅ UV重叠检测 (`selectOverlappedFaces`)
- ✅ UV超出范围检测 (`getArea`)
- ✅ UV拉伸/变形分析 (面积比例法)
- ✅ 孤立UV顶点检测
- ✅ 多重UV通道检测
- ✅ 自动修复（翻转、归一化、打包、放松）
- ✅ LLM智能分析（可选）
- ✅ UI界面

## 安装

1. 将所有`.ms`文件放入3ds Max的`scripts`目录
2. （可选）安装Python依赖用于LLM功能：
