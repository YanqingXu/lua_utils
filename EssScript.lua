--加载文件
function LoadFile(luaPath,data)
    local ui = require(luaPath)
    ui.process(data)
end

--封装自身对象方法
function handler(target, method)
    return function(...)
        if method ~= nil then
            return method(target, ...)
        end
    end
end

if listenMap == nil then
    listenMap = {}
end

--发送内部消息
function sendNotification(eventName,data)
    local event = cc.EventCustom:new(eventName)
    event._userData = data
    cc.Director:getInstance():getEventDispatcher():dispatchEvent(event)
end

--监听事件消息
function registerNotification(eventName,handler)
    if eventName == nil then
       return
    end
    local listenter = cc.EventListenerCustom:create(eventName,handler) 

    local et = listenMap[eventName] or {}
    if et then
        for _, v in pairs(et) do
            if v.name == eventName and v.func == handler then
                return
            end
        end
    end
    table.insert(et,{name = eventName,func = handler,bind = listenter})
    listenMap[eventName] = et
    cc.Director:getInstance():getEventDispatcher():addEventListenerWithFixedPriority(listenter,1)
end

--移除事件
function removeNotification(eventName,handler)
    if eventName == nil or handler == nil then
    	return
    end

    local et = listenMap[eventName] or {}
    for k, v in pairs(et) do
        if v.name == eventName and v.func == handler then 
            local listenter = v.bind
            cc.Director:getInstance():getEventDispatcher():removeEventListener(listenter)
            et[k]  = nil
            break
        end
    end
end

function hasNotification(eventName, handler)
    if eventName == nil or handler == nil then
        return
    end

    local et = listenMap[eventName] or {}
    for _,v in pairs(et) do
         if v.name == eventName and v.func == handler then
            return true
         end
    end

    return false
end

--销毁事件j
function removeAllNotification()
    for _, v in pairs(listenMap) do
        for _, j in pairs(v) do
            cc.Director:getInstance():getEventDispatcher():removeEventListener(j.bind)
        end
    end
end

function removeOneNotification(name)
    for p, v in pairs(listenMap) do
        if p == name then
            for k, j in pairs(v) do
                cc.Director:getInstance():getEventDispatcher():removeEventListener(j.bind)
                v[k] = nil
            end
        end
    end
end

function removeBlackNotification()
    local writeTable = {
        "LoadRemoteSuccessEvent",
        "LoadRemoteFailureEvent",
        "LoadRemoteMapEvent",
    }

    local function checkWrite(eventName)
        for _, v in pairs(writeTable) do
            if v == eventName then
                return true
            end
        end
        return false
    end

    for _,v in pairs(listenMap) do
        for k,j in pairs(v) do
            if false == checkWrite(j.name) then
                cc.Director:getInstance():getEventDispatcher():removeEventListener( j.bind)
                v[k] = nil
            end
        end
    end
end

-- 一键监听  (ui 当前界面的名字  regirstlist 注册监听的列表 removefunc 关闭界面的处理 usefunc ->true的话直接调用removefunc)
function UINotificationHandle(ui, regirstlist, removeFunc, usefunc)
    if not regirstlist then
        regirstlist = {}
    end

    for _,data in pairs(regirstlist) do 
        registerNotification(data[1],data[2])
    end

    local function remove()
        if removeFunc then
            removeFunc()
        end
        if usefunc then
            return
        end
        for _,data in pairs(regirstlist) do 
            removeNotification(data[1],data[2])
        end
        removeNotification(UI_CLOSE_PANEL .. ui, remove)
    end
    registerNotification(UI_CLOSE_PANEL .. ui, remove)
end

function emergencyRemoteLoad(url)
    local md5 = ""..os.time()
    local _urlServer = ""
    local _urlServer = _urlServer .. TINY_PACKAGE_MAP_URL
    _urlServer = _urlServer .. url .. "?v=".. md5
    local  _urlLocal = cc.FileUtils:getInstance():getWritablePath() .. GAME_REMOTE_SAVE_URL
    _urlLocal = _urlLocal .. url
    release_print(_urlServer)
    HttpCacheDataHelper.curlAsyncLoadData(_urlServer , _urlLocal , url)
end