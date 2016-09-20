
////////////////////////////////////////////////////////////////////////////////
// Subsystem "InternetSupport Monitor"
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Runs an additional check of
// possibility to launch business process for the entry point and interaction context creation parameters.
// Called
// from OnlineUserSupportClientServer.GetLaunchByDirectionAndParametersPossibility()
//
// Parameters:
// LaunchLocation - String - Business process entry point.
// InternetSupportParameters - see function
// 	OnlineUserSupport.ContextCreationParameters();
// ActionsDetails - Structure - in the structure
// 	Description of the action executed is returned if business process launch is prohibited.
// see	OnlineUserSupportClientServer.GetLaunchByDirectionAndParametersPossibility().
//
Procedure DefineLaunchPossibility(LaunchLocation, InternetSupportParameters, ActionsDetails) Export
	
	ThisStartOnApplicationStartup = InternetSupportParameters.OnStart;
	
	If Not InternetSupportParameters.UseMonitor
		AND LaunchLocation = "handStartNew" Then
		
		ActionsDetails.Insert("Action", "ShowMessage");
		ActionsDetails.Insert("Message",
			NStr("en='Use of
		|Online support monitor banned in current mode.';ru='Использование
		|монитора Интернет-поддержки запрещено в текущем режиме работы.'"));
		Return;
		
	EndIf;
	
	If ThisStartOnApplicationStartup AND Not InternetSupportParameters.ShowMonitorOnStart Then
		ActionsDetails.Insert("Action", "Return");
	EndIf;
	
EndProcedure

// Specifies the context of online
// support service commands: Client or server 1C:Enterprise.
// Called from UsersOnlineSupportClientServer.CommandType()
//
// Parameters:
// CommandName - String - name of the executed command;
// ConnectionOnServer - Boolean - True if connection with
// 	UOS service is set on 1C:Enterprise server.
// ExecutionContext - Number - the context of command
// 	execution returns in the parameter: 0 - server of 1C:Enterprise, 1 - client, -1 - unknown command.
//
Procedure CommandExecutionContext(CommandName, ConnectionOnServer, ExecutionContext) Export
	
	If CommandName = "check.updatehash" Then
		ExecutionContext = 0;
	EndIf;
	
EndProcedure

// Called on outline of the Online
// support service command of 1C:Enterprise server side.
// For more information, see the OnlineSupportMonitorClientServer.OutlineServerAnswer() function.
//
Procedure StructureServiceCommand(CommandName, ServiceCommand, CommandStructure) Export
	
	If CommandName = "check.updatehash" Then
		CommandStructure = StructureUpdateHashCheck(ServiceCommand);
		
	ElsIf CommandName = "status.set" Then
		CommandStructure = StructureIPPStatusInstallation(ServiceCommand);
		
	EndIf;
	
EndProcedure

// Called if you need to define form
// parameters by its index of 1C:Enterprise server side.
// Called
// from UsersOnlineSupportClientServer.InternalFormParameters()Parameters:
// FormIndex - String - index of the business process form.
// Parameters - Structure - form parameters. Fields are added to the structure:
// 	* OpenedFormName - String - full name of the form
// 		by its index, additional parameters of opening a form.
//
Procedure FillInternalFormParameters(FormIndex, Parameters) Export
	
	If FormIndex = "100" Then
		Parameters.Insert("OpenableFormName",
			"DataProcessor.OnlineSupportMonitor.Form.Monitor");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Transformation of the "Check the update hash of informational window" into internal presentation.
//
Function StructureUpdateHashCheck(ServerCommand)
	
	If ServerCommand.parameters.parameter.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	CommandStructure = New Structure;
	CommandStructure.Insert("CommandName"   , "check.updatehash");
	CommandStructure.Insert("UpdateHash", ServerCommand.parameters.parameter[0].value);
	
	Return CommandStructure;
	
EndFunction

// Transformation of the command "Set status" into internal presentation.
//
Function StructureIPPStatusInstallation(ServerCommand)
	
	CommandStructure = New Structure;
	
	If ServerCommand.parameters.parameter.Count() = 0 Then 
		Return Undefined;
	EndIf;
	
	For Each Parameter in ServerCommand.parameters.parameter Do
		
		If Lower(TrimAll(Parameter.name)) = "color" Then
			CommandStructure.Insert("Color", TrimAll(Parameter.value));
		EndIf;
		
	EndDo;
	
	CommandStructure.Insert("CommandName", ServerCommand.name);
	
	Return CommandStructure;
	
EndFunction

#EndRegion
