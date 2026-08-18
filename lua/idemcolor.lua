local namespace = vim.api.nvim_create_namespace("idemcolor")

local hl_group_of_identifier = {}
local attached_buffers = {}

local string_to_int = function(str)
    if str == nil then
        return 0
    end
    local int = 0
    for i = 1, #str do
        local c = str:sub(i, i)
        int = int + string.byte(c)
    end
    return int
end

local M = {}

M.colors = {
    dark = { "#619e9d", "#9E6162", "#81A35C", "#7E5CA3", "#9E9261", "#616D9E", "#97687B", "#689784", "#999C63", "#66639C" },
    bright = {"#f5c0c0", "#f5d3c0", "#f5eac0", "#dff5c0", "#c0f5c8", "#c0f5f1", "#c0dbf5", "#ccc0f5", "#f2c0f5", "#d8e4bc" },
    medium = { "#c99d9d", "#c9a99d", "#c9b79d", "#c9c39d", "#bdc99d", "#a9c99d", "#9dc9b6", "#9dc2c9", "#9da9c9", "#b29dc9" }
}

M.queries = {
    default = "(identifier) @idemcolor",
    javascript = [[
          (identifier) @idemcolor
          (property_identifier) @idemcolor
          (shorthand_property_identifier_pattern) @idemcolor
          (shorthand_property_identifier) @idemcolor
        ]]
}
M.queries.typescript = M.queries.javascript

M.config = {
    enable = true,
    colors = M.colors.medium,
    queries = M.queries,
}

---@param lang string
---@return boolean
local function is_supported(lang)
    local queries = M.config.queries
    local ok = pcall(vim.treesitter.query.parse, lang, queries[lang] or queries["default"])
    return ok
end

---@param bufnr number
---@return string|nil
local function get_buf_lang(bufnr)
    local ft = vim.bo[bufnr].filetype
    if ft == "" then
        return nil
    end
    local lang = vim.treesitter.language.get_lang(ft)
    return lang or ft
end

---@param bufnr number
---@param lang string
local function attach(bufnr, lang)
    if attached_buffers[bufnr] then
        return
    end

    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
    if not ok or not parser then
        return
    end

    local query = vim.treesitter.query.get(lang, 'idemcolor')
    if query == nil then
        local query_string = M.config.queries[lang] or M.config.queries["default"]
        local parse_ok, parsed_query = pcall(vim.treesitter.query.parse, lang, query_string)
        if not parse_ok or not parsed_query then
            return
        end
        query = parsed_query
    end

    attached_buffers[bufnr] = true

    local highlight_tree = function(root_tree, cap_start, cap_end)
        if not vim.api.nvim_buf_is_loaded(bufnr) then
            return
        end
        vim.api.nvim_buf_clear_namespace(bufnr, namespace, cap_start, cap_end)

        for id, node in query:iter_captures(root_tree, bufnr, cap_start, cap_end) do
            local name = query.captures[id]
            if name == "idemcolor" then
                local text = vim.treesitter.get_node_text(node, bufnr)
                if text ~= nil then
                    if hl_group_of_identifier[text] == nil then
                        local colors_count = 0
                        if not M.config.colors then
                            while vim.fn.hlexists('idemcolor' .. colors_count + 1) == 1 do
                                colors_count = colors_count + 1
                            end
                        else
                            colors_count = #M.config.colors
                        end
                        if colors_count == 0 then
                            return
                        end
                        local idx = (string_to_int(text) % colors_count) + 1
                        local group_name = "idemcolor" .. idx
                        if M.config.colors then
                            vim.api.nvim_set_hl(0, group_name, { default = true, fg = M.config.colors[idx] })
                        end
                        hl_group_of_identifier[text] = group_name
                    end
                    local start_row, start_col, end_row, end_col = node:range()
                    if start_row < 0 or end_row < start_row then
                        goto continue
                    end

                    local start_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, true)[1]
                    local end_line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, true)[1]
                    if start_line == nil or end_line == nil then
                        goto continue
                    end

                    start_col = math.max(0, math.min(start_col, #start_line))
                    end_col = math.max(0, math.min(end_col, #end_line))
                    if (end_row == start_row and end_col <= start_col) or (end_row < start_row) then
                        goto continue
                    end

                    pcall(vim.api.nvim_buf_set_extmark, bufnr, namespace, start_row, start_col, {
                        end_row = end_row,
                        end_col = end_col,
                        hl_group = hl_group_of_identifier[text],
                        priority = 101,
                    })
                end
            end
            ::continue::
        end
    end

    local trees = parser:parse()
    if trees and trees[1] then
        highlight_tree(trees[1]:root(), 0, -1)
    end

    parser:register_cbs({
        on_changedtree = function(changes, tree)
            if not tree then
                return
            end
            if not vim.api.nvim_buf_is_loaded(bufnr) then
                return
            end
            local root = tree:root()
            -- During buffer reload/detach, Neovim fires on_changedtree with the
            -- pre-reload (stale) tree (LanguageTree:invalidate(true)): its ranges
            -- refer to the old text, so re-placing extmarks from it would offset
            -- every highlight. Whole-buffer trees whose size no longer matches
            -- the buffer are stale; skip and let on_detach re-attach to the
            -- fresh parser.
            local ok_start, _, _, start_byte = pcall(root.start, root)
            local ok_end, _, _, end_byte = pcall(root.end_, root)
            if
                ok_start
                and ok_end
                and start_byte == 0
                and end_byte
                    ~= vim.api.nvim_buf_get_offset(bufnr, vim.api.nvim_buf_line_count(bufnr))
            then
                return
            end
            highlight_tree(root, 0, -1)
        end,
        on_detach = function()
            -- Buffer reload detaches the parser and its callbacks; a fresh
            -- parser is created on the next get_parser(). Drop the attachment
            -- flag and re-attach so extmarks keep tracking the new parser.
            attached_buffers[bufnr] = nil
            vim.schedule(function()
                if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
                    attach(bufnr, lang)
                end
            end)
        end,
    })
end

---@param bufnr number
local function detach(bufnr)
    if not attached_buffers[bufnr] then
        return
    end
    attached_buffers[bufnr] = nil
    if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    end
end

---@param opts table|nil
function M.setup(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)

    if not M.config.enable then
        return
    end

    local augroup = vim.api.nvim_create_augroup("idemcolor", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        callback = function(args)
            local bufnr = args.buf
            local lang = get_buf_lang(bufnr)
            if lang and is_supported(lang) then
                vim.schedule(function()
                    if vim.api.nvim_buf_is_valid(bufnr) then
                        attach(bufnr, lang)
                    end
                end)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
        group = augroup,
        callback = function(args)
            detach(args.buf)
        end,
    })

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            local lang = get_buf_lang(bufnr)
            if lang and is_supported(lang) then
                attach(bufnr, lang)
            end
        end
    end
end

function M.init()
    local ok, ts = pcall(require, "nvim-treesitter")
    if ok and ts.define_modules then
        local module_def = {
            module_path = "idemcolor",
            attach = function(bufnr, lang)
                attach(bufnr, lang)
            end,
            detach = function(bufnr)
                detach(bufnr)
            end,
            is_supported = function(lang)
                return is_supported(lang)
            end,
            colors = M.colors.medium,
            queries = M.queries
        }

        ts.define_modules {
            idemcolor = module_def,
        }
    else
        M.setup()
    end
end

return M
