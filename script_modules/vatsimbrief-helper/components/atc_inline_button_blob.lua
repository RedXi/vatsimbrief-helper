local Globals = require("vatsimbrief-helper.globals")

local AtcStringInlineButtonBlob
do
    AtcStringInlineButtonBlob = InlineButtonBlob:new()

    function AtcStringInlineButtonBlob:_getFullFrequencyStringForRadioHelperInterfaceVersion1(
        possiblyShorterFrequencyString)
        return possiblyShorterFrequencyString .. string.rep("0", 7 - string.len(possiblyShorterFrequencyString)) -- Append zeros for format XXX.XXX
    end

    function AtcStringInlineButtonBlob:_mathMinNilIsInfinite(firstNumberOrNil, secondNumber)
        if (firstNumberOrNil ~= nil and firstNumberOrNil < secondNumber) then
            return firstNumberOrNil
        else
            return secondNumber
        end
    end

    -- Override
    function AtcStringInlineButtonBlob:renderToCanvas()
        imgui.PushStyleColor(imgui.constant.Col.ButtonActive, 0xFF000000)
        imgui.PushStyleColor(imgui.constant.Col.ButtonHovered, 0xFF202020)

        InlineButtonBlob.renderToCanvas(self)

        imgui.PopStyleColor()
        imgui.PopStyleColor()
    end

    -- Override
    function AtcStringInlineButtonBlob:addTextWithoutNewline(nextTextSubstring)
        -- Convenience: Do NOT add nil or empty strings to blob
        if (nextTextSubstring == nil or nextTextSubstring == emptyString) then
            return
        end
        InlineButtonBlob.addTextWithoutNewline(self, nextTextSubstring)
    end

    TRACK_ISSUE(
        "Tech Debt",
        "Remove support for old VR Radio Helper interface version right before New Year's.",
        TRIGGER_ISSUE_AFTER_TIME(1606585539, Globals.daysToSeconds(30))
    )

    function AtcStringInlineButtonBlob:build(stations, isRadioHelperPanelActive, maxWidth)
        self:setDefaultButtonCallbackFunction(
            function(buttonText)
                logMsg("Selected frequency in ATC window: " .. buttonText)
                if (VHFHelperPublicInterface.getInterfaceVersion() == 2) then
                    VHFHelperPublicInterface.enterFrequencyProgrammaticallyAsString(buttonText)
                else
                    VHFHelperPublicInterface.enterFrequencyProgrammaticallyAsString(
                        self:_getFullFrequencyStringForRadioHelperInterfaceVersion1(buttonText)
                    )
                end
            end
        )

        TRACK_ISSUE("Lua", "continue statement", "nested ifs")
        TRACK_ISSUE("Lua", "labels", "nested ifs")

        -- Do some calculations for correct alignment of output
        local maxKeyLength = 0
        for i = 1, #stations do
            local airportIcao = stations[i][1]
            if string.len(airportIcao) > maxKeyLength then
                maxKeyLength = string.len(airportIcao)
            end
        end
        local separatorBetweenLocationAndFrequencies = ": "
        maxKeyLength = maxKeyLength + string.len(separatorBetweenLocationAndFrequencies)
        local padding = string.rep(" ", maxKeyLength)
        local maxValueLength = maxWidth - maxKeyLength

        -- Build text only version of stations for the case no Radio Helper is installed
        for i = 1, #stations do
            local stationsEntryOfAirport = stations[i]
            local airportIcao = stationsEntryOfAirport[1]
            local stationsOfAirport = stationsEntryOfAirport[2]

            if i > 1 then -- Otherwise, we're starting on the left already
                self:addNewline()
            end
            local currentLineLength = 0
            local lineHasPayload = false

            self:addTextWithoutNewline(airportIcao .. separatorBetweenLocationAndFrequencies)
            currentLineLength =
                currentLineLength + string.len(airportIcao) + string.len(separatorBetweenLocationAndFrequencies)

            if #stationsOfAirport == 0 then
                self:addTextWithoutNewline("-")
                currentLineLength = currentLineLength + 1
            end
            for j = 1, #stationsOfAirport do
                local stationOfAirport = stationsOfAirport[j]
                local stationOfAirportName = stationOfAirport[1]
                local stationOfAirportFrequency = stationOfAirport[2]

                local entryLength = 0
                if lineHasPayload then
                    entryLength = entryLength + string.len(" ")
                end
                entryLength =
                    entryLength + string.len(stationOfAirportName) + string.len("=") +
                    string.len(stationOfAirportFrequency)

                if currentLineLength + entryLength > maxWidth then
                    self:addNewline()
                    self:addTextWithoutNewline(padding)
                    currentLineLength = string.len(padding)
                    lineHasPayload = false
                end
                currentLineLength = currentLineLength + entryLength

                if lineHasPayload then
                    self:addTextWithoutNewline(" ")
                end
                lineHasPayload = true -- I.e. now we we'll add some. Don't forget to notice that.
                self:addTextWithoutNewline(stationOfAirportName .. "=")
                if isRadioHelperPanelActive then
                    TRACK_ISSUE(
                        "Imgui",
                        "The ImGUI LUA binding in FlyWithLua does not include GetStyle.",
                        "Define screen-picked colors manually."
                    )
                    local colorDefaultImguiBackground = 0xFF121110

                    local colorA320COMOrange = 0xFF00AAFF
                    local colorA320COMGreen = 0xFF00AA00

                    local isValidFrequency = nil
                    if (VHFHelperPublicInterface.getInterfaceVersion() == 2) then
                        isValidFrequency = VHFHelperPublicInterface.isValidFrequency(stationOfAirportFrequency)
                    else
                        isValidFrequency =
                            VHFHelperPublicInterface.isValidFrequency(
                            self:_getFullFrequencyStringForRadioHelperInterfaceVersion1(stationOfAirportFrequency)
                        )
                    end

                    if (isValidFrequency) then
                        if (VHFHelperPublicInterface.isCurrentlyEntered(stationOfAirportFrequency)) then
                            self:addCustomColorDefaultButton(
                                stationOfAirportFrequency,
                                colorA320COMGreen,
                                colorDefaultImguiBackground
                            )
                        elseif (VHFHelperPublicInterface.isCurrentlyTunedIn(stationOfAirportFrequency)) then
                            self:addCustomColorDefaultButton(
                                stationOfAirportFrequency,
                                colorA320COMOrange,
                                colorDefaultImguiBackground
                            )
                        else
                            self:addDefaultButton(stationOfAirportFrequency)
                        end
                    else
                        self:addTextWithoutNewline(stationOfAirportFrequency)
                    end
                else
                    self:addTextWithoutNewline(stationOfAirportFrequency)
                end
            end
        end
    end
end
return AtcStringInlineButtonBlob
