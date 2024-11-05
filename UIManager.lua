local UIManager = class("UIManager")
UI_STATUS = {
    OPEN = "OPEN",
    CLOSE = "CLOSE",
    HIDE = "HIDE"
}

UI_FULLSCREEN = false
UI_WILL_HIDE = false

local LayOutItemList = {}
local LayOutUIList = {}
local LayOutUIGroup = {}

local function LayOutUIGroupAdd(group, _winName)
    if LayOutUIGroup[group] == nil then
        LayOutUIGroup[group] = {}
    end
    local bAdd = false
    for i, v in ipairs(LayOutUIGroup[group]) do
        if _winName == v then
            bAdd = true
        end
    end

    if not bAdd then
        table.insert(LayOutUIGroup[group], _winName)
    end
end

local function LayOutUIGroupRemove(_winName)
    for key, g1 in pairs(LayOutUIGroup) do
        for key, value in pairs(g1) do
            if value == _winName then
                table.remove(g1, key)
                -- 如果为空
                if #g1 == 0 then
                    g1 = nil
                end
                break
            end
        end
    end
end

local function LayOutUIGroupCheck()
    for k, v in pairs(LayOutUIGroup) do
        -- 存在冲突
        for i = 1, #v do
            local info = api_ui:getItemInfo(v[i])
            if info ~= nil then
                if i == #v then
                    if info.status == UI_STATUS.OPEN then
                        info.panel:setVisible(true)
                    end
                else
                    if info.status == UI_STATUS.OPEN then
                        info.panel:setVisible(false)
                    end
                end
            end
        end
    end
end

function UIManager:ctor()
    self.m_panels = {}
    self.m_layer = cc.Layer:create()
    self.m_MaxZOrder = 0
    -- 启动界面线程 
    self.scheduler = api_schedule:registerSchedule("SCHEDULE_UI_MANAGER", 0, handler(self, self.update))
    self.m_layer:setTouchEnabled(true)
    self.componentsRemove = {}

    self.hideTemp = {}

    local function onNodeEvent(event)
        if "exit" == event then
        end
    end
    self.m_layer:registerScriptHandler(onNodeEvent)
end

