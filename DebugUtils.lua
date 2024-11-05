--[[
调试代码工具
--]]
DebugUtils = {}

-- 仅在Windows平台下使用
if CC_TARGET_PLATFORM ~= cc.PLATFORM_OS_WINDOWS then
    return
end

-- 本地项目根目录
DebugUtils.PROJECT_ROOT = cc.FileUtils:getInstance():getWritablePath():match("(.+runtime)")
if not DebugUtils.PROJECT_ROOT then
    return
end

DebugUtils.PROJECT_ROOT = string.gsub(DebugUtils.PROJECT_ROOT, "runtime", "src\\")

-- 用于缩进
local function pad(depth)
    return string.rep("  ", depth)
end

-- 用于转义字符串中的换行符
local function escape_newlines(str)
    return str:gsub("\n", "\\n")
end

local function trim(str)
    return str:gsub("^%s*(.-)%s*$", "%1")
end

local function dumpPrintTarget(target, depth, k)
    if type(target) == 'table' then
        return
    end

    if type(target) == 'string' then
        local newStr = escape_newlines(target)
        print(pad(depth + 1) .. '[' .. k .. '] = "' .. newStr .. '",')
    else
        print(pad(depth + 1) .. '[' .. k .. '] = ' .. tostring(target) .. ',')
    end
end

local function dumpImpl(target, depth, mapExisted)
    depth = depth or 0
    if depth > 10 then
        return
    end

    if type(target) ~= 'table' then
        print(tostring(target))
        return
    end

    print(pad(depth) .. '{')

    for k, v in pairs(target) do
        repeat
            if k == "__index" then
                break
            end

            if type(k) == "userdata" then
                k = tostring(k)
            end

            local key = k

            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end

            if mapExisted[key] and mapExisted[key] == v then
                dumpPrintTarget(v, depth, k)
                break
            end

            mapExisted[key] = v

            if type(v) == "table" then
                print(pad(depth + 1) .. '[' .. k .. '] = ')
                dumpImpl(v, depth + 1, mapExisted)
                break
            end

            dumpPrintTarget(v, depth, k)
        until true
    end

    print(pad(depth) .. '},')
end

function DebugUtils.dump(target, source)
    local traceback = string.split(debug.traceback("", 2), "\n")
    if not traceback then return end

    print("-----------------------------------------------------------------------------------------")
    print("dump from: " .. string.trim(traceback[2]))

    if source then
        print(source)
    end

    local mapExisted = {}
    dumpImpl(target, nil, mapExisted)
    print("-----------------------------------------------------------------------------------------")
end

local function trimQuotationMark(str)
    if string.find(str, "\"") then
        str = string.gsub(str, "\"", "")
    end

    if string.find(str, "\'") then
        str = string.gsub(str, "\'", "")
    end

    return str
end

local function extractFuncName(lineContent)
    -- 匹配普通的函数定义，如 "function funcName"
    local funcName = lineContent:match("function%s+([%w_.]+)%(")

    -- 匹配局部函数定义，如 "local funcName ="
    if not funcName then
        funcName = lineContent:match("local%s+([%w_]+)%s*=")
    end

    -- 匹配赋值给变量的匿名函数，如 "funcName = function" 或 "funcName = function()"
    if not funcName then
        funcName = lineContent:match("([%w_]+)%s*=%s*function")
    end

    -- 匹配表方法定义，如 "function TableName.funcName"
    if not funcName then
        funcName = lineContent:match("function%s+[%w_]+%.([%w_]+)")
    end

    -- 匹配冒号语法的方法定义，如 "function TableName:funcName"
    if not funcName then
        funcName = lineContent:match("function%s+[%w_]+:([%w_]+)")
    end

    if not funcName then
        funcName = "anonymous function"
    end

    return funcName
end

local function getFuncNameFromLine(filePath, lineNumber)
    filePath = DebugUtils.PROJECT_ROOT .. filePath
    local file = io.open(filePath, "r")
    if not file then return nil end

    local lineContent
    for i = 1, lineNumber do
        lineContent = file:read("*line")
    end

    file:close()
    return extractFuncName(lineContent)
end

function DebugUtils.trace(maxDepth)
    local traceback = string.split(debug.traceback("", 2), "\n")
    if not traceback then return end

    print("-----------------------------------------------------------------------------------------")
    print("| trace begin")

    local depth = 3
    maxDepth = depth + (maxDepth or 5)

    repeat
        if depth > maxDepth then
            print("| trace end: depth > maxDepth")
            break
        end

        if not traceback[depth] then
            print("| trace end")
            break
        end

        local isValid = true
        local funcInfo = traceback[depth]
        funcInfo = trim(funcInfo)

        local path, name = "", ""
        repeat
            if not string.find(funcInfo, "in function") then
                isValid = false
                break
            end

            local funcLineInfo = string.split(funcInfo, "in function")
            if not funcLineInfo or #funcLineInfo < 2 then
                break
            end

            path = funcLineInfo[1]
            name = funcLineInfo[2]

            if not string.find(name, "(xf.*%w+%.lua)\"%]:(%d+)") then
                break
            end

            local filePath, lineNum = name:match("(xf.*%w+%.lua)\"%]:(%d+)")
            if filePath and lineNum then
                local funcName = getFuncNameFromLine(filePath, tonumber(lineNum))
                if funcName then
                    name = funcName
                end
            end
        until true

        name = trimQuotationMark(name)
        name = trim(name)

        if isValid then
            print("|" .. pad(2) .. path .. " in function \"" .. name .. "\"")
        end
        depth = depth + 1
    until false

    print("-----------------------------------------------------------------------------------------")
end

-- 为node添加一个颜色层: 便于发现某些透明节点的位置，方便调试，尤其是点击事件区域没有效果时
function DebugUtils.addColorForNode(node, color, opacity)
    color = color or cc.c3b(255, 0, 0)
    opacity = opacity or 100

    local contentSize = node:getContentSize()
    local colorLayer = cc.LayerColor:create(color, contentSize.width, contentSize.height)
    colorLayer:setOpacity(opacity)
    node:addChild(colorLayer)
    colorLayer:setPosition(0, 0)
    colorLayer:setAnchorPoint(node:getAnchorPoint())
end

-- 递归depth层遍历所有可视节点，为它们添加一个颜色层
function DebugUtils.addColorForPanel(rootNode, depth, color, opacity)
    depth = depth or 1

    local function recurseNode(node, currentDepth)
        if currentDepth > depth then
            return
        end

        local nodeName = node:getName()
        if "" == nodeName then
            return
        end

        local children = node:getChildren()
        for _, child in ipairs(children) do
            if child:isVisible() then
                DebugUtils.addColorForNode(child, color, opacity)
                recurseNode(child, currentDepth + 1)
            end
        end
    end

    recurseNode(rootNode, 1)
end