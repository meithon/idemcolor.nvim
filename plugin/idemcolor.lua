local function uses_legacy_nvim_treesitter_module()
    local ok, configs = pcall(require, "nvim-treesitter.configs")
    if ok and configs.get_module then
        local module = configs.get_module("idemcolor")
        if module and module.enable then
            return true
        end
    end
    return false
end

if uses_legacy_nvim_treesitter_module() then
    require("idemcolor").init()
end