-- 打开UI窗体
function UIManager:open(_winName, data)
    local _parent = nil
    local _root = nil
    local _onlycreate = nil
    local _fix = nil
    if data ~= nil then
        _parent = data.parent
        _root = data.root
        _onlycreate = data.onlycreate
        _fix = data.fix
    end
    if ERROR_LOG == 1 then
        local pc = popupcommands[_winName]
        if pc then
            print("open-------------------------------》》》", pc.command, pc.mediator, UIFrames[pc.command].path)
        end
    end

    -- NotifyHelper.msgShow("窗口-->".._winName)

    if self:isExist(_winName) then
        -- 仅创建
        if _onlycreate then
            return
        end
        local itemInfo = self:getItemInfo(_winName)
        local lastStatus = itemInfo.status
        if lastStatus == UI_STATUS.CLOSE then
            return
        end
        itemInfo.status = UI_STATUS.OPEN
        itemInfo.panel:setVisible(true)

        -- UI组，组内界面显示唯一
        if itemInfo.group ~= nil then
            LayOutUIGroupAdd(itemInfo.group, _winName)
        end

        if itemInfo.mask ~= nil then
            itemInfo.mask:setVisible(true)
        end

        local function on_big_end()
            if _winName == "UI_CHAT" then
                showUiChat = false
            end

            if itemInfo.fullscreen and itemInfo.panel:isVisible() then
                self:onFullScreenShow()
            end
        end

        if itemInfo.show ~= nil then
            if lastStatus ~= UI_STATUS.OPEN then
                api_panel_effect_manager:CreateEffect(itemInfo.show, itemInfo.panel, on_big_end)
            end
        else
            if itemInfo.fullscreen then
                self:onFullScreenShow()
            end
        end

        self:bringToFront(itemInfo.panel)
        api_novice:onUIOpen(itemInfo.name)
        api_guide:onUIOpen(itemInfo.name)
        sendNotification(UI_SHOW_PANEL .. tostring(itemInfo.name), data)

        local _items = GetUIFrameItem(_winName)
        if _items and _items.open_sound then
            api_audio:play(_items.open_sound)
        end
        return
    end
    local _item = GetUIFrameItem(_winName)
    local _uilayout = nil
    if LayOutUIList[_item.path] == nil then
        LayOutUIList[_item.path] = ccs.GUIReader:getInstance():widgetFromBinaryFile(_item.path)
        LayOutUIList[_item.path]:retain()
    end
    LayOutUIList[_item.path]:retain()
    _uilayout = LayOutUIList[_item.path]:clone()
    if _uilayout and _item.outlineinfo then
        for k, v in pairs(_item.outlineinfo) do
            if v and v.labelname and v.labelname ~= "" and v.color and v.t then
                if v.t == 1 then
                    local lbl = ccui.Helper:seekWidgetByName(_uilayout, v.labelname)
                    if lbl and string.find(lbl:getDescription(), 'Label') ~= nil then
                        lbl:enableOutline(v.color, 2)
                    end
                elseif v.t == 2 then
                    local btn = ccui.Helper:seekWidgetByName(_uilayout, v.labelname)
                    if btn and string.find(btn:getDescription(), 'Button') ~= nil then
                        local lbl = btn:getTitleLabel()
                        if lbl and string.find(lbl:getDescription(), 'Label') ~= nil then
                            lbl:enableOutline(v.color, 2)
                        end
                    end
                end
            end
        end
    end
    LayOutUIList[_item.path]:release()

    -- UI组，组内界面显示唯一
    if _item.group ~= nil then
        LayOutUIGroupAdd(_item.group, _winName)
    end
    _uilayout:setName(_winName)
    if _root == nil then
        _root = _parent
    end

    -- 设置布局 
    self:setLayout(_uilayout, _item.layout, _item.fix, _parent, _fix)

    -- 设置mask
    local maskLayer = nil
    if _item.mask ~= 0 then
        local mode = _item.mask
        maskLayer = self:createMaskLayer(mode, _item.shadow)
        maskLayer:setName(_winName .. "|mask")
        local w = _uilayout:getContentSize().width
        local h = _uilayout:getContentSize().height
        local mask_w = maskLayer:getContentSize().width
        local mask_h = maskLayer:getContentSize().height

        maskLayer:setPosition((w - mask_w) / 2, (h - mask_h) / 2)
        maskLayer:setVisible(true)
        _uilayout:addChild(maskLayer, -1000)
    end

    -- 检测是否绑定界面
    if commandsrelation[_winName] then
        local relationInfo = commandsrelation[_winName]
        local bindPanel = api_ui:getPanel(relationInfo["bind"])
        if bindPanel then
            relationInfo.action.openAction(bindPanel, _uilayout)
        end
    end

    self:bringToFront(_uilayout)
    -- 如果该窗体有父节点
    if _parent ~= nil and not tolua.isnull(_parent) then
        _parent:addChild(_uilayout)
    else
        self.m_layer:addChild(_uilayout)
    end
    local status = UI_STATUS.OPEN
    -- 仅创建
    if _onlycreate then
        status = UI_STATUS.HIDE
        _uilayout:setVisible(false)
        if maskLayer ~= nil then
            maskLayer:setVisible(false)
        end
    else
        local function on_big_end()
            if _item.fullscreen and _uilayout:isVisible() then
                self:onFullScreenShow()
            end
        end

        if _item.show ~= nil then
            api_panel_effect_manager:CreateEffect(_item.show, _uilayout, on_big_end)
        else
            if _item.fullscreen then
                self:onFullScreenShow()
            end
        end

        if _item.blur then
            local blurmap = self.m_layer:getChildByName("blur_map")
            local blackmap = self.m_layer:getChildByName("black_map")

            if api_map:getMapLayer() and api_map:getMapLayer():getChildren() and api_map:getMapLayer():getChildren()[2] then
                local miniPath = "map/minimap/mini_"
                local mapData = nil
                mapData = cb_get_map_data(api_map.mSceneId)
                local mjp = mapData.resource
                local fullPath = string.format("%s%s%s", miniPath, mjp, ".png")
                if not cc.FileUtils:getInstance():isFileExist(fullPath) then
                    fullPath = string.format("%s%s%s", miniPath, mjp, ".jpg")
                end

                blurmap = cc.Sprite:create(fullPath)
                local is_night = gdMaps[api_map.mSceneId].isnight or 0
                if is_night == 1 then
                    blurmap:setColor(cc.c3b(35, 143, 171))
                end
                blurmap:setAnchorPoint(cc.p(0, 1))
                local bx, by = api_map:getMapLayer():getChildren()[1]:getPosition()
                local mapw = (math.ceil(TILE_WIDTH * mapData.sizex / 256) * 256)
                local maph = (math.ceil(TILE_HEIGHT * mapData.sizey / 256) * 256)
                blurmap:setScaleX(mapw / blurmap:getContentSize().width)
                blurmap:setScaleY(maph / blurmap:getContentSize().height)
                local n_bx = bx + mapw / 2
                local n_by = by - maph / 2
                blurmap:setPosition(bx, by)
            end
            local blacklayer = cc.LayerColor:create(cc.c3b(0, 0, 0), 10000, 10000)
            blacklayer:setPosition(-2000, -2000)
            _uilayout:addChild(blacklayer, -1100)
            blacklayer:setName("black_map")
            _uilayout:addChild(blurmap, -1050)
            blurmap:setName("blur_map")
        end
    end
    sendNotification(UI_OPEN_READY, {command = _winName})
    table.insert(self.m_panels, {
        name = _winName,
        panel = _uilayout,
        zorder = _uilayout:getLocalZOrder(),
        parent = _parent,
        root = _root,
        status = status,
        mask = maskLayer,
        show = _item.show,
        hide = _item.hide,
        fullscreen = _item.fullscreen,
        group = _item.group
    })
    if _item.open_sound then
        api_audio:play(_item.open_sound)
    end
