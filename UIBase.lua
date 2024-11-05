-- UI 基类 --
local Cls = class("BASE_UI")

-- 引用 --
local Scheduler = cc.Director:getInstance():getScheduler()  -- 全局定时器
local RoundList = require("xf.engine.ui.RoundList")         -- RoundList 组件
local ReactiveSystem = require("xf.engine.ReactiveSystem") -- 响应式系统
local bind = OperatorUtils.bind                             -- 绑定上下文

-- 构造方法 --
function Cls:ctor(UI_NAME, isMainPanel)
    -- 字段列表
    self._FIELDS = {} -- 防止和子类字段冲突

    -- 字段 --
    self._FIELDS.notifications = {} -- 通知列表
    self._FIELDS.props = {}         -- 属性通知列表
    self._FIELDS.events = {}        -- 事件通知列表
    self._FIELDS.serverFuncs = {}   -- 服务器响应通知列表
    self._FIELDS.capitals = {}      -- 货币通知列表

    self._FIELDS.schedulers = {}    -- 定时器列表
    self._FIELDS.roundLists = {}    -- RoundList 列表
    self._FIELDS.reactives = {}     -- 响应式对象列表

    self._FIELDS.ui_name = UI_NAME                          -- ui 名
    self._FIELDS.ui_root = api_ui:getPanel(UI_NAME)         -- ui 根节点
    self._FIELDS.ui = self:uiDelegate(self._FIELDS.ui_root) -- ui 代理

    -- 注册关闭通知
    self:registerNotification(UI_CLOSE_PANEL .. UI_NAME, self.dtor)

    -- 主面板
    if isMainPanel and self._FIELDS.ui.btn_close then
        self:bindClick(self._FIELDS.ui.btn_close, 1.0, function()
            self:closeSelf()
        end)
    end
end

-- 析构方法 --
function Cls:dtor()
    -- 清空通知
    self:removeAllNotification()

    -- 清空定时器
    self:unscheduleAll()

    -- 清除RoundList
    self:clearAllRoundList()

    -- 清除响应式对象
    self:clearAllReactives()

    if type(self.onClose) == "function" then
        self:onClose()
    end
end

-- 事件 --
-- 消息监听
function Cls:registerNotification(id, fn)
    -- 已注册, 先注销
    self:removeNotification(id)

    local fn_bind = bind(fn, self)
    registerNotification(id, fn_bind)        -- 注册
    self._FIELDS.notifications[id] = fn_bind -- 缓存
end

-- 移除消息监听
function Cls:removeNotification(id)
    if self._FIELDS.notifications[id] then
        removeNotification(id, self._FIELDS.notifications[id])
        self._FIELDS.notifications[id] = nil
    end
end

-- 删除所有通知监听
function Cls:removeAllNotification()
    -- 注销所有通知监听
    for id, func in pairs(self._FIELDS.notifications) do
        removeNotification(id, func)
    end

    -- 清空
    self._FIELDS.notifications = {}

    -- 清除属性通知
    self._FIELDS.props = {}

    -- 清除事件通知
    self._FIELDS.events = {}

    -- 清除服务器响应通知
    self._FIELDS.serverFuncs = {}

    -- 清除货币通知
    self._FIELDS.capitals = {}
end

-- 注册玩家属性变化通知, 可重复调用
function Cls:regPlayerPropChanged(propId, callback, ...)
    self._FIELDS.props[propId] = bind(callback, ...)

    self:registerNotification(PLAYER_PROP_CHANGED, function(_, event)
        local d = event._userData

        local fn = self._FIELDS.props[d.type]
        if fn then
            fn(d.data, d.oldData)
        end
    end)
end

-- 注册玩家事件属性变化通知, 可重复调用
function Cls:regPlayerEventChanged(eventId, callback, ...)
    self._FIELDS.events[eventId] = bind(callback, ...)

    self:registerNotification(PLAYER_EVENT_CHANGED, function(_, event)
        local d = event._userData

        local fn = self._FIELDS.events[d.eventid]
        if fn then
            fn(d.datax, d.datay, d.dataz, d.oldX, d.oldY, d.oldZ)
        end
    end)
end

-- 注册服务器响应通知，可重复调用
function Cls:regServerResponce(funcId, callback, ...)
    self._FIELDS.serverFuncs[funcId] = bind(callback, ...)

    self:registerNotification(FUNC_SERVER_RESPONCE, function(_, event)
        local d = event._userData

        local fn = self._FIELDS.serverFuncs[d.funcId]
        if fn then
            fn(d.datax, d.datay, d.dataz, d.datas)
        end
    end)
end

