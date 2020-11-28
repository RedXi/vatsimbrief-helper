local vhfHelperStub = {
	frequencies = {
		tunedInCom1 = nil,
		tunedInCom2 = nil,
		entered = nil
	},
	validator = function(freq)
		if (freq:match("([1][1-3][0-9]%.[0-9][0-9][0-9])") == freq) then
			return true
		end
		return false
	end
}

VHFHelperPublicInterface = {
	getInterfaceVersion = function()
		return 1
	end,
	enterFrequencyProgrammaticallyAsString = function(newFullString)
		if (isValidFrequency(newFullString)) then
			vhfHelperStub.frequencies.entered = newFullString
			return vhfHelperStub.frequencies.entered
		end
		return nil
	end,
	isCurrentlyTunedIn = function(fullFrequencyString)
		if
			(fullFrequencyString == vhfHelperStub.frequencies.tunedInCom1 or
				fullFrequencyString == vhfHelperStub.frequencies.tunedInCom2)
		 then
			return true
		end
		return false
	end,
	isCurrentlyEntered = function(fullFrequencyString)
		if (fullFrequencyString == vhfHelperStub.frequencies.entered) then
			return true
		end
		return false
	end,
	isValidFrequency = function(fullFrequencyString)
		return vhfHelperStub.validator(fullFrequencyString)
	end
}

return vhfHelperStub
