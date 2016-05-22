////////////////////////////////////////////////////////////////////////////////
// Additional Reports and data processors in Service Models subsystem,
//  procedures and functions with the repeated use of return values.
// 
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// The function returns a fixed array containing constant
//  names managing the availability of the additional report and data processor usage in the service model
//
Function ControlConstants() Export
	
	Result = New Array();
	Result.Add("AdditionalReportsAndDataProcessorsIndependentUseSaaS");
	Result.Add("UseAdditionalReportsDirectoryAndDataprocessorsSaaS");
	
	Return New FixedArray(Result);
	
EndFunction

// The function returns an array containing the
//  AdditionalReportsAndDataProcessors catalog attribute names that you can not change if there are connections with the supplied data processors.
//
Function ControlledAttributes() Export
	
	Result = New Array();
	Result.Add("SafeMode");
	Result.Add("DataProcessorStorage");
	Result.Add("ObjectName");
	Result.Add("Version");
	Result.Add("Kind");
	
	Return New FixedArray(Result);
	
EndFunction

// The function returns the matching
//  of ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS enums items to the detailed description of disable reason.
//
Function ExtendedDescriptionsReasonsLock() Export
	
	Reasons = Enums.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS;
	
	Result = New Map();
	Result.Insert(Reasons.BlockAdministratorService, NStr("en = 'Use of the additional data processor is prohibited due to violation of service rules!'"));
	Result.Insert(Reasons.BlockingByOwner, NStr("en = 'The use of the additional processor is prohibited by its owner!'"));
	Result.Insert(Reasons.ConfigurationVersionUpdate, NStr("en = 'The use of the additional data processor is temporarily unavailable due to application update. This may take several minutes. We apologize for the inconvenience.'"));
	
	Return New FixedMap(Result);
	
EndFunction