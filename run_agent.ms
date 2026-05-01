-- UV Compliance Agent - 入口脚本
-- 在3ds Max中运行此脚本启动Agent

-- 加载模块
fileIn "uv_agent_core.ms"
fileIn "uv_detector.ms"
fileIn "uv_fixer.ms"

global uvAgentUI

-- 创建UI
fn createUIAgent = (
    local ui = newRolloutFloater "UV合规性Agent" 450 550
    
    -- 主面板
    rollout mainRollout "UV布局合规性检测" (
        -- 物体选择组
        groupBox grpObject "目标物体" pos:[10,10] width:[420,60]
        label lblSelected "当前选择:" pos:[20,30] width:[80,20]
        edittext edtSelected "" pos:[100,28] width:[250,20]
        button btnRefresh "刷新" pos:[360,26] width:[50,24]
        
        -- 参数设置组
        groupBox grpParams "检测参数" pos:[10,80] width:[420,140]
        label lblDensity "目标贴图密度 (px/cm):" pos:[20,105] width:[160,20]
        spinner spnDensity "" pos:[190,103] width:[80,20] range:[1,100,10.24] type:#float
        label lblTolerance "密度容忍度 (%):" pos:[20,135] width:[120,20]
        spinner spnTolerance "" pos:[150,133] width:[80,20] range:[0,50,15] type:#float
        label lblSpacing "UV岛间距 (%):" pos:[20,165] width:[120,20]
        spinner spnSpacing "" pos:[150,163] width:[80,20] range:[0,5,0.5] type:#float
        
        checkbox chkAutoFix "启用自动修复" pos:[20,195] width:[120,20]
        checkbox chkLLM "启用LLM分析 (需配置)" pos:[180,195] width:[180,20]
        
        -- 操作按钮组
        groupBox grpActions "操作" pos:[10,230] width:[420,100]
        button btnScan "扫描UV问题" pos:[30,255] width:[120,35] height:[30]
        button btnFix "自动修复" pos:[165,255] width:[120,35] height:[30]
        button btnSelect "选择问题UV" pos:[300,255] width:[120,35] height:[30]
        button btnPack "打包UV壳" pos:[165,295] width:[120,30]
        button btnNormalize "归一化UV" pos:[300,295] width:[120,30]
        
        -- 结果显示组
        groupBox grpResult "检测结果" pos:[10,340] width:[420,190]
        listbox lbResults "" pos:[20,360] width:[400,165] height:[12]
        
        -- 刷新选择显示
        on btnRefresh pressed do (
            local sel = selection as array
            if sel.count > 0 then
                edtSelected.text = sel[1].name
            else
                edtSelected.text = "未选择物体"
        )
        
        -- 扫描
        on btnScan pressed do (
            local sel = selection as array
            if sel.count == 0 then (
                messageBox "请先选择一个物体"
                return()
            )
            
            -- 更新Agent配置
            uvComplianceAgent.targetTexelDensity = spnDensity.value
            uvComplianceAgent.densityTolerance = spnTolerance.value / 100.0
            uvComplianceAgent.spacingPercent = spnSpacing.value
            uvComplianceAgent.autoFixEnabled = chkAutoFix.checked
            uvComplianceAgent.llmEnabled = chkLLM.checked
            
            -- 执行扫描
            local report = uvComplianceAgent.scanObject sel[1].name
            
            -- 更新列表
            lbResults.items = #()
            local items = #()
            append items ("问题总数: " + (report[2] as string))
            append items ("合规状态: " + (if report[4] then "通过" else "未通过"))
            append items ("----------------------------------------")
            
            for issue in report[3] do (
                append items ("[" + issue[2] + "] " + issue[3])
            )
            
            lbResults.items = items
        )
        
        -- 自动修复
        on btnFix pressed do (
            local sel = selection as array
            if sel.count == 0 then (
                messageBox "请先选择一个物体"
                return()
            )
            
            -- 获取最近的报告
            if uvComplianceAgent.reportCache.count > 0 then (
                local report = uvComplianceAgent.reportCache[1]
                local result = uvComplianceAgent.autoFix report
                messageBox ("修复完成: " + (result[2] as string))
            ) else (
                messageBox "请先运行扫描"
            )
        )
        
        -- 选择问题UV
        on btnSelect pressed do (
            local sel = selection as array
            if sel.count == 0 then (
                messageBox "请先选择一个物体"
                return()
            )
            
            if uvComplianceAgent.reportCache.count > 0 then (
                local report = uvComplianceAgent.reportCache[1]
                uvComplianceAgent.selectInvalidUVs report
            ) else (
                messageBox "请先运行扫描"
            )
        )
        
        -- 打包UV
        on btnPack pressed do (
            local sel = selection as array
            if sel.count == 0 then (
                messageBox "请先选择一个物体"
                return()
            )
            
            -- 获取Unwrap修改器
            local unwrapMod = undefined
            for m in sel[1].modifiers where classOf m == Unwrap_UVW do (
                unwrapMod = m
                exit
            )
            
            if unwrapMod != undefined then (
                local numFaces = polyOp.getNumFaces sel[1]
                unwrapMod.packMapFaces #{1..numFaces} (1) 0.005
                messageBox "UV壳已重新打包"
            ) else (
                messageBox "请先添加Unwrap UVW修改器"
            )
        )
        
        -- 归一化UV
        on btnNormalize pressed do (
            local sel = selection as array
            if sel.count == 0 then (
                messageBox "请先选择一个物体"
                return()
            )
            
            local unwrapMod = undefined
            for m in sel[1].modifiers where classOf m == Unwrap_UVW do (
                unwrapMod = m
                exit
            )
            
            if unwrapMod != undefined then (
                local numFaces = polyOp.getNumFaces sel[1]
                unwrapMod.normalizeMap #{1..numFaces}
                messageBox "UV已归一化到[0,1]空间"
            ) else (
                messageBox "请先添加Unwrap UVW修改器"
            )
        )
    )
    
    addRollout mainRollout ui
    return ui
)

-- 启动UI
if uvAgentUI != undefined then (
    closerolloutfloater uvAgentUI
)
uvAgentUI = createUIAgent()

format "\n========================================\n"
format "UV合规性Agent for 3ds Max 已启动\n"
format "========================================\n"
format "使用说明:\n"
format "1. 选择要检测的物体\n"
format "2. 调整检测参数\n"
format "3. 点击'扫描UV问题'\n"
format "4. 查看检测结果\n"
format "5. 点击'自动修复'或'选择问题UV'手动修复\n"
format "========================================\n"