end

-- 获取当前层级
function UIManager:getCurrentZOrder(hierarchy)
    if not hierarchy then
        hierarchy = UI_LAYER_MID
    end
    local maxZOrder = 0
    -- 最底层
    if hierarchy == UI_LAYER_BOTTOM then
        maxZOrder = -10000
        -- 最上层
    elseif hierarchy == UI_LAYER_TOP then
        maxZOrder = 10000
        -- 中层
    else
        maxZOrder = 0
    end
    local childs = self.m_layer:getChildren()
    for i = 1, #childs, 1 do
        local uiInfo = GetUIFrameItem(childs[i]:getName())
        local uihierarchy = uiInfo and uiInfo.hierarchy or UI_LAYER_MID
        if hierarchy == UI_LAYER_TOP then
            if maxZOrder < childs[i]:getLocalZOrder() then
                maxZOrder = childs[i]:getLocalZOrder()
            end
        else
            if uihierarchy == hierarchy then
                if maxZOrder < childs[i]:getLocalZOrder() and childs[i]:getLocalZOrder() < 1000 then
                    maxZOrder = childs[i]:getLocalZOrder()
                end
            end
        end
    end
    return maxZOrder + 1
end

function UIManager:bringToFront(layerOut)
    local uiname = layerOut:getName()
    if uiname then
        local uiInfo = GetUIFrameItem(uiname)
        local hierarchy = UI_LAYER_MID
        if uiInfo then
            hierarchy = uiInfo.hierarchy
        end
        local currentZorder = self:getCurrentZOrder(hierarchy)
        layerOut:setLocalZOrder(currentZorder)
    end
end

function UIManager:isOpen(winName)
    for _, v in pairs(self.m_panels) do
        if v.name == winName and v.status == UI_STATUS.OPEN then
            return true
        end
    end

    return false
end

-- 判断是否存在这个面板
function UIManager:isExist(_winName)
    for _, v in pairs(self.m_panels) do
        if v.name == _winName then
            return true
        end
    end
    return false
end

-- 获取详细信息
function UIManager:getItemInfo(_winName)
    for _, v in pairs(self.m_panels) do
        if v.name == _winName then
            return v
        end
    end
    return nil
end

