OperatorUtils = OperatorUtils or {}

-- 遍历字典
function OperatorUtils.foreach(tbl, func)
    for k, v in pairs(tbl) do
        if func(k, v) then
            break
        end
    end
end

-- 遍历数组
function OperatorUtils.foreach_i(tbl, func)
    for _, v in ipairs(tbl) do
        if func(v) then
            break
        end
    end
end

-- foreach_range
function OperatorUtils.foreach_range(start, stop, step, func)
    for i = start, stop, step or 1 do
        if func(i) then
            break
        end
    end
end

-- 是否是空表
function OperatorUtils.is_empty(tbl)
    return not next(tbl)
end

-- 是否是数组
function OperatorUtils.is_array(tbl)
    if type(tbl) ~= "table" then
        return false
    end

    local i = 0
    for _ in pairs(tbl) do
        i = i + 1
        if tbl[i] == nil then
            return false
        end
    end

    return true
end

-- 是否是字典
function OperatorUtils.is_dict(tbl)
    return type(tbl) == "table" and not OperatorUtils.is_array(tbl)
end

-- do_func
function OperatorUtils.do_func(func, ...)
    if func then
        return func(...)
    end
end

-- 生成范围
function OperatorUtils.range(start, stop, step)
	local result = {}
	for i = start, stop, step or 1 do
		table.insert(result, i)
	end

	return result
end

-- 计数
function OperatorUtils.count(tbl, pred)
	local count = 0
    OperatorUtils.foreach(tbl, function(k, v)
        if not pred then
            count = count + 1
            return        
        end

        if pred(k, v) then
            count = count + 1
        end
    end)

	return count
end

-- 映射
function OperatorUtils.map(tbl, func)
    local result = {}

    for k, v in pairs(tbl) do
        local key, value = func(k, v)
        if key and value then
            result[key] = value
        end
    end

    return result
end

-- 转成数组
function OperatorUtils.to_list(tbl, func)
    local result = {}

    for k, v in pairs(tbl) do
        local value = v
        if func then
            value = func(k, v)
        end

        if value then
            table.insert(result, value)
        end
    end

    return result
end

-- 获取键
function OperatorUtils.keys(tbl)
    return OperatorUtils.to_list(tbl, function(k) return k end)
end

-- 过滤字典
function OperatorUtils.filter(tbl, pred)
    local result = {}

    for k, v in pairs(tbl) do
        if pred(k, v) then
            result[k] = v
        end
    end

    return result
end

-- 过滤数组
function OperatorUtils.filter_i(tbl, pred)
    local result = {}

    for _, v in ipairs(tbl) do
        if pred(v) then
            table.insert(result, v)
        end
    end

    return result
end

-- 折叠
function OperatorUtils.fold(tbl, func, initial)
    local result = initial

    for _, v in ipairs(tbl) do
        result = func(result, v)
    end

    return result
end

-- 求和
function OperatorUtils.sum(tbl, func)
    local list = OperatorUtils.to_list(tbl, function(k, v) return v end)
    return OperatorUtils.fold(list, function(a, b) return a + func(b) end, 0)
end

-- 随机
function OperatorUtils.random(tbl, func)
	local totalWeight = OperatorUtils.sum(tbl, func)
	local accWeight = 0
	local randomNumber = math.random(1, totalWeight)

	return OperatorUtils.find_i(tbl, function(v)
		accWeight = accWeight + func(v)
		return accWeight >= randomNumber
	end)
end

-- shuffle
function OperatorUtils.shuffle(tbl)
    local result = clone(tbl)
    for i = #result, 2, -1 do
        local j = math.random(1, i)
        result[i], result[j] = result[j], result[i]
    end

    return result
end

-- 扁平化
function OperatorUtils.flatten(tbl, shallow)
    local recursive = nil
    local result = {}

    recursive = function(t)
        if not t then return end

        if type(t) ~= "table" then
            table.insert(result, t)
            return
        end

        if OperatorUtils.is_empty(t) then
            return
        end

        if not OperatorUtils.is_array(t) then
            table.insert(result, t)
            return
        end

        for i, v in ipairs(t) do
            if shallow then
                table.insert(result, v)
            else
                recursive(v)
            end
        end
    end

    recursive(tbl)
    return result
