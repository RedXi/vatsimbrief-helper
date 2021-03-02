--[[

MIT License

Copyright (c) 2020 VerticalLongboard

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]
luaUnit = require("luaUnit")

-- imgui.constant.StyleVar.FrameRounding

imgui = {
    constant = {
        StyleVar = {
            ItemSpacing = "ItemSpacing",
            FrameRounding = "FrameRounding",
            FrameBorderSize = "FrameBorderSize"
        },
        Col = {Text = "Text", Button = "Button", Separator = "Separator"}
    },
    Constants = {
        DrawList_AddImage = "DrawList_AddImage",
        DrawList_AddImageQuad = "DrawList_AddImageQuad",
        Image = "Image",
        Button = "Button",
        SmallButton = "SmallButton",
        TextUnformatted = "TextUnformatted",
        SameLine = "SameLine",
        PushStyleColor = "PushStyleColor",
        PopStyleColor = "PopStyleColor",
        Separator = "Separator",
        InputText = "InputText",
        SliderFloat = "SliderFloat",
        Checkbox = "Checkbox",
        SetCursorPos = "SetCursorPos",
        PushClipRect = "PushClipRect",
        PopClipRect = "PopClipRect",
        DrawList_AddCircle = "DrawList_AddCircle",
        DrawList_AddLine = "DrawList_AddLine",
        DrawList_AddCircleFilled = "DrawList_AddCircleFilled"
    },
    LastFrameCommandList = {},
    DrawList_AddImageQuad = function(
        imageId,
        topLeftX,
        topLeftY,
        topRightX,
        topRightY,
        bottomRightX,
        bottomRightY,
        bottomLeftX,
        bottomLeftY,
        topLeftU,
        topLeftV,
        topRightU,
        topRightV,
        bottomRightU,
        bottomRightV,
        bottomLeftU,
        bottomLeftV,
        color)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.DrawList_AddImageQuad})
    end,
    PushClipRect = function(x, y, width, height)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.PushClipRect})
    end,
    PopClipRect = function()
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.PopClipRect})
    end,
    DrawList_AddCircle = function(centerX, centerY, radius, color, numSegments, thickness)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.DrawList_AddCircle})
    end,
    DrawList_AddCircleFilled = function(centerX, centerY, radius, color, numSegments)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.DrawList_AddCircleFilled})
    end,
    DrawList_AddImage = function(imageId, top, left, right, bottom, uv0x, uv0y, uv1x, uv1y, someColor)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.DrawList_AddImage})
    end,
    DrawList_AddLine = function(p0x, p0y, p1x, p1y, color, thickness)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.DrawList_AddLine})
    end,
    Image = function(imageId, size, uv0x, uv0y, uv1x, uv1y, blaColor, blaColor2, blaColor3, blaColor4)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.Image})
    end,
    SetCursorPos = function(x, y)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.SetCursorPos})
    end,
    Checkbox = function(title, initialValue)
        imgui:checkStringForWatchStrings(title)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.Checkbox, description = title})
    end,
    SliderFloat = function(title, two, three, four, five)
        imgui:checkStringForWatchStrings(title)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.SliderFloat, description = title})
    end,
    InputText = function(title, content, something)
        imgui:checkStringForWatchStrings(title)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.InputText, description = title})
    end,
    SetWindowFontScale = function(value)
    end,
    PushStyleVar = function(value, value2)
        luaUnit.assertNotNil(value)
        luaUnit.assertNotNil(value2)
        imgui.styleVarStackSize = imgui.styleVarStackSize + 1
    end,
    PushStyleVar_2 = function(value, value2, value3)
        luaUnit.assertNotNil(value2)
        luaUnit.assertNotNil(value3)
        imgui.styleVarStackSize = imgui.styleVarStackSize + 1
    end,
    PopStyleVar = function()
        imgui.styleVarStackSize = imgui.styleVarStackSize - 1
    end,
    TextUnformatted = function(value)
        imgui:checkStringForWatchStrings(value)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.TextUnformatted, textString = value})
    end,
    PushStyleColor = function(const, value)
        luaUnit.assertNotNil(value)
        imgui.styleColorStackSize = imgui.styleColorStackSize + 1
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.PushStyleColor, color = value})
    end,
    SameLine = function()
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.SameLine})
    end,
    PopStyleColor = function()
        imgui.styleColorStackSize = imgui.styleColorStackSize - 1
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.PopStyleColor, color = value})
    end,
    Dummy = function(value1, value2)
    end,
    SmallButton = function(value)
        imgui:checkStringForWatchStrings(value)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.SmallButton, title = value})

        if (imgui:matchButtonTitle(value) == imgui.pressButtonWithThisTitleProgrammatically) then
            imgui.buttonPressed = true
            return true
        end

        return false
    end,
    Button = function(value)
        imgui:checkStringForWatchStrings(value)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.Button, title = value})

        if (imgui:matchButtonTitle(value) == imgui.pressButtonWithThisTitleProgrammatically) then
            imgui.buttonPressed = true
            return true
        end

        return false
    end,
    PushID = function(value)
        imgui.idStackSize = imgui.idStackSize + 1
    end,
    PopID = function()
        imgui.idStackSize = imgui.idStackSize - 1
    end,
    Separator = function(value)
        table.insert(imgui.LastFrameCommandList, {type = imgui.Constants.Separator, title = value})
    end
}

