local M = require("lualine.component"):extend()

local default_options = {
    icon = " ",
    spinner = {
        text = {
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
    },
}

function M:init(options)
    M.super.init(self, options)

    self.options = vim.tbl_deep_extend("keep", self.options or {}, default_options)
    self.spinner_text = ""

    -- cache status texts from options (moved into default_options.spinner.text)
    self.status_texts = (self.options and self.options.spinner and self.options.spinner.text) or {}

    local is_finish = {
        CodeCompanionRequestFinished = true,
        CodeCompanionChatDone = true,
    }
    local is_stop = {
        CodeCompanionChatStopped = true,
        CodeCompanionChatCleared = true,
    }
    local is_close = {
        CodeCompanionChatClosed = true,
        CodeCompanionCLIClosed = true,
    }
    local is_open = {
        CodeCompanionChatCreated = true,
        CodeCompanionChatOpened = true,
        CodeCompanionCLICreated = true,
        CodeCompanionCLIOpened = true,
    }

    vim.api.nvim_create_autocmd("User", {
        pattern = "CodeCompanion*",
        callback = function(args)
            -- update adapter name if provided
            local model_name = args.data and (args.data.adapter and args.data.adapter.model or "") or ""
            local event = args.match or ""
            local text = self.status_texts[event]

            if is_stop[event] then
                if model_name ~= "" then
                    self.spinner_text = string.format(
                        "%s(%s)",
                        text or self.status_texts["CodeCompanionChatStopped"] or "Stopped",
                        model_name
                    )
                else
                    self.spinner_text = text or self.status_texts["CodeCompanionChatStopped"] or "Stopped"
                end
                return
            end

            if is_finish[event] then
                if model_name ~= "" then
                    self.spinner_text = string.format(
                        "%s(%s)",
                        text or self.status_texts["CodeCompanionRequestFinished"] or "Done",
                        model_name
                    )
                else
                    self.spinner_text = text or self.status_texts["CodeCompanionRequestFinished"] or "Done"
                end
                return
            end
            if is_close[event] then
                self.is_close = true
                return
            elseif is_open[event] then
                self.is_close = false
            end

            if text then
                if model_name ~= "" then
                    self.spinner_text = string.format("%s(%s)", text, model_name)
                else
                    self.spinner_text = text
                end
            end
        end,
    })
end

function M:update_status()
    if not package.loaded["codecompanion"] then
        return nil
    end
    if self.is_close then
        return nil
    end

    return ("%s"):format(self.spinner_text)
end

return M