-- 获取UI面板
function UIManager:getPanel(_winName)
    for _, v in pairs(self.m_panels) do
        if v.name == _winName then
            return v.panel
        end
    end
    return nil
end

function UIManager:isHighPanel(_winName)
    if _winName == nil then
        return false
    end
    local m_ui = self:getPanel(_winName)
    if m_ui == nil then
        return false
    end

    local index = m_ui:getLocalZOrder()
    for k, v in pairs(self.m_panels) do
        if v.status == UI_STATUS.OPEN then
            if v.panel:getParent() == self.m_layer and v.panel:getLocalZOrder() > index then
                return false
            end
        end
    end
    return true
end

-- 获取ui层
function UIManager:getUILayer()
    return self.m_layer
end

-- 关闭UI面板
function UIManager:close(_winName)
    if commandsrelation[_winName] then
        local relationInfo = commandsrelation[_winName]
        local bindPanel = api_ui:getPanel(relationInfo.bind)
        if bindPanel then
            relationInfo.action.closeAction(bindPanel)
        end
    end
    -- 删除组对象
    LayOutUIGroupRemove(_winName)

    for _, v in pairs(self.m_panels) do
        if v.name == _winName then
            v.status = UI_STATUS.CLOSE
            local _item = GetUIFrameItem(_winName)
            if _item and _item.close_sound then
                api_audio:play(_item.close_sound)
            end
        end
    end
    --
    if MsgboxHelper.openUI == _winName then
        MsgboxHelper.openUI = nil
    end

    -- 清掉当前界面的远程加载
    api_rui:destroyUI(_winName)
end

-- 隐藏UI界面
function UIManager:hide(_winName)
    -- 删除组对象
    LayOutUIGroupRemove(_winName)

    for _, v in pairs(self.m_panels) do
        if v.name == _winName then
            if v.status == UI_STATUS.OPEN then
                v.status = UI_STATUS.HIDE
                local _item = GetUIFrameItem(_winName)
                if _item and _item.close_sound then
                    api_audio:play(_item.close_sound)
                end
            end
        end
    end
end

function UIManager:set_full_screen_ui_show(uiname)
    local ui = (self:getItemInfo(uiname) or {}).panel
    if ui then
        ui.oldVisible = ui:isVisible()
        ui:setVisible(false)
    end
end

-- 实际干的是显示的事情
function UIManager:set_full_screen_ui_hide(uiname)
    local ui = (self:getItemInfo(uiname) or {}).panel
    if ui then
        ui:setVisible(true)
    end
end

function UIManager:onFullScreenShow()
    if api_map.mSceneId == MapID.mls then
        return
    end

    self:set_full_screen_ui_show(UI_MAIN_PLAYER_INFO)
    self:set_full_screen_ui_show(UI_MAIN_MINI_MAP)
    self:set_full_screen_ui_show(UI_MAIN_SYSTEM_MENU)
    self:set_full_screen_ui_show(UI_MAIN_EXP_PROGRESS)
    self:set_full_screen_ui_show(UI_MAIN_SKILL_CONTROL)
    self:set_full_screen_ui_show(UI_MINI_CHAT)
    self:set_full_screen_ui_show(UI_MAIN_RIGHT_PANEL)
    self:set_full_screen_ui_show(UI_WQTASK)
    api_ghost.layer:setVisible(false)
end

function UIManager:onFullScreenHide()
    if api_map.mSceneId == MapID.mls then
        return
    end

    self:set_full_screen_ui_hide(UI_MAIN_PLAYER_INFO)
    self:set_full_screen_ui_hide(UI_MAIN_MINI_MAP)
    self:set_full_screen_ui_hide(UI_MAIN_SYSTEM_MENU)
    self:set_full_screen_ui_hide(UI_MAIN_EXP_PROGRESS)
    self:set_full_screen_ui_hide(UI_MAIN_SKILL_CONTROL)
    self:set_full_screen_ui_hide(UI_MINI_CHAT)
    self:set_full_screen_ui_hide(UI_MAIN_RIGHT_PANEL)
    self:set_full_screen_ui_hide(UI_WQTASK)
    api_ghost.layer:setVisible(true)
end

