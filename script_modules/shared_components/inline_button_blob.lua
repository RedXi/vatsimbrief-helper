local InlineButtonBlob
do
    InlineButtonBlob = {
        Constants = {
            TextWithoutNewlineCode = 0,
            NewlineCode = 1,
            DefaultButtonCode = 2,
            CustomColorDefaultButtonCode = 3,
            CustomCallbackButtonCode = 4,
            ColorTextWithoutNewlineCode = 5,
            BlockCodeOffset = 0,
            BlockSkipDistanceOffset = 1,
            MinimumBlockSkipDistance = 2
        }
    }

    function InlineButtonBlob:new()
        local newInstanceWithState = {
            blobTable = {},
            defaultButtonCallbackFunction = nil,
            nextImguiButtonId = 15564
        }

        setmetatable(newInstanceWithState, self)
        self.__index = self
        return newInstanceWithState
    end

    function InlineButtonBlob:_addDefaultBlockHeader(blockCode, additionalSkipDistance)
        table.insert(self.blobTable, blockCode)
        local skipDistance = InlineButtonBlob.Constants.MinimumBlockSkipDistance + additionalSkipDistance
        table.insert(self.blobTable, skipDistance)
    end

    function InlineButtonBlob:_addBasicButtonSubHeader(buttonTitleAsString)
        table.insert(self.blobTable, buttonTitleAsString)

        -- Having two buttons with the same text does not work well in ImGUI
        table.insert(self.blobTable, buttonTitleAsString .. "##" .. tostring(self.nextImguiButtonId))
        self.nextImguiButtonId = self.nextImguiButtonId + 1
    end

    function InlineButtonBlob:setDefaultButtonCallbackFunction(value)
        self.defaultButtonCallbackFunction = value
    end

    function InlineButtonBlob:addTextWithoutNewline(textAsString)
        self:_addDefaultBlockHeader(InlineButtonBlob.Constants.TextWithoutNewlineCode, 1)
        table.insert(self.blobTable, textAsString or "<NIL text>")
    end

    function InlineButtonBlob:addColorTextWithoutNewline(textAsString, textColor)
        self:_addDefaultBlockHeader(InlineButtonBlob.Constants.ColorTextWithoutNewlineCode, 2)
        table.insert(self.blobTable, textAsString or "<NIL text>")
        table.insert(self.blobTable, textColor or "<NIL color>")
    end

    function InlineButtonBlob:addNewline()
        self:_addDefaultBlockHeader(InlineButtonBlob.Constants.NewlineCode, 0)
    end

    function InlineButtonBlob:addDefaultButton(buttonTitleAsString)
        self:_addDefaultBlockHeader(InlineButtonBlob.Constants.DefaultButtonCode, 2)

        self:_addBasicButtonSubHeader(buttonTitleAsString or "<NIL button title>")
    end

    function InlineButtonBlob:addCustomCallbackButton(buttonTitleAsString, onPressCallbackFunction)
        self:_addDefaultBlockHeader(InlineButtonBlob.Constants.CustomCallbackButtonCode, 3)

        self:_addBasicButtonSubHeader(buttonTitleAsString or "<NIL button title>")
        table.insert(self.blobTable, onPressCallbackFunction)
    end

    function InlineButtonBlob:addCustomColorDefaultButton(buttonTitleAsString, textColor, backgroundColor)
        self:_addDefaultBlockHeader(InlineButtonBlob.Constants.CustomColorDefaultButtonCode, 4)

        self:_addBasicButtonSubHeader(buttonTitleAsString)
        table.insert(self.blobTable, textColor or "<NIL color>")
        table.insert(self.blobTable, backgroundColor or "<NIL color>")
    end

    function InlineButtonBlob:renderToCanvas()
        -- ImGUI unfortunately adds newlines after widgets _by default_
        local lastItemTriggeredANewline = true

        imgui.PushStyleVar_2(imgui.constant.StyleVar.ItemSpacing, 0.0, 0.0)
        imgui.PushStyleVar_2(imgui.constant.StyleVar.FramePadding, 0.0, 0.0)

        local index = 1
        while index < #self.blobTable do
            local nextCode = self.blobTable[index + InlineButtonBlob.Constants.BlockCodeOffset]

            if (nextCode == InlineButtonBlob.Constants.NewlineCode) then
                lastItemTriggeredANewline = true
            else
                if (not lastItemTriggeredANewline) then
                    imgui.SameLine()
                end

                lastItemTriggeredANewline = false
            end

            if (nextCode == InlineButtonBlob.Constants.TextWithoutNewlineCode) then
                imgui.TextUnformatted(self.blobTable[index + 2])
            elseif (nextCode == InlineButtonBlob.Constants.ColorTextWithoutNewlineCode) then
                imgui.PushStyleColor(imgui.constant.Col.Text, self.blobTable[index + 3])
                imgui.TextUnformatted(self.blobTable[index + 2])
                imgui.PopStyleColor()
            elseif (nextCode == InlineButtonBlob.Constants.CustomCallbackButtonCode) then
                if (imgui.SmallButton(self.blobTable[index + 3])) then
                    self.blobTable[index + 4](self.blobTable[index + 2])
                end
            elseif (nextCode == InlineButtonBlob.Constants.DefaultButtonCode) then
                if (imgui.SmallButton(self.blobTable[index + 3])) then
                    self.defaultButtonCallbackFunction(self.blobTable[index + 2])
                end
            elseif (nextCode == InlineButtonBlob.Constants.CustomColorDefaultButtonCode) then
                imgui.PushStyleColor(imgui.constant.Col.Text, self.blobTable[index + 4])
                imgui.PushStyleColor(imgui.constant.Col.Button, self.blobTable[index + 5])

                if (imgui.SmallButton(self.blobTable[index + 3])) then
                    self.defaultButtonCallbackFunction(self.blobTable[index + 2])
                end

                imgui.PopStyleColor()
                imgui.PopStyleColor()
            end

            local skipDistance = self.blobTable[index + InlineButtonBlob.Constants.BlockSkipDistanceOffset]
            if (skipDistance <= 0) then
                imgui.TextUnformatted("")
                imgui.TextUnformatted("!BLOB corrupted, invalid skip distance!")
                break
            end

            index = index + skipDistance
        end

        imgui.PopStyleVar()
        imgui.PopStyleVar()
    end
end

return InlineButtonBlob