-- 货币发生变化通知
function Cls:regCapitalChanged(capitalType, callback, ...)
    self._FIELDS.capitals[capitalType] = bind(callback, ...)

    self:registerNotification(PROXY_CAPITAL_UPDATE, function(_, event)
        local d = event._userData

        local fn = self._FIELDS.capitals[d.type]
        if fn then
            fn()
        end
    end)
end

-- 定时器 --
function Cls:schedule(interval, func, ...)
    local func_bind = bind(func, ...)
    local schedulerId = Scheduler:scheduleScriptFunc(function()
        func_bind()
    end, interval, false)

    self._FIELDS.schedulers[schedulerId] = func_bind
    return schedulerId
end

-- 一次性定时器 (延时调用)
function Cls:scheduleOnce(delay, func, ...)
    local schedulerId = nil
    local func_bind = bind(func, ...)

    schedulerId = Scheduler:scheduleScriptFunc(function()
        func_bind()
        self:unschedule(schedulerId)
    end, delay, false)

    self._FIELDS.schedulers[schedulerId] = func_bind
    return schedulerId
end

-- 一次性定时器 (防抖刷新)
function Cls:scheduleDebounce(func, wait)
    local schedulerId = nil
    return function(...)
        if schedulerId then
            self:unschedule(schedulerId)
        end

        local args = {...}
        schedulerId = Scheduler:scheduleScriptFunc(function()
            func(OperatorUtils.unpack(args))
            self:unschedule(schedulerId)
            schedulerId = nil
        end, wait, false)

        self._FIELDS.schedulers[schedulerId] = func
    end
end

-- 有限次数定时器
function Cls:scheduleRepeat(interval, repeat_count, func, ...)
    local schedulerId = nil
    local func_bind = bind(func, ...)

    schedulerId = Scheduler:scheduleScriptFunc(function()
        func_bind()
        repeat_count = repeat_count - 1
        if repeat_count <= 0 then
            self:unschedule(schedulerId)
        end
    end, interval, false)

    self._FIELDS.schedulers[schedulerId] = func_bind
    return schedulerId
end

-- 取消定时器
function Cls:unschedule(schedulerId)
    if schedulerId then
        Scheduler:unscheduleScriptEntry(schedulerId)
        self._FIELDS.schedulers[schedulerId] = nil
    end
end

-- 取消所有定时器
function Cls:unscheduleAll()
    for scheduleId, _ in pairs(self._FIELDS.schedulers) do
        self:unschedule(scheduleId)
    end

    self._FIELDS.schedulers = {}
end
-- UI --
-- ui代理：当使用 ui.xxx 时，自动查找节点；也可ui["xxx.xxx"]多级查找
function Cls:uiDelegate(widget)
    if not self:isValidWidget(widget) then
        return {}
    end

    local mt = {
        __index = function(t, k)
            local listNodeName = string.split(k, ".")
            local len = #listNodeName

            if 1 == len then
                local w = ccui.Helper:seekWidgetByName(widget, k)
                rawset(t, k, w)
                return w
            end

            local w = widget
            for i = 1, len do
                w = ccui.Helper:seekWidgetByName(w, listNodeName[i])
                if not w then
                    print("uiDelegate: widget not found: ", listNodeName[i])
                    return nil
                end
            end

            rawset(t, k, w)
            return w
        end
    }

    return setmetatable({["__widget__"] = widget}, mt)
end

-- 绑定点击事件
function Cls:bindClick(widget, cd, fn, ...)
    if type(widget) == "string" then
        widget = self._FIELDS.ui[widget]
    end

    if not self:isValidWidget(widget) then
        return
    end

    local fn_bind = bind(fn, ...)
    widget:addTouchEventListener(function(sender, state)
        if state == ccui.TouchEventType.ended then
            if type(cd) == "number" and 
               cd > 0               and 
               CommonFunction.checkButtonIsCooling(sender, cd)
            then
                return
            end

            fn_bind(sender, state)
        end
    end)

    return widget
end

-- 设置文字
function Cls:setString(widget, text)
    if type(widget) == "string" then
        widget = self._FIELDS.ui[widget]
    end

    if not self:isValidWidget(widget) then
        return nil
    end

    widget:setString(text)
    return widget
end

-- 加载纹理
function Cls:loadTexture(widget, res, callback, fromPList)
    if type(widget) == "string" then
        widget = self._FIELDS.ui[widget]
    end

    if not self:isValidWidget(widget) then
        return nil
    end

    api_rui:loadTexture(widget, res, callback, fromPList)
    return widget
end