-- 组件移出回收
function UIManager:componentRemove(compoent)
    table.insert(self.componentsRemove, compoent)
end

-- 根据优先级  关闭同组中的界面
function UIManager:dealWithSameGroup(winName)
    local _item = GetUIFrameItem(winName)
    if _item and _item.groupid then
        local groupid = _item.groupid
        local order = _item.order or 0
        -- 关之前界面  
        local groupData = gdUIGroup[groupid] or {}
        for k, v in pairs(groupData) do
            if self:getUIStatus(v.name) == UI_STATUS.OPEN and v.name ~= winName then
                if v.order < order then
                    sendNotification(UI_HIDE_PANEL, {command = v.name})
                else
                    return false
                end
            end
        end
    end
    return true
end

function UIManager:removeChild(panel)
    -- 清理他的所有子对象
    for k, v1 in pairs(self.m_panels) do
        if v1.root == panel then
            -- 主动触发关闭事件
            sendNotification(UI_CLOSE_PANEL .. tostring(v1.name))
            api_guide:onUIClose(v1.name)
            self.m_panels[k] = nil
            self:removeChild(v1.panel)
            -- 清掉当前界面子节点的远程加载
            api_rui:destroyUI(v1.name)
            v1.panel:removeFromParent()
        end
    end
end

function UIManager:hideChild(panel)
    -- 隐藏他的所有子对象
    for k, v1 in pairs(self.m_panels) do
        if v1.root == panel then
            sendNotification(UI_HIDE_PANEL .. tostring(v1.name))
        end
    end
end

-- 获取界面状态
function UIManager:getUIStatus(_winName)
    for _, v in pairs(self.m_panels) do
        if v.name == _winName then
            return v.status
        end
    end
    return UI_STATUS.CLOSE
end

-- 更新界面层
function UIManager:update()
    for k, v in pairs(self.m_panels) do
        if v.status == UI_STATUS.CLOSE then
            if v.mask ~= nil then
                v.mask:removeFromParent()
            end

            if v.fullscreen then
                self:onFullScreenHide()
            end

            api_guide:onUIClose(v.name)

            self.m_panels[k] = nil
            self:removeChild(v.panel)
            v.panel:removeFromParent()
        elseif v.status == UI_STATUS.HIDE then
            if v.mask ~= nil then
                v.mask:setVisible(false)
            end
            if v.panel:isVisible() then
                if v.hide == nil then
                    v.panel:setVisible(false)
                    if v.fullscreen then
                        self:onFullScreenHide()
                    end
                else
                    api_hide_panel_effect_manager:CreateEffect(1, v.panel)
                end
                self:hideChild(v.panel)
            end
        end
    end

    LayOutUIGroupCheck()

    -- 移除组件
    for _, v in pairs(self.componentsRemove) do
        self.componentsRemove[_] = nil
        if v and not tolua.isnull(v) then
            v:removeFromParent()
        end
    end
end

function UIManager:setLayout(panel, layout, fix, parent, ex_fix)
    local layouts = Split(layout, "|")
    panel:setAnchorPoint(cc.p(UILayout["x" .. layouts[1]].AnchorPointX, UILayout["y" .. layouts[2]].AnchorPointY))

    local layX = UILayout["x" .. layouts[1]].PositionX
    local layY = UILayout["y" .. layouts[2]].PositionY

    if IS_IPHONEX == 1 and (parent == self.m_layer or parent == nil) then
        if layouts[1] == "left" then
            layX = layX + 44
        elseif layouts[1] == "right" then
            layX = layX - 44
        end
    end

    if fix then
        layX = layX + fix[1]
        layY = layY + fix[2]
    end

    if ex_fix then
        layX = layX + ex_fix[1]
        layY = layY + ex_fix[2]
    end

    panel:setPosition(cc.p(layX, layY))
end

local instance = nil
function UIManager.getInstance()
    if instance == nil then
        instance = UIManager.new()
    end
    return instance
end

function UIManager:clearItemList()
    for key, var in pairs(LayOutItemList) do
        var:release()
    end

    LayOutItemList = {}
end

function UIManager:clearUIList()
    for key, var in pairs(LayOutUIList) do
        var:release()
    end

    LayOutUIList = {}
