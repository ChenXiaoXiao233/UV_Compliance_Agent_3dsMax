-- UV Layout Compliance Agent - Core Module
-- 基于3ds Max API的UV布局合规性检测与修复Agent

struct UVComplianceAgent (
    -- 配置参数
    targetTexelDensity = 10.24,
    spacingPercent = 0.5,
    densityTolerance = 0.15,
    autoFixEnabled = true,
    llmEnabled = false,
    
    -- 内部变量
    issueCounter = 0,
    reportCache = #(),
    
    -- 生成问题ID
    fn nextIssueID = (
        issueCounter += 1
        return "UV-" + (issueCounter as string)
    ),
    
    -- 获取3D面积
    fn getFaceArea3D obj faceIndex = (
        local face = getFace obj faceIndex
        local verts = #()
        for i = 1 to 3 do (
            local v = getVert obj face[i]
            append verts v
        )
        local ab = verts[2] - verts[1]
        local ac = verts[3] - verts[1]
        return length (cross ab ac) / 2.0
    ),
    
    -- 获取UV面积（有向）
    fn getUVArea unwrapMod faceIndex = (
        local uv = unwrapMod.getMapFace 1 faceIndex
        local uvs = #()
        for i = 1 to 3 do (
            local uvCoord = unwrapMod.getMapVert 1 (uv[i] + 1)
            append uvs [uvCoord.x, uvCoord.y, 0]
        )
        local u = uvs[2] - uvs[1]
        local v = uvs[3] - uvs[1]
        return (u.x*v.y - u.y*v.x) / 2.0
    ),
    
    -- 检测UV翻转
    fn detectFlippedUVs obj unwrapMod = (
        local issues = #()
        local numFaces = polyOp.getNumFaces obj
        local flippedFaces = #()
        
        for f = 1 to numFaces do (
            local area3D = getFaceArea3D obj f
            local areaUV = getUVArea unwrapMod f
            if (area3D > 0 and areaUV < 0) or (area3D < 0 and areaUV > 0) then (
                append flippedFaces f
            )
        )
        
        if flippedFaces.count > 0 then (
            local issue = #(
                nextIssueID(),
                "WARNING",
                obj.name,
                0,
                "检测到 " + (flippedFaces.count as string) + " 个翻转的UV面",
                #("type", "flipped_uv", "face_ids", flippedFaces),
                "建议: 在UV编辑器中选中这些面并使用'Flip'功能翻转",
                true
            )
            append issues issue
        )
        return issues
    ),
    
    -- 检测UV重叠（使用Unwrap_UVW内置方法）
    fn detectOverlaps obj unwrapMod = (
        local issues = #()
        
        -- 使用selectOverlappedFaces方法检测重叠
        unwrapMod.selectOverlappedFaces()
        local overlappedFaces = unwrapMod.getSelectedFaces()
        local overlapCount = overlappedFaces.numberSet
        
        if overlapCount > 0 then (
            local issue = #(
                nextIssueID(),
                "ERROR",
                obj.name,
                0,
                "检测到 " + (overlapCount as string) + " 个UV重叠的面",
                #("type", "overlap", "overlap_count", overlapCount),
                "建议: 使用UV编辑器的'Relax'或'Pack'功能重新布局UV",
                false
            )
            append issues issue
        )
        
        -- 清除选择
        unwrapMod.selectFaces #{} 
        return issues
    ),
    
    -- 检测UV超出范围
    fn detectOutOfRange obj unwrapMod = (
        local issues = #()
        local numFaces = polyOp.getNumFaces obj
        
        -- 获取UV边界
        unwrapMod.getArea #{1..numFaces} &uvX &uvY &uvWidth &uvHeight &uvFaceArea &objArea
        
        if uvWidth > 1.0 or uvHeight > 1.0 then (
            local issue = #(
                nextIssueID(),
                "ERROR",
                obj.name,
                0,
                "UV超出[0,1]范围: 宽度=" + (uvWidth as string) + ", 高度=" + (uvHeight as string),
                #("type", "out_of_range", "uv_width", uvWidth, "uv_height", uvHeight),
                "建议: 使用UV编辑器的'Pack'或'Normalize'功能将UV归一到0-1空间",
                true
            )
            append issues issue
        )
        return issues
    ),
    
    -- 检测UV拉伸/变形
    fn detectStretchedUVs obj unwrapMod = (
        local issues = #()
        local numFaces = polyOp.getNumFaces obj
        local ratios = #()
        
        for f = 1 to numFaces do (
            local area3D = getFaceArea3D obj f
            local areaUV = abs (getUVArea unwrapMod f)  -- 取绝对值
            if area3D > 0 and areaUV > 0 then (
                local ratio = areaUV / area3D
                append ratios ratio
            ) else (
                append ratios 0
            )
        )
        
        -- 计算平均ratio
        local validRatios = for r in ratios where r > 0 collect r
        if validRatios.count > 0 then (
            local avgRatio = (for r in validRatios sum r) / validRatios.count
            local tolerance = densityTolerance
            local stretchedFaces = #()
            local compressedFaces = #()
            
            for f = 1 to numFaces where ratios[f] > 0 do (
                local deviation = abs (ratios[f] - avgRatio) / avgRatio
                if deviation > tolerance then (
                    if ratios[f] > avgRatio then
                        append stretchedFaces f
                    else
                        append compressedFaces f
                )
            )
            
            if stretchedFaces.count > 0 then (
                local issue = #(
                    nextIssueID(),
                    "WARNING",
                    obj.name,
                    0,
                    "检测到 " + (stretchedFaces.count as string) + " 个拉伸的UV面",
                    #("type", "stretched", "face_ids", stretchedFaces),
                    "建议: 使用Unwrap UVW的'Relax'工具放松UV，或调整UV壳比例",
                    true
                )
                append issues issue
            )
            
            if compressedFaces.count > 0 then (
                local issue = #(
                    nextIssueID(),
                    "INFO",
                    obj.name,
                    0,
                    "检测到 " + (compressedFaces.count as string) + " 个压缩的UV面",
                    #("type", "compressed", "face_ids", compressedFaces),
                    "建议: 适当放大这部分UV壳以匹配纹理细节",
                    true
                )
                append issues issue
            )
        )
        return issues
    ),
    
    -- 获取UV岛信息
    fn getUVShells unwrapMod = (
        -- 获取所有面，使用连通性检测UV岛
        local numFaces = unwrapMod.getNumFaces()
        local visited = #{}
        local shells = #()
        
        -- 简化实现：假设每个连续区域是一个壳
        local faceIndices = for i = 1 to numFaces collect i
        local currentShell = #{}
        
        -- 注：完整实现需要建立UV邻接图
        -- 这里返回一个包含所有面的单个壳
        append shells #{1..numFaces}
        return shells
    ),
    
    -- 主扫描函数
    fn scanObject objName = (
        local obj = getNodeByName objName
        if obj == undefined then (
            format "错误: 物体 '%' 不存在\n" objName
            return undefined
        )
        
        -- 检查是否有Unwrap UVW修改器，没有则添加
        local unwrapMod = undefined
        for m in obj.modifiers where classOf m == Unwrap_UVW do (
            unwrapMod = m
            exit
        )
        
        if unwrapMod == undefined then (
            unwrapMod = Unwrap_UVW()
            addModifier obj unwrapMod
        )
        
        -- 执行各项检测
        local report = #()
        local allIssues = #()
        
        -- 1. 检测翻转
        local flippedIssues = detectFlippedUVs obj unwrapMod
        for issue in flippedIssues do append allIssues issue
        
        -- 2. 检测重叠
        local overlapIssues = detectOverlaps obj unwrapMod
        for issue in overlapIssues do append allIssues issue
        
        -- 3. 检测超出范围
        local rangeIssues = detectOutOfRange obj unwrapMod
        for issue in rangeIssues do append allIssues issue
        
        -- 4. 检测拉伸
        local stretchIssues = detectStretchedUVs obj unwrapMod
        for issue in stretchIssues do append allIssues issue
        
        -- 构建报告
        local reportStruct = #(
            objName,
            allIssues.count,
            allIssues,
            allIssues.count == 0
        )
        
        reportCache = #(reportStruct)
        
        -- 输出结果
        format "\n========================================\n"
        format "UV合规性报告 - %\n" objName
        format "========================================\n"
        format "问题总数: %\n" allIssues.count
        format "合规状态: %\n" (if allIssues.count == 0 then "通过" else "未通过")
        format "----------------------------------------\n"
        
        for issue in allIssues do (
            format "[%] %\n" issue[2] issue[3]
            format "    → %\n" issue[7]
        )
        format "========================================\n"
        
        return reportStruct
    ),
    
    -- 自动修复
    fn autoFix report = (
        local objName = report[1]
        local obj = getNodeByName objName
        if obj == undefined then return #(false, "物体不存在")
        
        -- 获取Unwrap修改器
        local unwrapMod = undefined
        for m in obj.modifiers where classOf m == Unwrap_UVW do (
            unwrapMod = m
            exit
        )
        
        if unwrapMod == undefined then return #(false, "没有Unwrap UVW修改器")
        
        local fixedCount = 0
        
        for issue in report[3] do (
            local issueType = (for i = 1 to issue[6].count by 2 where issue[6][i] == "type" collect issue[6][i+1])[1]
            
            case issueType of (
                "flipped_uv": (
                    -- 获取翻转的面并翻转
                    local faceIDs = (for i = 1 to issue[6].count by 2 where issue[6][i] == "face_ids" collect issue[6][i+1])[1]
                    unwrapMod.selectFaces (faceIDs as bitarray)
                    unwrapMod.flipSelectedFaces()
                    fixedCount += 1
                )
                "out_of_range": (
                    -- 归一化UV
                    local numFaces = polyOp.getNumFaces obj
                    unwrapMod.normalizeMap #{1..numFaces}
                    fixedCount += 1
                )
                default: ()
            )
        )
        
        format "修复完成: % 个问题已修复\n" fixedCount
        return #(true, fixedCount)
    ),
    
    -- 选择有问题的UV
    fn selectInvalidUVs report = (
        local objName = report[1]
        local obj = getNodeByName objName
        if obj == undefined then return false
        
        local unwrapMod = undefined
        for m in obj.modifiers where classOf m == Unwrap_UVW do (
            unwrapMod = m
            exit
        )
        
        if unwrapMod == undefined then return false
        
        local allFaces = #{}
        for issue in report[3] do (
            for i = 1 to issue[6].count by 2 where issue[6][i] == "face_ids" do (
                local faceIDs = issue[6][i+1]
                if classOf faceIDs == Array then (
                    for fid in faceIDs do allFaces[fid] = true
                )
            )
        )
        
        unwrapMod.selectFaces allFaces
        subObjectLevel = 3  -- 切换到面级别
        return true
    ),
    
    -- 生成文本报告（供LLM使用）
    fn generateTextReport report = (
        local str = ""
        str += "========================================\n"
        str += "UV布局合规性报告 - " + report[1] + "\n"
        str += "========================================\n"
        str += "问题总数: " + (report[2] as string) + "\n"
        str += "合规状态: " + (if report[4] then "✅ 通过" else "❌ 未通过") + "\n"
        str += "----------------------------------------\n"
        
        for issue in report[3] do (
            str += "[" + issue[2] + "] " + issue[3] + "\n"
            str += "    → 建议: " + issue[7] + "\n"
        )
        str += "========================================\n"
        return str
    ),
    
    -- 批量扫描
    fn scanSelection = (
        local selection = selection as array
        if selection.count == 0 then (
            format "请先选择要扫描的物体\n"
            return #()
        )
        
        local reports = #()
        for obj in selection do (
            if obj != undefined and classOf obj == Editable_Poly or classOf obj == PolyMeshObject then (
                local report = scanObject obj.name
                if report != undefined then append reports report
            )
        )
        
        return reports
    )
)

-- 创建全局实例
global uvComplianceAgent = UVComplianceAgent()
format "UV Compliance Agent 已加载\n"