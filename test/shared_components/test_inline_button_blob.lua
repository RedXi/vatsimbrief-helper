imguiStub = require("imgui_stub")
InlineButtonBlob = require("shared_components.inline_button_blob")

TestInlineButtonBlob = {}

function TestInlineButtonBlob:testRendersAllWidgetsInOrderWithProperNewlines()
    local someText = "Here it is"
    local someOtherText = "And here too"
    local buttonTitle = "Press this"
    local buttonTitle2 = "Press!"
    local seriousText = "Saw Log Without Paws"
    local thatText = "that's it"
    local customText = "custom"

    local blob = InlineButtonBlob:new()
    blob:addTextWithoutNewline(someText)
    blob:addNewline()
    blob:addNewline()
    blob:addTextWithoutNewline(someOtherText)
    blob:addColorTextWithoutNewline(thatText)
    blob:addNewline()
    blob:addDefaultButton(buttonTitle)
    blob:addTextWithoutNewline(seriousText)
    blob:addCustomCallbackButton(
        customText,
        function()
        end
    )
    blob:addDefaultButton(buttonTitle2)

    imguiStub:startFrame()
    blob:renderToCanvas()
    imguiStub:endFrame()

    local i = 0
    local sameLineTooEarlyIndex = 0

    sameLineTooEarlyIndex = imguiStub:findCommandInList(i + 1, imguiStub.Constants.SameLine)

    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, someText)
    luaUnit.assertIsTrue(sameLineTooEarlyIndex > i)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, someOtherText)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, thatText)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SmallButton, buttonTitle)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.TextUnformatted, seriousText)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SmallButton, customText)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SameLine)
    i = imguiStub:findNextMatch(i + 1, imguiStub.Constants.SmallButton, buttonTitle2)
end

function TestInlineButtonBlob:testDefaultCallbackIsCalled()
    local blob = InlineButtonBlob:new()

    local called = false
    blob:setDefaultButtonCallbackFunction(
        function(buttonTitle)
            called = true
        end
    )
    local buttonTitle = "bla"
    blob:addDefaultButton(buttonTitle)

    imguiStub:pressButtonProgrammaticallyOnce(buttonTitle)
    imguiStub:startFrame()
    blob:renderToCanvas()
    imguiStub:endFrame()
    luaUnit.assertIsTrue(called)
end

function TestInlineButtonBlob:testCustomCallbackIsCalled()
    local blob = InlineButtonBlob:new()

    local called = false
    local callback = function(buttonTitle)
        called = true
    end

    local buttonTitle = "bla"
    blob:addCustomCallbackButton(buttonTitle, callback)

    imguiStub:pressButtonProgrammaticallyOnce(buttonTitle)
    imguiStub:startFrame()
    blob:renderToCanvas()
    imguiStub:endFrame()
    luaUnit.assertIsTrue(called)
end
