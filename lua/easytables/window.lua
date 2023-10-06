local table_builder = require("easytables.tablebuilder")
local math = require("math")

local M = {}

DEFAULT_OPTIONS = {
    title = "Table",
    prompt_title = "Content",
    width = 60,
    height = 30,
    min_value_width = 3,
}

function M:create(options)
    options = options or {}

    self.title = options.title or DEFAULT_OPTIONS.title
    self.prompt_title = options.prompt_title or DEFAULT_OPTIONS.prompt_title
    self.width = options.width or DEFAULT_OPTIONS.width
    self.height = options.height or DEFAULT_OPTIONS.height
    self.min_value_width = options.min_value_width or DEFAULT_OPTIONS.min_value_width

    return self
end

function M:get_x()
    return math.floor((vim.o.columns - self.width) / 2)
end

function M:get_y()
    return math.floor(((vim.o.lines - self.height) / 2) - 1)
end

function M:_open_preview_window()
    self.preview_buffer = vim.api.nvim_create_buf(false, true)
    self.preview_window = vim.api.nvim_open_win(self.preview_buffer, true, {
        relative = "win",
        col = self:get_x(),
        row = self:get_y(),
        width = self.width,
        height = self.height,
        style = "minimal",
        border = "rounded",
        title = self.title,
        title_pos = "center",
    })

    vim.api.nvim_set_option_value("readonly", true, { win = self.preview_window })
    -- Disable default highlight
    vim.api.nvim_set_option_value("winhighlight", "Normal:Normal",
        { win = self.preview_window })
end

function M:_open_prompt_window()
    self.prompt_buffer = vim.api.nvim_create_buf(false, false)
    self.prompt_window = vim.api.nvim_open_win(self.prompt_buffer, true, {
        relative = "win",
        col = self:get_x() - 1,
        row = self:get_y() + self.height + 2,
        width = self.width,
        height = 2,
        style = "minimal",
        border = "rounded",
        title = self.prompt_title,
        title_pos = "center",
    })

    vim.api.nvim_set_option_value('winhighlight', "Normal:Normal", { win = self.prompt_window })
end

function M:show()
    -- Don't open window again if it's already opened
    if self.preview_window then
        return
    end

    self:_open_preview_window()
    self:_open_prompt_window()
end

function M:_reset_prompt()
    vim.api.nvim_buf_set_lines(self.prompt_buffer, 0, -1, false, { "" })
end

function M:_draw_highlight(table)
    local cell = table:get_highlighted_cell()

    if cell == nil then
        return
    end

    local row = 1 + math.max(0, cell.row - 1) * 2
    local widths = table:get_widths_for_columns(self.min_value_width)
    local cell_start, cell_end = table:get_cell_positions(cell.col, cell.row, widths)
    local border_start, border_end = table:get_horizontal_border_width(cell.col, cell.row, self.min_value_width)

    vim.api.nvim_buf_set_extmark(
        self.preview_buffer,
        vim.api.nvim_create_namespace("easytables"),
        row - 1,
        border_start,
        {
            end_col = border_end,
            hl_group = "NormalFloat",
            hl_mode = "combine",
        }
    )
    vim.api.nvim_buf_set_extmark(
        self.preview_buffer,
        vim.api.nvim_create_namespace("easytables"),
        row + 1,
        border_start,
        {
            end_col = border_end,
            hl_group = "NormalFloat",
            hl_mode = "combine",
        }
    )
    vim.api.nvim_buf_set_extmark(
        self.preview_buffer,
        vim.api.nvim_create_namespace("easytables"),
        row,
        cell_start,
        {
            end_col = cell_end,
            hl_group = "NormalFloat",
            hl_mode = "combine",
        }
    )
end

function M:draw_table(table)
    local representation = table_builder.draw_representation(table)

    vim.api.nvim_buf_set_lines(self.preview_buffer, 0, -1, false, representation)

    self:_draw_highlight(table)
end

function M:register_listeners(table)
    vim.api.nvim_buf_attach(self.prompt_buffer, false, {
        on_lines = function(_, handle)
            local lines = vim.api.nvim_buf_get_lines(handle, 0, -1, false)

            vim.schedule(function()
                local selected_cell = table:get_highlighted_cell()

                table:insert(selected_cell.col, selected_cell.row, lines[1])
                self:draw_table(table)
            end)
        end,
    })

    vim.api.nvim_buf_create_user_command(
        self.prompt_buffer,
        "JumpToNextCell",
        function()
            table:move_highlight_to_next_cell()
            self:draw_table(table)
            self:_reset_prompt()
        end,
        {}
    )

    vim.api.nvim_buf_create_user_command(
        self.prompt_buffer,
        "JumpToPreviousCell",
        function()
            table:move_highlight_to_previous_cell()
            self:draw_table(table)
            self:_reset_prompt()
        end,
        {}
    )

    vim.api.nvim_buf_create_user_command(
        self.prompt_buffer,
        "JumpDown",
        function()
            table:move_highlight_down()
            self:draw_table(table)
            self:_reset_prompt()
        end,
        {}
    )

    vim.api.nvim_buf_create_user_command(
        self.prompt_buffer,
        "JumpUp",
        function()
            table:move_highlight_up()
            self:draw_table(table)
            self:_reset_prompt()
        end,
        {}
    )

    vim.api.nvim_buf_create_user_command(
        self.prompt_buffer,
        "JumpLeft",
        function()
            table:move_highlight_left()
            self:draw_table(table)
            self:_reset_prompt()
        end,
        {}
    )

    vim.api.nvim_buf_create_user_command(
        self.prompt_buffer,
        "JumpRight",
        function()
            table:move_highlight_right()
            self:draw_table(table)
            self:_reset_prompt()
        end,
        {}
    )
end

return M
