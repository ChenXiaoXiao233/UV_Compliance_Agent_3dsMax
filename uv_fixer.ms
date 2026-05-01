-- UV Fixer Module
-- UV自动修复模块

struct UVFixer (
    
    -- 修复翻转的UV
    fn fixFlippedUVs obj unwrapMod faceIDs = (
        try (
            unwrapMod.selectFaces faceIDs
            unwrapMod.flipSelectedFaces()
            unwrapMod.selectFaces #{}
            return #(true, (faceIDs.numberSet as string) + " 个面已修复")
        ) catch (
            return #(false, (getCurrentException() as string))
        )
    ),
    
    -- 修复UV超出范围
    fn fixOutOfRange obj unwrapMod = (
        try (
            local numFaces = polyOp.getNumFaces obj
            unwrapMod.normalizeMap #{1..numFaces}
            return #(true, "UV已归一化到[0,1]空间")
        ) catch (
            return #(false, (getCurrentException() as string))
        )
    ),
    
    -- 修复UV拉伸（简化版）
    fn fixStretchedUVs obj unwrapMod faceIDs = (
        try (
            unwrapMod.selectFaces faceIDs
            -- 使用Relax功能
            unwrapMod.relaxSelectedFaces 0.5
            unwrapMod.selectFaces #{}
            return #(true, (faceIDs.numberSet as string) + " 个面已放松")
        ) catch (
            return #(false, (getCurrentException() as string))
        )
    ),
    
    -- 打包UV壳
    fn packUVShells obj unwrapMod = (
        try (
            local numFaces = polyOp.getNumFaces obj
            unwrapMod.packMapFaces #{1..numFaces} (1) 0.005
            return #(true, "UV壳已重新打包")
        ) catch (
            return #(false, (getCurrentException() as string))
        )
    ),
    
    -- 执行修复
    fn fixIssue obj issue = (
        local objNode = getNodeByName obj.name
        if objNode == undefined then return #(false, "物体不存在")
        
        -- 获取Unwrap修改器
        local unwrapMod = undefined
        for m in objNode.modifiers where classOf m == Unwrap_UVW do (
            unwrapMod = m
            exit
        )
        
        if unwrapMod == undefined then return #(false, "没有Unwrap UVW修改器")
        
        -- 解析issue类型
        local issueType = undefined
        for i = 1 to issue[6].count by 2 where issue[6][i] == "type" do (
            issueType = issue[6][i+1]
            exit
        )
        
        case issueType of (
            "flipped_uv": (
                local faceIDs = undefined
                for i = 1 to issue[6].count by 2 where issue[6][i] == "face_ids" do (
                    faceIDs = issue[6][i+1] as bitarray
                    exit
                )
                if faceIDs != undefined then
                    return fixFlippedUVs objNode unwrapMod faceIDs
            )
            "out_of_range": (
                return fixOutOfRange objNode unwrapMod
            )
            "stretched": (
                local faceIDs = undefined
                for i = 1 to issue[6].count by 2 where issue[6][i] == "face_ids" do (
                    faceIDs = issue[6][i+1] as bitarray
                    exit
                )
                if faceIDs != undefined then
                    return fixStretchedUVs objNode unwrapMod faceIDs
            )
            default: return #(false, "未知问题类型")
        )
        
        return #(false, "无法识别的问题类型")
    ),
    
    -- 批量修复
    fn fixAllIssues obj issues = (
        local successCount = 0
        local failCount = 0
        local results = #()
        
        for issue in issues do (
            local result = fixIssue obj issue
            if result[1] then
                successCount += 1
            else
                failCount += 1
            append results result
        )
        
        return #(successCount, failCount, results)
    )
)

global uvFixer = UVFixer()