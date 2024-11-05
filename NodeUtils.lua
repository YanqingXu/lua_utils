--[[
ui节点工具类
--]]
NodeUtils = {}

NodeUtils.mapNodeLike = {
    -- ui节点
    ["ccui.Button"] = ccui.Button,
    ["ccui.CheckBox"] = ccui.CheckBox,
    ["ccui.ImageView"] = ccui.ImageView,
    ["ccui.Text"] = ccui.Text,

    -- 文本
    ["ccui.TextField"] = ccui.TextField,
    ["ccui.TextBMFont"] = ccui.TextBMFont,
    ["ccui.TextAtlas"] = ccui.TextAtlas,
    ["ccui.LoadingBar"] = ccui.LoadingBar,
    ["ccui.Slider"] = ccui.Slider,
    ["ccui.Scale9Sprite"] = ccui.Scale9Sprite,
    ["ccui.EditBox"] = ccui.EditBox,
    ["ccui.Widget"] = ccui.Widget,

    -- 基础节点
    ["cc.Node"] = cc.Node,
    ["cc.Layer"] = cc.Layer,
    ["cc.LayerColor"] = cc.LayerColor,
    ["cc.ProtectedNode"] = cc.ProtectedNode,

    -- 容器
    ["ccui.Layout"] = ccui.Layout,
    ["ccui.ListView"] = ccui.ListView,
    ["ccui.PageView"] = ccui.PageView,
    ["ccui.ScrollView"] = ccui.ScrollView,

    -- 富文本
    ["ccui.RichText"] = ccui.RichText,
    ["ccui.RichElementText"] = ccui.RichElementText,
    ["ccui.RichElementImage"] = ccui.RichElementImage,
    ["ccui.RichElementCustomNode"] = ccui.RichElementCustomNode,
    ["ccui.RichElementNewLine"] = ccui.RichElementNewLine,
    ["ccui.RichElement"] = ccui.RichElement,
}

NodeUtils.mapNodeMeta = {}
for k, v in pairs(NodeUtils.mapNodeLike) do
    local meta = getmetatable(v)
    NodeUtils.mapNodeMeta[meta] = k
end

-- 用于缩进
local function pad(depth)
    return string.rep("  ", depth)
end

-- 打印一个ui控件的所有lua方法，包括继承关系
function NodeUtils.printMethods(widgetName)
    -- 每组按顺序打印
    local groupIndex = 1
    local index = 1

    -- 打印对象的方法
    local function printFromTable(t, level)
        local nodeInfo = NodeUtils.mapNodeMeta[t] or ("" .. groupIndex)
        print("********************  " .. nodeInfo .. "  **********************")
        for k, v in pairs(t) do
            if type(v) == "function" then
                -- 排除元方法
                if string.sub(k, 1, 2) ~= "__" then
                    print(pad(level) .. index .. "、" .. k)
                    index = index + 1
                end
            end
        end

        groupIndex = groupIndex + 1
        return nodeInfo
    end

    -- 递归打印元表的方法
    local function recurseMetatable(obj, level)
        local meta = getmetatable(obj)
        if not meta then return end -- 如果没有元表，则返回

        --打印
        local nodeInfo = printFromTable(meta, level)
        if nodeInfo == "cc.Node" then
            return
        end

        -- 递归检查元表的元表
        recurseMetatable(meta, level + 1)
    end

    -- 开始递归遍历元表
    local widget = NodeUtils.mapNodeLike[widgetName]
    recurseMetatable(widget, 1)
end

-- 打印节点树具体实现
local function printNodeTreeImp(node, maxDepth, depth, funcNodeInfo)
    if not depth then
        depth = 0
    end

    if maxDepth and depth > maxDepth then
        return
    end

    if not funcNodeInfo then
        funcNodeInfo = function(nd) return "" end
    end

    local str = ""
    for i = 1, depth do
        str = pad(i)
    end

    print(str .. node:getName(), funcNodeInfo(node))
    for _, v in ipairs(node:getChildren()) do
        printNodeTreeImp(v, depth + 1, maxDepth, funcNodeInfo)
    end
end

-- 打印节点树: maxDepth不传则打印全部
function NodeUtils.printNodeTree(node, maxDepth, funcNodeInfo)
    print("-------------- 打印节点树 ----------------")
    printNodeTreeImp(node, maxDepth, nil, funcNodeInfo)
    print("-----------------------------------------")
end


-- 节点事件
NodeUtils.EVENT = {
    SIZE_CHANGED = "size-changed",
    SCALE_CHANGED = "scale-changed",
    OPACITY_CHANGED = "opacity-changed",
    ROTATION_CHANGED = "rotation-changed",
    POSITION_CHANGED = "position-changed",
    VISIBLE_CHANGED = "visible-changed",
    CHILDREN_CHANGED = "children-changed",
}

