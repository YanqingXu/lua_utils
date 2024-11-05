--[[
设置targetNode相对于node的位置
--]]

function setWorldPosition(targetNode, node, offset)
    if not node then
        return
    end

    local nodeParent = node:getParent()
    if not nodeParent then
        return
    end

    local nodePosition = cc.p(node:getPosition())
    local worldPosition = nodeParent:convertToWorldSpace(nodePosition)

    local parent = targetNode:getParent()
    if not parent then
        return
    end

    local pos = parent:convertToNodeSpace(worldPosition)
    if offset then
        pos.x = pos.x + offset.x
        pos.y = pos.y + offset.y
    end

    targetNode:setPosition(pos.x, pos.y)
end

function getWorldPosition(targetNode, node)
    local nodeParent = node:getParent()
    if not nodeParent then
        return
    end

    local nodePosition = cc.p(node:getPosition())
    local worldPosition = nodeParent:convertToWorldSpace(nodePosition)

    local parent = targetNode:getParent()
    if not parent then
        return
    end

    local pos = parent:convertToNodeSpace(worldPosition)
    return pos
end

ALIGN_TYPE = {
    leftTop = 1,
    leftCenter = 2,
    leftBottom = 3,
    centerTop = 4,
    center = 5,
    centerBottom = 6,
    rightTop = 7,
    rightCenter = 8,
    rightBottom = 9,
}

SCREEN_SIZE = cc.Director:getInstance():getWinSize()

-- 获取offset之后的位置
local function getOffsetPos(pos, offset)
    if not offset then
        return pos
    end

    local x = pos.x
    local y = pos.y

    if offset.x then
        x = x + offset.x
    end

    if offset.y then
        y = y + offset.y
    end

    return cc.p(x, y)
end

local function getLeftTopPos(contentSize, anchorPoint, offset)
    local leftX      = contentSize.width * anchorPoint.x
    local topY       = SCREEN_SIZE.height - contentSize.height * (1 - anchorPoint.y)

    local leftTopPos = cc.p(leftX, topY)
    return getOffsetPos(leftTopPos, offset)
end

local function getLeftCenterPos(contentSize, anchorPoint, offset)
    local leftX         = contentSize.width * anchorPoint.x
    local centerY       = SCREEN_SIZE.height / 2 - (0.5 - anchorPoint.y) * contentSize.height

    local leftCenterPos = cc.p(leftX, centerY)
    return getOffsetPos(leftCenterPos, offset)
end

local function getLeftBottomPos(contentSize, anchorPoint, offset)
    local leftX         = contentSize.width * anchorPoint.x
    local bottomY       = contentSize.height * anchorPoint.y

    local leftBottomPos = cc.p(leftX, bottomY)
    return getOffsetPos(leftBottomPos, offset)
end

local function getCenterTopPos(contentSize, anchorPoint, offset)
    local centerX      = SCREEN_SIZE.width / 2 - (0.5 - anchorPoint.x) * contentSize.width
    local topY         = SCREEN_SIZE.height - contentSize.height * (1 - anchorPoint.y)

    local centerTopPos = cc.p(centerX, topY)
    return getOffsetPos(centerTopPos, offset)
end

local function getCenterPos(contentSize, anchorPoint, offset)
    local centerX = SCREEN_SIZE.width / 2 - (0.5 - anchorPoint.x) * contentSize.width
    local centerY = SCREEN_SIZE.height / 2 - (0.5 - anchorPoint.y) * contentSize.height

    local centerPos = cc.p(centerX, centerY)
    return getOffsetPos(centerPos, offset)
end

local function getCenterBottomPos(contentSize, anchorPoint, offset)
    local centerX         = SCREEN_SIZE.width / 2 - (0.5 - anchorPoint.x) * contentSize.width
    local bottomY         = contentSize.height * anchorPoint.y

    local centerBottomPos = cc.p(centerX, bottomY)
    return getOffsetPos(centerBottomPos, offset)
end

local function getRightTopPos(contentSize, anchorPoint, offset)
    local rightX      = SCREEN_SIZE.width - contentSize.width * (1 - anchorPoint.x)
    local topY        = SCREEN_SIZE.height - contentSize.height * (1 - anchorPoint.y)

    local rightTopPos = cc.p(rightX, topY)
    return getOffsetPos(rightTopPos, offset)
end

local function getRightCenterPos(contentSize, anchorPoint, offset)
    local rightX         = SCREEN_SIZE.width - contentSize.width * (1 - anchorPoint.x)
    local centerY        = SCREEN_SIZE.height / 2 - (0.5 - anchorPoint.y) * contentSize.height

    local rightCenterPos = cc.p(rightX, centerY)
    return getOffsetPos(rightCenterPos, offset)
end

local function getRightBottomPos(contentSize, anchorPoint, offset)
    local rightX         = SCREEN_SIZE.width - contentSize.width * (1 - anchorPoint.x)
    local bottomY        = contentSize.height * anchorPoint.y

    local rightBottomPos = cc.p(rightX, bottomY)
    return getOffsetPos(rightBottomPos, offset)
end

local mapAdaption = {
    [ALIGN_TYPE.leftTop] = getLeftTopPos,
    [ALIGN_TYPE.leftCenter] = getLeftCenterPos,
    [ALIGN_TYPE.leftBottom] = getLeftBottomPos,
    [ALIGN_TYPE.centerTop] = getCenterTopPos,
    [ALIGN_TYPE.center] = getCenterPos,
    [ALIGN_TYPE.centerBottom] = getCenterBottomPos,
    [ALIGN_TYPE.rightTop] = getRightTopPos,
    [ALIGN_TYPE.rightCenter] = getRightCenterPos,
    [ALIGN_TYPE.rightBottom] = getRightBottomPos,
}

function getScreenAdaptionPos(targetNode, alignType, offset)
    if not targetNode then
        return
    end

    if type(alignType) ~= "number" then
        return
    end

    if alignType < ALIGN_TYPE.leftTop or alignType > ALIGN_TYPE.rightBottom then
        return
    end

    local contentSize = targetNode:getContentSize()
    local anchorPoint = targetNode:getAnchorPoint()

    local func = mapAdaption[alignType]
    if func then
        return func(contentSize, anchorPoint, offset)
    end
end

function screenAdaption(targetNode, alignType, offset)
    local pos = getScreenAdaptionPos(targetNode, alignType, offset)
    if not pos then
        return
    end

    targetNode:setPosition(pos.x, pos.y)
end