-- 创建EditBox
function Cls:createEditBox(initData)
    initData = initData or {}
    local contentSize = initData.contentSize or cc.size(0, 0)
    local maxLength = initData.maxLength or 100
    local placeholder = initData.placeholder or ""
    local defaultText = initData.defaultText or ""
    local fontSize = initData.fontSize or 20
    local placeholderFontSize = initData.placeholderFontSize or fontSize
    local inputMode = initData.inputMode or cc.EDITBOX_INPUT_MODE_ANY
    local editBoxHandler = initData.editBoxHandler or function() end

    local uiEditBox = cc.EditBox:create(contentSize, cc.Scale9Sprite:create())
    uiEditBox:setTouchEnabled(true)
    uiEditBox:setAnchorPoint(cc.p(0,0))
    uiEditBox:setMaxLength(maxLength)
    uiEditBox:setPlaceholderFontSize(placeholderFontSize)
    uiEditBox:setPlaceHolder(placeholder)
    uiEditBox:setFontSize(fontSize)
    uiEditBox:setText(defaultText)
    uiEditBox:setInputMode(inputMode)
    uiEditBox:setReturnType(cc.KEYBOARD_RETURNTYPE_DONE)
    uiEditBox:registerScriptEditBoxHandler(editBoxHandler)
    return uiEditBox
end

-- 创建 RoundList
function Cls:createRoundList(...)
    local ret = RoundList.new(...)
    table.insert(self._FIELDS.roundLists, ret)
    return ret
end

-- 清理所有 RoundList
function Cls:clearAllRoundList()
    for _, roundList in ipairs(self._FIELDS.roundLists) do
        if roundList and type(roundList.clear) == "function" then
            -- 清理
            roundList:clear()
        end
    end

    -- 清空
    self._FIELDS.roundLists = {}
end

-- 响应式系统 --
-- 创建reactive对象
function Cls:reactive(...)
    local obj = ReactiveSystem.reactive(...)
    table.insert(self._FIELDS.reactives, obj)
    return obj
end

-- 创建ref对象
function Cls:ref(...)
    local obj = ReactiveSystem.ref(...)
    table.insert(self._FIELDS.reactives, obj)
    return obj
end

-- 创建计算属性对象
function Cls:computed(...)
    local obj = ReactiveSystem.computed(...)
    table.insert(self._FIELDS.reactives, obj)
    return obj
end

-- 监听响应式对象
function Cls:watch(effect, widget)
    if not self:isValidWidget(widget) then
        ReactiveSystem.watch(effect)
        return
    end

    local effectWrapper = nil
    effectWrapper = function(...)
        if not self:isValidWidget(widget) then
            ReactiveSystem.clearEffect(effectWrapper)
            return
        end

        effect(...)
    end

    ReactiveSystem.watch(effectWrapper)
end

-- 监听响应式Ref对象
function Cls:watchRef(refObj, callback, widget)
    if not self:isValidWidget(widget) then
        ReactiveSystem.watchRef(refObj, callback)
        return
    end

    ReactiveSystem.watchRef(refObj, function(...)
        if not self:isValidWidget(widget) then
            ReactiveSystem.unwatch(refObj)
            return
        end

        callback(...)
    end)
end

-- 监听计算属性对象
function Cls:watchComputed(computedObj, callback, widget)
    if not self:isValidWidget(widget) then
        ReactiveSystem.watchComputed(computedObj, callback)
        return
    end

    ReactiveSystem.watchComputed(computedObj, function(...)
        if not self:isValidWidget(widget) then
            ReactiveSystem.clearComputed(computedObj)
            return
        end

        callback(...)
    end)
end

-- 清理所有响应式对象
function Cls:clearAllReactives()
    for _, obj in ipairs(self._FIELDS.reactives) do
        if ReactiveSystem.isReactive(obj) then
            ReactiveSystem.unwatch(obj)
        elseif ReactiveSystem.isComputed(obj) then
            ReactiveSystem.clearComputed(obj)
        end
    end

    -- 清空
    self._FIELDS.reactives = {}
end

-- 通用 --
-- 是否合法组件
function Cls:isValidWidget(widget)
    if not widget then
        return false
    end

    if type(widget) ~= "userdata" then
        return false
    end

    if tolua.isnull(widget) then
        return false
    end

    return true
end

-- 查找节点
function Cls:seekWidgetByName(widget, name)
    return ccui.Helper:seekWidgetByName(widget, name)
end

-- 关闭自身
function Cls:closeSelf()
    sendNotification(UI_CLOSE_PANEL, {command = self._FIELDS.ui_name})
end

-- 属性 --
-- 获取根节点
function Cls:getRoot()
    return self._FIELDS.ui_root
end

-- 获取 UI 代理
function Cls:getUI()
    return self._FIELDS.ui
end

-- 导出 UI 对象
function Cls.export(cls)
    return {
        process = function(data)
            local inst = cls.new(data)
        end
    }
end

return Cls