
#Region ProgramInterface

// Function connects a device.
//
// Parameters:
//  DriverObject   - <*>
//           - DriverObject of a trading equipment driver.
//
// Returns:
//  <Boolean> - Result of the function work.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;
	Output_Parameters = New Array();
	ConnectionParameters.Insert("DeviceID", Undefined);

	// Check set parameters.
	Port               = Undefined;
	Timeout            = Undefined;
	TurnsCount = Undefined;
	Parameters.Property("Port"    , Port);
	Parameters.Property("Timeout" , Timeout);
	Parameters.Property("TurnsCount", TurnsCount);
	
	If Port = Undefined
		OR Timeout = Undefined Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set.
		|For the correct work of the device it is necessary to specify the parameters of its work.
		|You can do it using the Parameters setting
		|form of the peripheral model in the Connection and equipment setting form.'"));
		Result = False;
	EndIf;

	ValueArray = New Array;
	ValueArray.Add(Parameters.Port);
	ValueArray.Add(Parameters.Timeout);
	ValueArray.Add(?(Parameters.TurnsCount = Undefined, 1, Parameters.TurnsCount));
	
	If Result Then
		Response = DriverObject.Connect(ValueArray, ConnectionParameters.DeviceID);
		If Not Response Then
			Output_Parameters.Add(999);
			Output_Parameters.Add(DriverObject.ErrorText);
			Result = False;
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function disconnects a device.
//
// Parameters:
//  DriverObject - <*>
//         - DriverObject of a trading equipment driver.
//
// Returns:
//  <Boolean> - Result of the function work.
//
Function DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;

	Output_Parameters = New Array();

	DriverObject.Disable(ConnectionParameters.DeviceID);

	Return Result;

EndFunction

// The function receives, processes and redirects for execution a command to the driver.
//
Function RunCommand(Command, InputParameters = Undefined, Output_Parameters = Undefined,
                         DriverObject, Parameters, ConnectionParameters) Export

	Result = True;

	Output_Parameters = New Array();

	// Output of lines on a display
	If Command = "OutputLineToCustomerDisplay" OR Command = "DisplayText" Then
		TextString = InputParameters[0];
		Result = OutputLineToCustomerDisplay(DriverObject, Parameters, ConnectionParameters, TextString, Output_Parameters);

	// Display clearing
	ElsIf Command = "ClearCustomerDisplay" OR Command = "ClearText" Then
		Result = ClearCustomerDisplay(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Test device
	ElsIf Command = "DeviceTest" OR Command = "CheckHealth" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Get output parameters
	ElsIf Command = "GetOutputParameters" Then
		Result = GetOutputParameters(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Receive driver version
	ElsIf Command = "GetDriverVersion" Then
		Result = GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// This command is not supported by the current driver.
	Else
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='The %Command% command is not supported by the current driver.'"));
		Output_Parameters[1] = StrReplace(Output_Parameters[1], "%Command%", Command);
		Result = False;

	EndIf;

	Return Result;

EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Function displays string list on customer display.
//
Function OutputLineToCustomerDisplay(DriverObject, Parameters, ConnectionParameters, TextString, Output_Parameters)

	Result = True;

	RowArray = New Array();
	RowArray.Add(StrGetLine(TextString, Parameters.ShowOnDisplay));

	Response = DriverObject.OutputLineToCustomerDisplay(ConnectionParameters.DeviceID, RowArray);
	If Not Response Then
		Result = False;
		DriverObject.GetError(DriverObject.ErrorDescription);
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ErrorDescription);
	EndIf;

	Return Result;
	
EndFunction

// Function clears the customer display.
//
Function ClearCustomerDisplay(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Response = DriverObject.ClearCustomerDisplay(ConnectionParameters.DeviceID);
	If Not Response Then
		Result = False;
		DriverObject.GetError(DriverObject.ErrorDescription);
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ErrorDescription);
	EndIf;

	Return Result;

EndFunction

// function returns the parameters of output to the customer display).
Function GetOutputParameters(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;
	Output_Parameters.Clear();  
	Output_Parameters.Add(20);
	Output_Parameters.Add(2);
		
	Return Result;

EndFunction

// Function tests device.
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Result = ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	If Not Result Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='An error occurred while connecting the device'"));
	Else
		TextString = NStr("en='Product description'")+Chars.LF+NStr("en='Amount Total'");
		Result = OutputLineToCustomerDisplay(DriverObject, Parameters, ConnectionParameters, TextString, Output_Parameters);
		EquipmentManagerClient.Pause(5);
		If Result Then
			Output_Parameters.Add(0);
			Output_Parameters.Add(NStr("en='Test completed successfully'"));
		EndIf;
	EndIf;

	DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	Return Result;

EndFunction

// Function returns installed driver version.
//
Function GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Output_Parameters.Add(NStr("en='Installed'"));
	Output_Parameters.Add(NStr("en='Not defined'"));

	Try
		Output_Parameters[1] = DriverObject.GetVersionNumber();
	Except
	EndTry;

	Return Result;

EndFunction

#EndRegion