end

function UIManager:clearAll()
    api_ui:clearItemList()
    api_ui:clearUIList()
    for _, v in pairs(self.m_panels) do
        sendNotification(UI_CLOSE_PANEL .. tostring(v.name))
        v.status = UI_STATUS.CLOSE
    end
    sendNotification(UI_TIP_CLOSE, {})
end

function UIManager:hideAll()
    for _, v in pairs(self.m_panels) do
        if v.status == UI_STATUS.OPEN and v.panel:isVisible() and v.name ~= "UI_MAIN" and v.name ~= "UI_MINI_CHAT" then
            local item = GetUIFrameItem(v.name)
            if item.groupid and item.groupid == 1 then
                table.insert(self.hideTemp, v)
                v.panel:setVisible(false)
            else
                sendNotification(UI_CLOSE_PANEL, {command = v.name})
            end
        end
    end
    sendNotification(UI_HIDE_PANEL, {})
end

function UIManager:showHideTemp()
    for _, v in pairs(self.hideTemp) do
        for __, j in pairs(self.m_panels) do
            if v.name == j.name then
                j.panel:setVisible(true)

                if v.name == UI_AUTO_EQUIP then
                    if not MyRole.mAutoEquips[1] then
                        j.panel:setVisible(false)
                    end
                end
                break
            end
        end
    end
    sendNotification(UI_HIDE_PANEL, {command = UI_CHAT_REDPACKET_PNLJ})
    sendNotification(UI_HIDE_PANEL, {command = UI_CHAT})
    sendNotification(UI_HIDE_PANEL, {command = UI_CHAT_TOOL})
    sendNotification(UI_OPEN_PANEL, {})
    self.hideTemp = {}
end

function UIManager:closeCurrentPanel()
    for _, v in pairs(self.m_panels) do
        if v.status == UI_STATUS.OPEN and v.panel:isVisible() and v.name ~= "UI_MAIN" and v.name ~= "UI_MINI_CHAT" then
            local item = GetUIFrameItem(v.name)
            if not item.groupid or item.groupid ~= 1 then
                sendNotification(UI_CLOSE_PANEL, {command = v.name})
            end
        end
    end
end

function UIManager:getLayoutItem(itemName, saved)
    local _item = GetUIFrameItem(itemName)
    local _uilayout = nil
    if LayOutItemList[_item.path] == nil then
        LayOutItemList[_item.path] = ccs.GUIReader:getInstance():widgetFromBinaryFile(_item.path)
        LayOutItemList[_item.path]:retain()
    end
    LayOutItemList[_item.path]:retain()
    _uilayout = LayOutItemList[_item.path]:clone()
    if _uilayout and _item.outlineinfo then
        for k, v in pairs(_item.outlineinfo) do
            if v and v.labelname and v.labelname ~= "" and v.color and v.t then
                if v.t == 1 then
                    local lbl = ccui.Helper:seekWidgetByName(_uilayout, v.labelname)
                    if lbl and string.find(lbl:getDescription(), 'Label') ~= nil then
                        lbl:enableOutline(v.color, 2)
                    end
                elseif v.t == 2 then
                    local btn = ccui.Helper:seekWidgetByName(_uilayout, v.labelname)
                    if btn and string.find(btn:getDescription(), 'Button') ~= nil then
                        local lbl = btn:getTitleLabel()
                        if lbl and string.find(lbl:getDescription(), 'Label') ~= nil then
                            lbl:enableOutline(v.color, 2)
                        end
                    end
                end
            end
        end
    end
    LayOutItemList[_item.path]:release()

    return _uilayout
end

function UIManager:showBrotherBattleMainPanel()
    self:set_full_screen_ui_show(UI_MAIN_MINI_MAP)
    self:set_full_screen_ui_show(UI_MAIN_SYSTEM_MENU)
    self:set_full_screen_ui_show(UI_WQTASK)
    self:set_full_screen_ui_show(UI_MAIN_RIGHT_PANEL)
    self:set_full_screen_ui_hide(UI_XJP_MAIN_8)
    sendNotification(UI_OPEN_PANEL, {command = UI_XJP_DFS_ZHANDOU_2})
    sendNotification(UI_OPEN_PANEL, {command = UI_XJP_DFS_ZHANDOU_4})
    sendNotification(UI_OPEN_PANEL, {command = UI_XJP_DFS_ZHANDOU_5})
    sendNotification(UI_OPEN_PANEL, {command = UI_XJP_DFS_ZHANDOU_3})
