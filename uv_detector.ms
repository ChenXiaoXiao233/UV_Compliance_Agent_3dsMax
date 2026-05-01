-- UV Detector Module
-- UV问题检测模块

struct UVDetector (
    
    fn detectLoneVertices obj unwrapMod = (
        local issues = #()
        local numVerts = polyOp.getNumVerts obj
        local uvUsed = #{}
        
        local numFaces = polyOp.getNumFaces obj
        for f = 1 to numFaces do (
            local uvVerts = unwrapMod.getMapFace 1 f
            for uv in uvVerts do (
                uvUsed[uv+1] = true
            )
        )
        
        local loneVerts = #{}
        for v = 1 to numVerts do (
            if not uvUsed[v] then loneVerts[v] = true
        )
        
        if loneVerts.numberSet > 0 then (
            local issue = #(
                "UV-DET-001",
                "INFO",
                obj.name,
                0,
                "检测到 " + (loneVerts.numberSet as string) + " 个孤立UV顶点",
                #("type", "lone_vertices", "vert_count", loneVerts.numberSet),
                "建议: 在UV编辑器中删除未使用的顶点或使用'Clean'工具",
                false
            )
            append issues issue
        )
        return issues
    ),
    
    fn detectShellSpacing obj unwrapMod = (
        local issues = #()
        -- 完整实现需要计算壳间距离
        return issues
    ),
    
    fn detectMultipleChannels obj = (
        local issues = #()
        local numChannels = meshOp.getNumMaps obj
        
        if numChannels > 2 then (
            local issue = #(
                "UV-DET-002",
                "WARNING",
                obj.name,
                0,
                "检测到 " + (numChannels as string) + " 个UV通道",
                #("type", "multiple_channels", "channel_count", numChannels),
                "建议: 删除不需要的UV通道以减少文件大小",
                true
            )
            append issues issue
        )
        return issues
    ),
    
    fn fullDetect obj = (
        local unwrapMod = undefined
        for m in obj.modifiers where classOf m == Unwrap_UVW do (
            unwrapMod = m
            exit
        )
        
        if unwrapMod == undefined then return #()
        
        local allIssues = #()
        local loneIssues = detectLoneVertices obj unwrapMod
        for i in loneIssues do append allIssues i
        
        local spacingIssues = detectShellSpacing obj unwrapMod
        for i in spacingIssues do append allIssues i
        
        local channelIssues = detectMultipleChannels obj
        for i in channelIssues do append allIssues i
        
        return allIssues
    )
)

global uvDetector = UVDetector()
