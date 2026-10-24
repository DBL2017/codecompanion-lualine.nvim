local M = require("lualine.component"):extend()

local DEFAULT_OPTIONS = {
    icon = " ",
    event_text = {
        -- ACP
        CodeCompanionACPConnected = "ACP: Connected",
        CodeCompanionACPSessionPost = "ACP: Session started",
        CodeCompanionChatACPModeChanged = "Chat: ACP mode changed",
        CodeCompanionACPChatRestored = "ACP: Chat restored",

        -- Chat
        CodeCompanionChatCreated = "Chat: Created",
        CodeCompanionChatOpened = "Chat: Opened",
        CodeCompanionChatClosed = "Chat: Closed",
        CodeCompanionChatHidden = "Chat: Hidden",
        CodeCompanionChatSubmitted = "Chat: Submitted",
        CodeCompanionChatDone = "Response received",
        CodeCompanionChatCompacting = "Compressing",
        CodeCompanionChatStopped = "Stopped",
        CodeCompanionChatCleared = "Cleared",
        CodeCompanionChatRestored = "Chat: Restored",
        CodeCompanionChatAdapter = "Adapter set",
        CodeCompanionChatModel = "Model set",

        -- CLI
        CodeCompanionCLICreated = "CLI: Created",
        CodeCompanionCLIOpened = "CLI: Opened",
        CodeCompanionCLIClosed = "CLI: Closed",
        CodeCompanionCLIHidden = "CLI: Hidden",
        CodeCompanionCLISent = "CLI: Sent",

        -- Tools / files / inline
        CodeCompanionContextChanged = "Context changed",
        CodeCompanionFileEdited = "File edited",
        CodeCompanionInlineStarted = "Inline: Started",
        CodeCompanionInlineFinished = "Inline: Finished",

        -- MCP
        CodeCompanionMCPServerStart = "MCP: Starting",
        CodeCompanionMCPServerReady = "MCP: Ready",
        CodeCompanionMCPServerClosed = "MCP: Closed",
        CodeCompanionMCPServerToolsLoaded = "MCP: Tools loaded",

        -- Requests
        CodeCompanionRequestStarted = "Thinking",
        CodeCompanionRequestStreaming = "Receiving",
        CodeCompanionRequestFinished = "Done",

        -- Tool system
        CodeCompanionToolAdded = "Tool added",
        CodeCompanionToolApprovalRequested = "Tool approval requested",
        CodeCompanionToolApprovalFinished = "Tool approval finished",
        CodeCompanionToolStarted = "Tool running",
        CodeCompanionToolFinished = "Tool finished",
        CodeCompanionToolsStarted = "Tools running",
        CodeCompanionToolsFinished = "Tools finished",
        CodeCompanionToolsJudgeStarted = "Tools judge started",
        CodeCompanionToolsJudgeFinished = "Tools judge finished",
    },
}

local function format_duration(seconds)
    if not seconds then
        return ""
    end

    local mins = math.floor(seconds / 60)
    local secs = seconds % 60

    if mins > 0 then
        return string.format("[%dm%02ds]", mins, secs)
    end

    return string.format("[%ds]", secs)
end

local function calculate_elapsed(start_time)
    return math.floor((vim.loop.now() - start_time) / 1000)
end

function M:init(options)
    M.super.init(self, options)

    self.requests = {}
    self._last_update = 0
    self._cached_status = nil

    local function handle_request_start(req, data, text)
        req.id = data and data.id
        req.status = "running"
        req.status_text = text or ""
    end

    local function handle_round_start(req)
        if req.round_start_time then
            return
        end

        req.round_start_time = vim.loop.now()
        req.round_elapsed = nil
    end

    local function handle_round_finish(req, status)
        if req.round_start_time then
            req.round_elapsed = calculate_elapsed(req.round_start_time)
            req.round_start_time = nil
        end
        req.status = status
    end

    -- 模型变更事件公共函数
    local function handle_model_change(req, data, model_field)
        local model = data and data[model_field] or ""
        req.model_name = (type(model) == "table" and model.name) or model or "default"
    end

    -- 事件处理映射表（switch-case 模式）
    local event_handlers = {
        -- 模型变更事件
        CodeCompanionChatAdapter = function(req, data)
            handle_model_change(req, data, "adapter")
        end,
        CodeCompanionChatModel = function(req, data)
            handle_model_change(req, data, "model")
        end,

        -- 请求启动事件
        CodeCompanionRequestStarted = handle_request_start,
        CodeCompanionChatSubmitted = handle_round_start,

        -- 请求完成事件
        CodeCompanionChatDone = function(req)
            handle_round_finish(req, "finished")
        end,

        -- 停止/清除事件
        CodeCompanionChatStopped = function(req)
            handle_round_finish(req, "stopped")
        end,
        CodeCompanionChatCleared = function(req)
            handle_round_finish(req, "stopped")
        end,
    }

    vim.api.nvim_create_autocmd("User", {
        pattern = "CodeCompanion*",
        callback = function(args)
            local event = args.match or ""
            local text = DEFAULT_OPTIONS.event_text[event]
            local bufnr = args.data and args.data.bufnr
            if not bufnr then
                return
            end

            -- 创建或获取请求对象
            local req = self.requests[bufnr]
            if not req then
                req = {
                    bufnr = bufnr,
                }
                self.requests[bufnr] = req
            end

            -- 更新状态文本（所有事件通用）
            if text then
                req.status_text = text
            end

            -- 查找并执行事件处理函数
            local handler = event_handlers[event]
            if handler then
                handler(req, args.data, text)
            end
            -- 清除缓存
            self._cached_status = nil
        end,
    })
end

function M:update_status()
    if not package.loaded["codecompanion"] then
        return nil
    end

    local bufnr = vim.api.nvim_get_current_buf()
    if vim.bo[bufnr].filetype ~= "codecompanion" then
        return nil
    end

    -- 当启用codecompanion-history auto_generate_title时这里会失效
    -- local name = vim.api.nvim_buf_get_name(bufnr)
    -- if not name:match("CodeCompanion") then
    --     return nil
    -- end

    local req = self.requests[bufnr]
    if not req then
        return nil
    end

    -- 缓存优化：每100ms更新一次
    local now = vim.loop.now()
    if self._cached_status and (now - self._last_update) < 100 then
        return self._cached_status
    end

    self._last_update = now

    local round_duration
    if req.round_start_time then
        round_duration = format_duration(calculate_elapsed(req.round_start_time))
    elseif req.round_elapsed then
        round_duration = format_duration(req.round_elapsed)
    end

    local duration = round_duration or ""

    local icon = DEFAULT_OPTIONS.icon or ""
    local model_name = req.model_name or "default"
    local status_text = req.status_text or ""
    if duration ~= "" then
        self._cached_status = string.format("%s %s(%s) %s", icon, status_text, model_name, duration)
    else
        self._cached_status = string.format("%s %s(%s)", icon, status_text, model_name)
    end

    return self._cached_status
end
return M
