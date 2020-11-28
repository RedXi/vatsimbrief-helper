local IssueTracker
do
    IssueTracker = {}

    function IssueTracker:new()
        local newInstanceWithState = {components = {}}
        setmetatable(newInstanceWithState, self)
        self.__index = self

        return newInstanceWithState
    end

    function IssueTracker:declareLinkedKnownIssue(newComponent, newDescription, newWorkaround, blameStringList)
        local newKnownIssue = self:_post(newComponent, newDescription, newWorkaround)
        newKnownIssue.isLinked = true
        newKnownIssue.blameStringList = blameStringList
        newKnownIssue.blamedComponents = {}
    end

    function IssueTracker:trackIssue(newComponent, newDescription, newWorkaround)
        self:_post(newComponent, newDescription, newWorkaround)
    end

    function IssueTracker:printSummary()
        self:_TRACK_INTERNAL_ISSUE(
            "Lua",
            "Lua does not support continue statements",
            "Use deeply nested ifs or labels in a future Lua update/Lua version instead."
        )
        self:_TRACK_INTERNAL_ISSUE("Lua", "Lua does not support labels", "Stick to ifs until next Lua update")
        self:_TRACK_INTERNAL_ISSUE(
            "IssueTracker",
            "The longest description is not necessarily the best one.",
            "Let's see how people use IssueTracker for now."
        )

        self:_relinkAllLinkedIssues()
        self:_printIssues(false)
        self:_printKnownIssues()
    end

    function IssueTracker:printAllIssues()
        self:_printIssues(true)
    end

    function IssueTracker:_post(newComponent, newDescription, newWorkaround)
        local newOccurrenceLocation = self:_getOccurrenceLocation(5)

        local existingIssue =
            self:_findIssueAndMakeItEasierToFindTheSameIssueAgain(newComponent, newDescription, newWorkaround)
        if (existingIssue ~= nil) then
            self:_addOccurrence(existingIssue, newOccurrenceLocation, newWorkaround)
            return existingIssue
        end

        self.components[newComponent] = self.components[newComponent] or {issues = {}}
        local component = self.components[newComponent]

        component.issues[newDescription] =
            component.issues[newDescription] or
            {descriptions = {}, isLinked = false, occurrences = {}, numOccurrences = 0}
        local newIssue = component.issues[newDescription]
        newIssue.descriptions[newDescription] = newIssue.descriptions[newDescription] or {}
        self:_addOccurrence(newIssue, newOccurrenceLocation, newWorkaround)
        return newIssue
    end

    function IssueTracker:_relinkAllLinkedIssues()
        for componentName, component in pairs(self.components) do
            for issueDescription, issue in pairs(component.issues) do
                if (issue.isLinked) then
                    self:_relinkKnownLinkedIssue(issue)
                end
            end
        end
    end

    function IssueTracker:_relinkKnownLinkedIssue(issueToRelink)
        assert(issueToRelink.isLinked)
        issueToRelink.numRelatedTo = 0
        for componentName, component in pairs(self.components) do
            for issueDescription, issue in pairs(component.issues) do
                if (not issue.isLinked) then
                    for key, blameString in pairs(issueToRelink.blameStringList) do
                        if (issueDescription:find(blameString) ~= nil) then
                            issueToRelink.numRelatedTo = issueToRelink.numRelatedTo + 1
                            issueToRelink.blamedComponents[componentName] =
                                issueToRelink.blamedComponents[componentName] or {}
                        end
                    end
                end
            end
        end

        local num = 0
        for _, _ in pairs(issueToRelink.blamedComponents) do
            num = num + 1
        end

        local atLeastOneWorkaround = nil
        local atLeastOneOccurrence = nil
        for occurrenceLocation, occurrence in pairs(issueToRelink.occurrences) do
            atLeastOneOccurrence = occurrence
            if (occurrence.workaround ~= nil) then
                atLeastOneWorkaround = occurrence.workaround
                break
            end
        end

        local knownIssueString = nil
        if (num == 0 and atLeastOneWorkaround == nil) then
            local newOccurrenceLocation = self:_getOccurrenceLocation(4)
            knownIssueString =
                ("[91mCannot blame anything in %s. Also, no workaround available.[0m A new or non-issue?"):format(
                newOccurrenceLocation
            )
        else
            if (atLeastOneWorkaround == nil) then
                knownIssueString = "None for now."
            else
                knownIssueString = atLeastOneWorkaround
            end

            if (num > 0) then
                knownIssueString = knownIssueString .. " Known issue in "
                for blamedComponentName, _ in pairs(issueToRelink.blamedComponents) do
                    knownIssueString = knownIssueString .. blamedComponentName .. "/"
                end
                knownIssueString = knownIssueString:sub(1, -2)
            else
                knownIssueString = knownIssueString .. " [91mWill be fixed in future releases.[0m"
            end
        end

        atLeastOneOccurrence.workaround = knownIssueString
    end

    function IssueTracker:_TRACK_INTERNAL_ISSUE(newComponent, newDescription, newWorkaround)
        self:trackIssue(newComponent, newDescription, newWorkaround)
    end

    function IssueTracker:_printKnownIssues()
        local headerToPrint = "[96m[4mIssue Tracker: All linked known issues:[0m"
        for componentName, component in pairs(self.components) do
            local componentToPrint = ("\n[4m%s[0m:"):format(componentName)

            for issueDescription, issue in pairs(component.issues) do
                if (issue.isLinked) then
                    if (headerToPrint ~= nil) then
                        self:_log(headerToPrint)
                        headerToPrint = nil
                    end
                    if (componentToPrint ~= nil) then
                        self:_log(componentToPrint)
                        componentToPrint = nil
                    end

                    for occurrenceLocation, occurrence in pairs(issue.occurrences) do
                        self:_log(
                            ("[94m%s[0m:%s"):format(occurrenceLocation, self:_prefixAllLines(issueDescription, " "))
                        )
                        assert(occurrence.workaround)
                        self:_log(("  Workaround:%s"):format(self:_prefixAllLines(occurrence.workaround, " ")))

                        local issuesPlural = "issues"
                        if (issue.numRelatedTo == 1) then
                            issuesPlural = "issue"
                        end
                        self:_log(("  Related to %d %s.\n"):format(issue.numRelatedTo, issuesPlural))
                    end
                end
            end
        end
    end

    function IssueTracker:_findBestDecriptionForIssue(issueDescription, issue)
        local longestDescription = issueDescription
        local longestDescriptionLength = longestDescription:len()
        for desc, _ in pairs(issue.descriptions) do
            local descLen = desc:len()
            if (descLen > longestDescriptionLength) then
                longestDescription = desc
                longestDescriptionLength = desc:len()
            end
        end

        return longestDescription
    end

    function IssueTracker:_prefixAllLines(linesString, prefix)
        return prefix .. linesString:gsub("\n", "\n" .. prefix)
    end

    function IssueTracker:_printIssues(printAll)
        if (printAll) then
            self:_log(
                "\n" .. "[96m[4mIssue Tracker: All manually highlighted issues in code that ran during tests:[0m"
            )
        else
            self:_log(
                "\n" ..
                    "[96m[4mIssue Tracker: All manually highlighted issues in code that ran during tests without a workaround:[0m"
            )
        end
        local num = 0
        local numUnique = 0
        local numWorkedAround = 0
        for componentName, component in pairs(self.components) do
            local componentToPrint = ("\n[4m%s[0m:"):format(componentName)
            for issueDescription, issue in pairs(component.issues) do
                local issueToPrint =
                    ("[96m(%dx)[0m%s"):format(
                    issue.numOccurrences,
                    self:_prefixAllLines(self:_findBestDecriptionForIssue(issueDescription, issue), " ")
                )

                if (not issue.isLinked) then
                    numUnique = numUnique + 1
                    num = num + issue.numOccurrences
                    local notWorkedAroundCompletely = self:_wasNotWorkedAroundCompletely(issue)

                    if (notWorkedAroundCompletely or printAll) then
                        for occurrenceLocation, occurrence in pairs(issue.occurrences) do
                            if (componentToPrint ~= nil) then
                                self:_log(componentToPrint)
                                componentToPrint = nil
                            end
                            if (issueToPrint ~= nil) then
                                self:_log(issueToPrint)
                                issueToPrint = nil
                            end

                            if (occurrence.workaround == nil) then
                                self:_log((" [94m%s[0m: [93mNo Workaround[0m"):format(occurrenceLocation))
                            else
                                self:_log(
                                    (" [94m%s[0m: Workaround:%s"):format(
                                        occurrenceLocation,
                                        self:_prefixAllLines(occurrence.workaround, " ")
                                    )
                                )
                            end
                        end
                    else
                        numWorkedAround = numWorkedAround + 1
                    end
                end
            end
        end
        if (num == 0) then
            self:_log(
                ('\nFound %d total issues. That means everything is fine or nobody cares. Use TRACK_ISSUE("Blamed Topic", "Description") to leave hints in code.\n'):format(
                    num,
                    numUnique,
                    numWorkedAround
                )
            )
        else
            self:_log(
                ("\nFound %d unique (%d total collected) issues in code that ran during tests, [93m%d without a workaround[0m."):format(
                    numUnique,
                    num,
                    numUnique - numWorkedAround
                )
            )
            if (not printAll) then
                self:_log("If you like to see all issues, run the task 'triggerAllIssues'\n")
            end
        end
    end

    function IssueTracker:_findIssueAndMakeItEasierToFindTheSameIssueAgain(component, description, workaround)
        assert(component)
        assert(description)
        local existingComponent = self.components[component]
        if (existingComponent == nil) then
            return nil
        end

        for issueDescription, issue in pairs(existingComponent.issues) do
            for desc, _ in pairs(issue.descriptions) do
                if (desc:lower():find(description:lower()) ~= nil or description:lower():find(desc:lower())) then
                    issue.descriptions[description] = issue.descriptions[description] or {}
                    return issue
                end
            end
        end

        return nil
    end

    function IssueTracker:_getOccurrenceLocation(level)
        local stackLevelAboveTrackIssue = level
        local debugInfo = debug.getinfo(stackLevelAboveTrackIssue)
        local newOccurrenceLocation = debugInfo.source:sub(2, -1) .. ":" .. debugInfo.currentline
        return newOccurrenceLocation
    end

    function IssueTracker:_addOccurrence(issue, location, workaround)
        issue.numOccurrences = issue.numOccurrences + 1
        issue.occurrences[location] = issue.occurrences[location] or {workaround = nil}
        local newOcurrence = issue.occurrences[location]
        if (workaround ~= nil) then
            newOcurrence.workaround = workaround
        end
        return newOcurrence
    end

    function IssueTracker:_wasNotWorkedAroundCompletely(issue)
        local notWorkedAroundCompletely = false
        for occurrenceLocation, occurrence in pairs(issue.occurrences) do
            if (occurrence.workaround == nil) then
                notWorkedAroundCompletely = true
            end
        end

        return notWorkedAroundCompletely
    end

    function IssueTracker:_log(string)
        print(string)
    end
