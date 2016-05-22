
////////////////////////////////////////////////////////////////////////////////
// 1C Taxcom Connection subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

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
	
	If CommandName = "setcodesregion" Then
		
		ExecutionContext = ?(ConnectionOnServer, 0, 1);
		
	ElsIf CommandName = "performtheaction.findcertificatefingerprint"
		OR CommandName = "performtheaction.getinformationaboutorganization"
		OR CommandName = "performtheaction.getcertificate" Then
		
		ExecutionContext = 0;
		
	EndIf;
	
EndProcedure

// Called on outline of the Online
// support service command of 1C:Enterprise server side.
// For more
// information, see the OnlineSupportMonitorClientServer.OutlineServerAnswer() function.
//
Procedure StructureServiceCommand(CommandName, ServiceCommand, CommandStructure) Export
	
	If CommandName = "performtheaction" Then
		CommandStructure = StructuredSpecifiedActionPerformCommand(ServiceCommand);
		
	ElsIf CommandName = "setcodesregion" Then
		CommandStructure = OnlineUserSupportClientServer.StructureParametersRecord(
			ServiceCommand);
		
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
	
	If FormIndex = "ftx1" Then
		Parameters.Insert("OpenableFormName",
			"DataProcessor.Connection1CTaxcom.Form.SubscriberUUID");
		
	ElsIf FormIndex = "ftx2" Then
		Parameters.Insert("OpenableFormName",
			"DataProcessor.Connection1CTaxcom.Form.ApplicationForSubscriberRegistration");
		
	ElsIf FormIndex = "ftx3" Then
		Parameters.Insert("OpenableFormName",
			"DataProcessor.Connection1CTaxcom.Form.SubscriberPersonalArea");
		
	ElsIf FormIndex = "ftx4" Then
		Parameters.Insert("OpenableFormName",
			"DataProcessor.Connection1CTaxcom.Form.ChangeTariff");
		
	ElsIf FormIndex = "ftx5" Then
		Parameters.Insert("OpenableFormName",
			"DataProcessor.Connection1CTaxcom.Form.UUIDManualInput");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Transforms the performtheaction command into an internal presentation.
//
Function StructuredSpecifiedActionPerformCommand(ServerCommand)
	
	If ServerCommand.parameters.parameter.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	For Each Parameter IN ServerCommand.parameters.parameter Do
		
		ParameterName = Lower(TrimAll(Parameter.name));
		If ParameterName = "action" Then
			
			Return New Structure("CommandName", "performtheaction." + Lower(TrimAll(Parameter.value)));
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

// Run the Write states codes into the session parameters command.
//
Procedure SaveInStateCodesParameters(COPContext, Val CommandStructure) Export
	
	ParameterArray = CommandStructure.Parameters;
	CodesList      = New ValueList;
	
	For Each Parameter IN ParameterArray Do
		
		// Parameter name
		// is the Value code - it
		// is easier to Select a region name by the region name - thus replacement
		CodesList.Add(
			Parameter.Name,
			Parameter.Name + " - " + Parameter.Value);
		
	EndDo;
	
	OnlineUserSupportClientServer.WriteContextParameter(
		COPContext,
		"codesRegionED",
		CodesList);
	
EndProcedure

#EndRegion