end

function UIManager:hideBrotherBattleMainPanel()
    self:set_full_screen_ui_hide(UI_MAIN_MINI_MAP)
    self:set_full_screen_ui_hide(UI_MAIN_SYSTEM_MENU)
    self:set_full_screen_ui_hide(UI_WQTASK)
    self:set_full_screen_ui_hide(UI_MAIN_RIGHT_PANEL)
    sendNotification(UI_CLOSE_PANEL, {command = UI_XJP_DFS_ZHANDOU_2})
    sendNotification(UI_CLOSE_PANEL, {command = UI_XJP_DFS_ZHANDOU_4})
    sendNotification(UI_CLOSE_PANEL, {command = UI_XJP_DFS_ZHANDOU_5})
    sendNotification(UI_CLOSE_PANEL, {command = UI_XJP_DFS_ZHANDOU_3})
end


function UIManager:showPlayerBattleMainPanel()
    self:set_full_screen_ui_show(UI_MAIN_MINI_MAP)
    self:set_full_screen_ui_show(UI_MAIN_SYSTEM_MENU)
    self:set_full_screen_ui_show(UI_WQTASK)
    self:set_full_screen_ui_show(UI_MAIN_RIGHT_PANEL)
    self:set_full_screen_ui_hide(UI_XJP_MAIN_8)
    sendNotification(UI_OPEN_PANEL,{command = UI_XJP_DFS_ZHANDOU_4})
    sendNotification(UI_OPEN_PANEL,{command = UI_XJP_DFS_ZHANDOU_5})
    sendNotification(UI_OPEN_PANEL,{command = UI_XJP_GRS_ZHANDOU_3})
end

function UIManager:hidePlayerBattleMainPanel()
    self:set_full_screen_ui_hide(UI_MAIN_MINI_MAP)
    self:set_full_screen_ui_hide(UI_MAIN_SYSTEM_MENU)
    self:set_full_screen_ui_hide(UI_WQTASK)
    self:set_full_screen_ui_hide(UI_MAIN_RIGHT_PANEL)
    sendNotification(UI_CLOSE_PANEL,{command = UI_XJP_DFS_ZHANDOU_4})
    sendNotification(UI_CLOSE_PANEL,{command = UI_XJP_DFS_ZHANDOU_5})
    sendNotification(UI_CLOSE_PANEL,{command = UI_XJP_GRS_ZHANDOU_3})
end

function UIManager:showGuildBattleMainPanel()
    self:set_full_screen_ui_show(UI_MAIN_SYSTEM_MENU)
    self:set_full_screen_ui_show(UI_MAIN_RIGHT_PANEL)
    self:set_full_screen_ui_hide(UI_XJP_MAIN_8)
    sendNotification(UI_OPEN_PANEL, {command = UI_XJP_DFS_ZHANDOU_5})
end

function UIManager:hideGuildBattleMainPanel()
    self:set_full_screen_ui_hide(UI_MAIN_SYSTEM_MENU)
    self:set_full_screen_ui_hide(UI_MAIN_RIGHT_PANEL)
    sendNotification(UI_CLOSE_PANEL, {command = UI_XJP_DFS_ZHANDOU_5})
end