end

-- 分类
function OperatorUtils.classify(tbl, func)
    local result = {}

    for k, v in pairs(tbl) do
        local key = func(k, v)
        if not result[key] then
            result[key] = {}
        end
        table.insert(result[key], v)
    end

    return result
end

-- 查找(在字典中查找)
function OperatorUtils.find(tbl, pred)
    for k, v in pairs(tbl) do
        if pred(k, v) then
            return k, v
        end
    end
end

-- 查找(在数组中查找)
function OperatorUtils.find_i(tbl, pred)
    for _, v in ipairs(tbl) do
        if pred(v) then
            return v
        end
    end
end

-- 删除(在字典中删除)
function OperatorUtils.remove(tbl, pred)
    for k, v in pairs(tbl) do
        if pred(k, v) then
            tbl[k] = nil
        end
    end
end

-- 删除(在数组中删除)
function OperatorUtils.remove_i(tbl, pred)
    for i = #tbl, 1, -1 do
        if pred(tbl[i]) then
            table.remove(tbl, i)
        end
    end
end

-- 任意(遍历字典)
function OperatorUtils.any(tbl, pred)
    return OperatorUtils.find(tbl, pred) ~= nil
end

-- 任意(遍历数组)
function OperatorUtils.any_i(tbl, pred)
    return OperatorUtils.find_i(tbl, pred) ~= nil
end

-- 全部(遍历字典)
function OperatorUtils.all(tbl, pred)
    for k, v in pairs(tbl) do
        if not pred(k, v) then
            return false
        end
    end

    return true
end

-- 全部(遍历数组)
function OperatorUtils.all_i(tbl, pred)
    return OperatorUtils.fold(tbl, function(a, b) return a and pred(b) end, true)
end

-- 展开
function OperatorUtils.unpack(tbl, i)
    i = i or 1
    if tbl[i] then
        return tbl[i], OperatorUtils.unpack(tbl, i + 1)
    end
end

-- 连接
function OperatorUtils.concat(tbl, ...)
    local result = {}
    for _, v in ipairs(tbl) do
        table.insert(result, v)
    end

    for _, v in ipairs({...}) do
        for _, vv in ipairs(v) do
            table.insert(result, vv)
        end
    end

    return result
end

-- 事件总线
local listeners = {}
function OperatorUtils.event_bus()
    return {
        -- 注册事件
        on = function(event, listener)
            if not listeners[event] then
                listeners[event] = {}
            end
            table.insert(listeners[event], listener)
        end,

        -- 触发事件
        emit = function(event, ...)
            local list = listeners[event]
            if not list then
                return
            end

            for i = #list, 1, -1 do
                list[i](...)
            end
        end,

        -- 移除事件
        off = function(event, listener)
            local list = listeners[event]
            if not list then
                return
            end

            if not listener then
                listeners[event] = nil
                return
            end

            OperatorUtils.remove_i(list, function(v) return v == listener end)
        end
    }
end

-- 绑定 （柯里化）
function OperatorUtils.bind(func, ...)
    local args = {...}
    return function(...)
        return func(OperatorUtils.unpack(OperatorUtils.concat(args, {...})))
    end
end

-- 缓存
function OperatorUtils.memoize(func, cache)
    cache = cache or {}
    return function(...)
        local key = table.concat({...}, ",")
        if not cache[key] then
            cache[key] = func(...)
        end

        return cache[key]
    end
end

-- 节流
function OperatorUtils.throttle(func, wait)
    local last = 0
    return function(...)
        local now = os.time()
        if now - last >= wait then
            func(...)
            last = now
        end
    end
end

-- 防抖
function OperatorUtils.debounce(func, wait)
    local Scheduler = cc.Director:getInstance():getScheduler()
    local timer = nil

    return function(...)
        if timer then
            Scheduler:unscheduleScriptEntry(timer)
        end

        local args = {...}
        timer = Scheduler:scheduleScriptFunc(function()
            func(OperatorUtils.unpack(args))
            Scheduler:unscheduleScriptEntry(timer)
            timer = nil
        end, wait, false)
    end
end