-- 事件分发
local function dispatchEvent(obj)
    OperatorUtils.event_bus().emit(obj)
end

-- 自身属性
local listSelfKey = {
    "node",
    "eventName",
    "propertyData",
}

local mapFunc = {
    [NodeUtils.EVENT.SIZE_CHANGED] = "getContentSize",
    [NodeUtils.EVENT.SCALE_CHANGED] = "getScale",
    [NodeUtils.EVENT.OPACITY_CHANGED] = "getOpacity",
    [NodeUtils.EVENT.ROTATION_CHANGED] = "getRotation",
    [NodeUtils.EVENT.VISIBLE_CHANGED] = "isVisible",
    [NodeUtils.EVENT.CHILDREN_CHANGED] = "getChildrenCount",
    [NodeUtils.EVENT.POSITION_CHANGED] = function (node)
        return cc.p(node:getPositionX(), node:getPositionY())
    end,
}

local function getNodePropertyData(obj, eventName)
    if not obj.node or tolua.isnull(obj.node) then
        return
    end

    local func = mapFunc[eventName]
    if not func then
        return
    end

    if type(func) == "function" then
        return func(obj.node)
    end

    return obj.node[func](obj.node)
end

local function onNodeEventTrigger(obj, eventName)
    if eventName == NodeUtils.EVENT.POSITION_CHANGED then
        local x, y = obj.node:getPosition()
        if obj.propertyData.x ~= x or obj.propertyData.y ~= y then
            obj.propertyData = cc.p(x, y)
            dispatchEvent(obj)
        end

        return
    end

    if eventName == NodeUtils.EVENT.SIZE_CHANGED then
        local size = obj.node:getContentSize()
        if obj.propertyData.width ~= size.width or 
            obj.propertyData.height ~= size.height then
            obj.propertyData = size
            dispatchEvent(obj)
        end

        return
    end

    local newPropertyData = getNodePropertyData(obj, eventName)
    if obj.propertyData ~= newPropertyData then
        obj.propertyData = newPropertyData
        dispatchEvent(obj)
    end
end

-- 节点方法拦截
local function funcInterceptor(obj, funcName, ...)
    if tolua.isnull(obj.node) then
        print("error----------> NodeUtils.lua line 453 attempt call "..funcName.." on a null node...")
        return
    end

    -- 调用node原始方法
    local results = { obj.node[funcName](obj.node, ...) }
    local firstResult = results[1]

    if tolua.isnull(obj.node) then
        return
    end

    -- 检测触发自定义事件
    onNodeEventTrigger(obj, obj.eventName)
    
    -- 返回node原始方法的返回值
    if firstResult then
        return OperatorUtils.unpack(results)
    end
end

-- 重写index元方法
local function metaIndex(obj, key)
    if table.indexof(listSelfKey, key) then
        return rawget(obj, key)
    end

    local value = obj.node[key]
    if value then
        if type(value) ~= "function" then
            return value
        end

        return function(t, ...)
            return funcInterceptor(t, key, ...)
        end
    end
end

-- 重写newindex元方法
local function metaNewIndex(obj, key, value)
    if table.indexof(listSelfKey, key) then
        rawset(obj, key, value)
        return
    end

    if type(value) == "function" then
        rawset(obj, key, value)
        return
    end

    obj.node[key] = value
end

-- node装饰器
function NodeUtils.newNode(node, eventName, callback)
    if not node or tolua.isnull(node) then
        print("error---------->  NodeUtils.newNode: node is null...")
        return
    end

    local nodeType = tolua.type(node)
    local nodeLike = NodeUtils.mapNodeLike[nodeType]
    if not nodeLike then
        print("error---------->  NodeUtils.newNode: nodeLike is not a node...")
        return node
    end

    local obj = {}
    local nodeMt = getmetatable(nodeLike)
    local metaTable = DeepCopy(nodeMt)
    setmetatable(obj, metaTable)

    -- 属性拦截
    getmetatable(obj).__index = metaIndex
    getmetatable(obj).__newindex = metaNewIndex

    obj.node = node
    obj.eventName = eventName

    -- 记录node原始的属性值
    obj.propertyData = getNodePropertyData(obj, eventName)

    OperatorUtils.event_bus().on(obj, function()
        print("event---------->  ".. obj.eventName .." triggered...")
        if callback then
            callback()
        end
    end)

    return obj
end

-- 还原操作
function NodeUtils.restoreNode(obj)
    if obj and obj.node then
        OperatorUtils.event_bus().off(obj)
        return obj.node      
    end
end