function imgui:findNextMatch(startIndex, commandType, textString)
    local i = startIndex - 1
    while true do
        i = self:findCommandInList(i + 1, commandType)
        if (i == nil) then
            return nil
        end

        local cmd = self.LastFrameCommandList[i]

        if (commandType == self.Constants.Button or commandType == self.Constants.SmallButton) then
            if (self:matchButtonTitle(cmd.title) == textString) then
                return i
            end
        elseif (commandType == self.Constants.TextUnformatted) then
            if (cmd.textString == textString) then
                return i
            end
        else
            return i
        end
    end
end

function imgui:matchButtonTitle(title)
    local titleIdIndex = title:find("##")
    if (titleIdIndex == nil) then
        return title
    end

    if (titleIdIndex == 1) then
        return ""
    end

    return title:sub(1, titleIdIndex - 1)
end

function imgui:getCommandFromList(commandIndex)
    return self.LastFrameCommandList[commandIndex]
end

function imgui:findCommandInList(startIndex, commandType)
    for i = startIndex, #self.LastFrameCommandList do
        if (self.LastFrameCommandList[i].type == commandType) then
            return i
        end
    end

    return nil
end

function imgui:debugPrintCommandList()
    logMsg("ImguiStub: All commands captured in last frame:\n" .. "-----------------------------------------------")
    local num = 0
    for _, command in pairs(self.LastFrameCommandList) do
        num = num + 1
        local commandLine = ""
        commandLine = commandLine .. ("%d type=%s "):format(num, command.type)
        if
            (command.type == imgui.Constants.Checkbox or command.type == imgui.Constants.SliderFloat or
                command.type == imgui.Constants.InputText)
         then
            commandLine = commandLine .. ("description=%s"):format(command.description)
        elseif (command.type == imgui.Constants.Button or command.type == imgui.Constants.SmallButton) then
            commandLine = commandLine .. ("title=%s"):format(command.title)
        elseif (command.type == imgui.Constants.TextUnformatted) then
            commandLine = commandLine .. ("textString=%s"):format(command.textString)
        elseif (command.type == imgui.Constants.PushStyleColor) then
            commandLine = commandLine .. ("color=%s"):format(tostring(command.color))
        end
        logMsg(commandLine)
    end
    logMsg(("%d commands captured"):format(num))
end

function imgui:checkStringForWatchStrings(value)
    if (imgui.watchString ~= nil and value:find(imgui.watchString)) then
        imgui.watchStringFound = true
    end

    if (value == imgui.exactMatchString) then
        imgui.exactMatchFound = true
    end
end

function imgui:startFrame()
    self.watchStringFound = false
    self.exactMatchFound = false
    self.buttonPressed = false
    self.styleVarStackSize = 0
    self.styleColorStackSize = 0
    self.idStackSize = 0
    self.LastFrameCommandList = {}
end

function imgui:pressButtonProgrammaticallyOnce(buttonTitle)
    self.pressButtonWithThisTitleProgrammatically = buttonTitle
end

function imgui:keepALookOutForString(someString)
    self.watchString = someString
end

function imgui:keepALookOutForExactMatch(someString)
    self.exactMatchString = someString
end

function imgui:endFrame()
    self.pressButtonWithThisTitleProgrammatically = nil

    luaUnit.assertEquals(self.styleVarStackSize, 0)
    luaUnit.assertEquals(self.styleColorStackSize, 0)
    luaUnit.assertEquals(self.idStackSize, 0)
end

function imgui:wasWatchStringFound()
    return self.watchStringFound
end

function imgui:wasExactMatchFound()
    return self.exactMatchFound
end

function imgui:wasButtonPressed()
    return self.buttonPressed
end

return imgui