end

local issueTracker = IssueTracker:new()

TRACK_ISSUE = function(component, description, workaround)
    issueTracker:trackIssue(component, description, workaround)
end

KNOWN_ISSUE = function(newComponent, newDescription, newWorkaround, blameStringList)
    issueTracker:declareLinkedKnownIssue(newComponent, newDescription, newWorkaround, blameStringList)
end

TRIGGER_ISSUE_AFTER_TIME =
    TRIGGER_ISSUE_AFTER_TIME or
    function(trackingSince, triggerAfterHowLong)
        if (trackingSince == nil) then
            print(
                ("[93mNow is: %d (copy this number into your TRACK_ISSUE/TRIGGER_ISSUE_AFTER_TIME(now, triggerAfterSecondsFromNow) call)[0m"):format(
                    os.time()
                )
            )
            assert(nil)
        end

        assert(triggerAfterHowLong)
        if (os.time() - trackingSince > triggerAfterHowLong) then
            return nil
        end

        return ("This is not yet an issue. It is tracked since %s and will trigger on %s. Take your time!"):format(
            os.date("%x %X", trackingSince),
            os.date("%x %X", trackingSince + triggerAfterHowLong)
        )
    end

MULTILINE_TEXT = function(...)
    local completeString = ""
    for _, argument in ipairs(arg) do
        completeString = completeString .. argument .. "\n"
    end

    completeString = completeString:sub(1, -2)

    return completeString
end

return issueTracker
