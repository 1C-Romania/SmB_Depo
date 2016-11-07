
////////////////////////////////////////////////////////////////////////////////
// Subsystem "InternetSupport Monitor"
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Opens the online support monitor.
//
// Parameters:
// LaunchParameters - Structure, Undefined - additional
// 	parameters of opening the online support monitor;
//
Procedure OpenOnlineSupportMonitor(LaunchParameters = Undefined) Export
	
	LaunchLocation = "handStartNew";
	
	// Execution of online support script.
	OnlineUserSupportClient.RunScript(LaunchLocation, LaunchParameters);
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Common use

// Called when the system
// launches from UsersOnlineSupportClient.OnSystemLaunch().
//
Procedure OnStart() Export
	
	OUSParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart().OnlineUserSupport;
	OnlineUserSupportClient.RunScript(
		"systemStartNew",
		,
		,
		OUSParameters.OnlineSupportMonitor);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Business processes handlers

// Called when forming parameters of
// business process form opening sent to the GetForm() method.
// Called from UsersOnlineSupportClient.GenerateFormOpeningParameters()
//
// Parameters:
// COPContext - see the
// 	UsersOnlineSupportServerCall.NewInteractionContext()
// function OpeningFormName - String - full name of opened form;
// Parameters - Structure - filled in form opening parameters
//
Procedure FormOpenParameters(COPContext, OpenableFormName, Parameters) Export
	
	If OpenableFormName = "DataProcessor.OnlineSupportMonitor.Form.Monitor" Then
		Parameters.Insert("HashInformationMonitor", COPContext.HashInformationMonitor);
	EndIf;
	
EndProcedure

#EndRegion