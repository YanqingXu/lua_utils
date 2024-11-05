local GmManager = class("GmManager")

local MaxGmCount = 10 -- 最多存储10条gm命令
local GM_DATA_KEY = "gmCommand"


function GmManager:ctor()
    self.tbGm = {}

    for i = 1, MaxGmCount do
        local gmText = UserDataDefaultHelper.getStringData("", GM_DATA_KEY .. i)
        if gmText ~= "" then
            table.insert(self.tbGm, gmText)
        end
    end

    self.curGmIndex = 1
end

function GmManager:addKeyBoardListener(scene)
    local function isGMPanelHide()
        local ui_input_panel = api_ui:getPanel(UI_MAIN_GM_INPUT)
        if not ui_input_panel or not ui_input_panel:isVisible() then
            return true
        end

        return false
    end

    local function showOrHideGM()
        if isGMPanelHide() then
            sendNotification(UI_OPEN_PANEL, { command = UI_MAIN_GM_INPUT })
            return
        end

        api_gm:sendGMCommand()

        self.curGmIndex = 1
        sendNotification(UI_CLOSE_PANEL, { command = UI_MAIN_GM_INPUT })
    end

    local function showGmCmd(cmd)
        if isGMPanelHide() then
            return
        end
        self:showGmCommand(cmd)
    end

    local listCallBack = {
        [cc.KeyCode.KEY_ENTER] = function()
            showOrHideGM()
        end,

        [cc.KeyCode.KEY_KP_ENTER] = function()
            showOrHideGM()
        end,

        [cc.KeyCode.KEY_UP_ARROW] = function()
            showGmCmd(self:getLastGmCommand())
        end,

        [cc.KeyCode.KEY_DOWN_ARROW] = function()
            showGmCmd(self:getNextGmCommand())
        end,

        [cc.KeyCode.KEY_KP_PLUS] = function()
            self:increaseGmCommand()
        end,

        [cc.KeyCode.KEY_KP_MINUS] = function()
            self:decreaseGmCommand()
        end,

        [cc.KeyCode.KEY_ESCAPE] = function()
            if isGMPanelHide() then
                return
            end

            self.curGmIndex = 1
            sendNotification(UI_CLOSE_PANEL, { command = UI_MAIN_GM_INPUT })
        end,
    }

    local function onKeyReleased(keyCode, event)
        local callback = listCallBack[keyCode]
        if callback then
            callback()
        end
    end

    local listener = cc.EventListenerKeyboard:create()
    listener:registerScriptHandler(onKeyReleased, cc.Handler.EVENT_KEYBOARD_RELEASED)

    local eventDispatcher = scene:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listener, scene)
end

-- 是否是客户端gm
function GmManager:checkExeClientGm(gmText)
    -- 解析gm命令
    local tbGmText = string.split(gmText, " ")
    if #tbGmText < 1 then
        return
    end

    local funcName = gdClientGMList[tbGmText[1]]
    if not funcName then
        return
    end

    local func = gdClientGM[funcName]
    if not func then
        return
    end

    -- 获取剩余参数
    func(unpack(tbGmText, 2))
    return true
end

function GmManager:sendGMCommand()
    local ui = api_ui:getPanel(UI_MAIN_GM_INPUT)
    if not ui then
        return
    end

    local chateditbox = ccui.Helper:seekWidgetByName(ui, "chateditbox")
    local gmText = chateditbox:getText()
    if gmText == "" then
        return
    end

    -- 保存gm命令
    self:saveGmCommand(gmText)

    if self:checkExeClientGm(gmText) then
        return
    end

    api_msgbox:showPrompt("发送GM命令: " .. gmText .. " 成功")
    socialRequest.sendGMCommand(gmText)
end