--------------------------------
-- 创建遮照层
--------------------------------
function UIManager:createMaskLayer(mode, shadow)
    local layer
    if shadow ~= nil then
        layer = cc.LayerColor:create(cc.c4b(0, 0, 0, 150))
    else
        layer = cc.Layer:create()
    end

    mode = math.abs(mode)
    layer:setTouchEnabled(true)
    local eventDispatcher = layer:getEventDispatcher()
    local function onTouchBegan(touch, event)
        local winName = Split(layer:getName(), "|")[1]
        if layer:isVisible() == false then
            return false
        end

        if winName ~= nil and winName ~= "" then
            local panel = api_ui:getPanel(winName)
            if panel then -- cocos在遍历对象时候 有可能更改遮罩和界面层级的深度  这时调整一次  
                if panel:getLocalZOrder() <= layer:getLocalZOrder() then
                    panel:setLocalZOrder(layer:getLocalZOrder() + 1)
                    return false
                end
            end
            if mode == 1 then
                if winName == "UI_HERO" then
                    if MyRole.getProp(ENTITY_PROP_TALENT_UNSAVE) == 1 then -- 未保存 
                        sendNotification(UI_OPEN_PANEL, {command = UI_MSG_SAVE_TALENT, index_mem = -1})
                        return true
                    end
                end
                sendNotification(UI_CLOSE_PANEL, {command = winName})
            elseif mode == 2 then
                if winName == "DialogUIMask" then
                    sendNotification(EVENT_HILD_MSGBOX)
                    return true
                end
            elseif mode == 3 then
                sendNotification(UI_HIDE_PANEL, {command = winName})
            elseif mode == 4 then
                sendNotification(UI_TIP_CLOSE)
            elseif mode == 5 then
                sendNotification(UI_MASK_TOUCHED .. winName)
            end
        else
            api_ui:componentRemove(layer)
        end
        return true
    end
    local listener = cc.EventListenerTouchOneByOne:create()
    listener:registerScriptHandler(onTouchBegan, cc.Handler.EVENT_TOUCH_BEGAN)
    if mode ~= 4 then
        listener:setSwallowTouches(true)
    end

    eventDispatcher:addEventListenerWithSceneGraphPriority(listener, layer)
    return layer
end

--
-- get遮罩  
--
function UIManager:getMaskLayer(winName)
    local childs = self.m_layer:getChildren()
    local layoutLayer = nil
    for k, v in pairs(childs) do
        if v:getName() == winName then
            layoutLayer = v
            break
        end
    end
    if not layoutLayer then
        return false
    end
    local maskLayer = nil
    local layoutChilds = layoutLayer:getChildren()
    for k, v in pairs(layoutChilds) do
        if v:getName() == winName .. "|mask" then
            maskLayer = v
            break
        end
    end
    return maskLayer
end

-- --切换场景需要关闭界面 和 隐藏界面
function UIManager:closeOnChangeMap()
    for _, v in pairs(self.m_panels) do
        if v.status == UI_STATUS.OPEN then
            local uiFrame = GetUIFrameItem(v.name)
            if MyRole.isOffTuoguan() and uiFrame.gjjump and uiFrame.gjjump == 1 then

            else
                if uiFrame.close_on_change_map == 1 then
                    sendNotification(UI_CLOSE_PANEL, {command = v.name})
                elseif uiFrame.close_on_change_map == 2 then
                    sendNotification(UI_HIDE_PANEL, {command = v.name})
                end
            end
        end
    end
end

function UIManager:cccAll()
    local childTab = {}
    local childs = api_ui:getUILayer():getChildren()
    for i = 1, #childs, 1 do
        local order = childs[i]:getLocalZOrder()
        if order > 0 then
            local name = childs[i]:getName()
            if api_ui:getItemInfo(name) then
                local status = api_ui:getItemInfo(name).status
                if status == UI_STATUS.OPEN then
                    local item = GetUIFrameItem(name)
                    if item then
                        if item.negative then
                        else
                            sendNotification(UI_CLOSE_PANEL, {command = name})
                        end
                    end
                end
            end
        end
    end
end

function UIManager:hasCoverUI()
    local childTab = {}
    local childs = api_ui:getUILayer():getChildren()
    for i = 1, #childs, 1 do
        local order = childs[i]:getLocalZOrder()
        if order > 0 then
            local name = childs[i]:getName()
            if api_ui:getItemInfo(name) then
                local status = api_ui:getItemInfo(name).status
                if status == UI_STATUS.OPEN then
                    local item = GetUIFrameItem(name)
                    if item then
                        if item.negative then
                        else
                            table.insert(childTab, childs[i])
                        end
                    end
                end
            end
        end
    end

    return #childTab > 0
end

return UIManager