-- 移除gm命令
function GmManager:removeGmCommand(index)
    if index == #self.tbGm then
        table.remove(self.tbGm, index)
        UserDataDefaultHelper.setStringData("", GM_DATA_KEY .. index, "")
        return
    end

    -- 重新保存、排序
    for i = index, #self.tbGm - 1 do
        UserDataDefaultHelper.setStringData("", GM_DATA_KEY .. i, self.tbGm[i+1])
    end

    UserDataDefaultHelper.setStringData("", GM_DATA_KEY .. #self.tbGm, "")
    table.remove(self.tbGm, index)
end

-- 保存gm命令
function GmManager:saveGmCommand(gmText)
    for i=#self.tbGm, 1, -1 do
        if self.tbGm[i] == gmText then
            self:removeGmCommand(i)
        end
    end

    if #self.tbGm >= MaxGmCount then
        self:removeGmCommand(1)
    end

    table.insert(self.tbGm, gmText)
    UserDataDefaultHelper.setStringData("", GM_DATA_KEY .. #self.tbGm, gmText)
end

-- 获取gm命令
function GmManager:getGmCommand()
    if self.curGmIndex > #self.tbGm then
        return ""
    end

    return self.tbGm[self.curGmIndex]
end

-- 获取上一条gm命令
function GmManager:getLastGmCommand()
    self.curGmIndex = self.curGmIndex - 1
    if self.curGmIndex < 1 then
        self.curGmIndex = #self.tbGm
    end

    local gmText = self.tbGm[self.curGmIndex]
    return gmText
end

-- 获取下一条gm命令
function GmManager:getNextGmCommand()
    self.curGmIndex = self.curGmIndex + 1
    if self.curGmIndex > #self.tbGm then
        self.curGmIndex = 1
    end

    local gmText = self.tbGm[self.curGmIndex]
    return gmText
end

-- 对gm命令的第一个数字加1
function GmManager:increaseGmCommand()
    local ui = api_ui:getPanel(UI_MAIN_GM_INPUT)
    if not ui then
        return
    end

    local chateditbox = ccui.Helper:seekWidgetByName(ui, "chateditbox")
    if not chateditbox then
        return
    end

    local gmText = chateditbox:getText()
    if gmText == "" then
        return
    end

    local tbGmText = string.split(gmText, " ")
    if not tbGmText then
        return
    end

    if #tbGmText < 1 then
        return
    end

    if string.find(tbGmText[2], "%d+") ~= nil then
        local num = tonumber(tbGmText[2])
        if not num then
            return
        end

        num = num + 1
        tbGmText[2] = tostring(num)

        local newGmText = table.concat(tbGmText, " ")
        chateditbox:setText(newGmText)
    end
end

-- 对gm命令的第一个数字减1
function GmManager:decreaseGmCommand()
    local ui = api_ui:getPanel(UI_MAIN_GM_INPUT)
    if not ui then
        return
    end

    local chateditbox = ccui.Helper:seekWidgetByName(ui, "chateditbox")
    if not chateditbox then
        return
    end

    local gmText = chateditbox:getText()
    if gmText == "" then
        return
    end

    local tbGmText = string.split(gmText, " ")
    if not tbGmText then
        return
    end

    if #tbGmText < 1 then
        return
    end

    if string.find(tbGmText[2], "%d+") ~= nil then
        local num = tonumber(tbGmText[2])
        if not num then
            return
        end

        num = num - 1
        tbGmText[2] = tostring(num)

        local newGmText = table.concat(tbGmText, " ")
        chateditbox:setText(newGmText)
    end
end

-- 显示gm命令
function GmManager:showGmCommand(gmText)
    local ui = api_ui:getPanel(UI_MAIN_GM_INPUT)
    if not ui then
        return
    end

    local chateditbox = ccui.Helper:seekWidgetByName(ui, "chateditbox")
    if not chateditbox then
        return
    end

    chateditbox:setText(gmText)
end

local instance

function GmManager.getInstance()
    if instance == nil then
        instance = GmManager.new()
    end
    return instance
end

return GmManager
