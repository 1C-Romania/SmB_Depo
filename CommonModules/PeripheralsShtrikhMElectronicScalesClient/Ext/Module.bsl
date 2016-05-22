
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

	ConnectionParameters.Insert("DeviceID", "");

	Output_Parameters = New Array();

	// Check set parameters.
	Port         = Undefined;
	Speed        = Undefined;
	Parity       = Undefined;
	ScalesType   = Undefined;
	Description  = Undefined;

	Parameters.Property("Port"        , Port);
	Parameters.Property("Speed"       , Speed);
	Parameters.Property("Parity"      , Parity);
	Parameters.Property("ScalesType"  , ScalesType);
	Parameters.Property("Description" , Description);

	If Port         = Undefined
	 Or Speed       = Undefined
	 Or Parity      = Undefined
	 Or ScalesType  = Undefined
	 Or Description = Undefined Then
	 	Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set.
		|For the correct work of the device it is necessary to specify the parameters of its work.
		|You can do it using the Parameters setting
		|form of the peripheral model in the Connection and equipment setting form.'"));

		Result = False;
	EndIf;

	If Result Then
		DriverObject.AddDevice();
		If DriverObject.Result = 0 Then
			ConnectionParameters.DeviceID = DriverObject.CurrentDeviceNumber;

			DriverObject.CurrentDeviceDescription = Parameters.Description;
			
			DriverObject.Model	        = Number(Parameters.ScalesType);
			DriverObject.NumberPort     = Parameters.Port;
			DriverObject.ExchangeSpeed  = Parameters.Speed;
			DriverObject.Parity         = Parameters.Parity;
				
			DriverObject.DeviceIsOn = True;
			If DriverObject.Result <> 0 Then
				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);

				DriverObject.DeleteDevice();
				ConnectionParameters.DeviceID = Undefined;
				Result = False;
			EndIf;
		Else
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(DriverObject.ResultDescription);

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

	DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;
	DriverObject.DeviceIsOn = 0;
	DriverObject.DeleteDevice();

	ConnectionParameters.DeviceID = Undefined;

	Return Result;

EndFunction

// The function receives, processes and redirects for execution a command to the driver.
//
Function RunCommand(Command, InputParameters = Undefined, Output_Parameters = Undefined,
                         DriverObject, Parameters, ConnectionParameters) Export

	Result = True;

	Output_Parameters = New Array();

	// Taring 
	If Command = "Tare" OR Command = "Calibrate" Then
		TareWeight = ?(TypeOf(InputParameters) = Type("Array")
		            AND InputParameters.Count() > 0,
		            InputParameters[0],
		            Undefined);
		
		Result = Tare(DriverObject, Parameters, ConnectionParameters, Output_Parameters, TareWeight);

	// Getting weight
	ElsIf Command = "GetWeight" OR Command = "GetWeight" Then
		Result = GetWeight(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Getting weight
	ElsIf Command = "SetZero" OR Command = "SetZero" Then
		Result = SetZero(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Test device
	ElsIf Command = "CheckHealth" OR Command = "DeviceTest" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Receive driver version
	ElsIf Command = "GetDriverVersion" Then
		Result = GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// This command is not supported by the current driver.
	Else
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='The %Command% command is not supported by the current driver.'"));
		Output_Parameters[1] = StrReplace(Output_Parameters[1], "%Command%", Command);
		Result = False;

	EndIf;

	Return Result;

EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// The function weighs a tare on the scales.
//
Function Tare(DriverObject, Parameters, ConnectionParameters, Output_Parameters, TareWeight = Undefined)

	Result = True;

	DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;

	If TareWeight = Undefined Then
		DriverObject.Tara();
	Else
		DriverObject.TareWeight = TareWeight;
		DriverObject.SetTare();
	EndIf;

	If DriverObject.Result <> 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);

		Result = False;
	EndIf;

	Return Result;

EndFunction

// The function receives weight of the load placed on the scales.
//
Function GetWeight(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;

	DriverObject.GetWeight();
	If DriverObject.Result = 0 Then
		Output_Parameters.Add(DriverObject.Weight);
	Else
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);

		Result = False;
	EndIf;

	Return Result;

EndFunction

// Function sets the zero on the scale.
//
Function SetZero(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;

	DriverObject.Zero();
	If DriverObject.Result <> 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);

		Result = False;
	EndIf;

	Return Result;

EndFunction

// Function tests device.
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;
	
	OutputParametersTemp = Undefined;
	
	Result = ConnectDevice(DriverObject, Parameters, ConnectionParameters, OutputParametersTemp);

	DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;

	DriverObject.GetWeight();
	
	Result = DriverObject.Result = 0;
		
	Output_Parameters.Clear();
	Output_Parameters.Add(?(Result, 0, 999));
    Output_Parameters.Add(?(Result, 
		NStr("en='Current weight'") + DriverObject.Weight,
		NStr("en='An error occurred while connecting the device'")));
	
	DisableDevice(DriverObject, Parameters, ConnectionParameters, OutputParametersTemp);

	Return Result;

EndFunction

// Function returns installed driver version.
//
Function GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Output_Parameters.Add(NStr("en='Installed'"));
	Output_Parameters.Add(NStr("en='Not defined'"));

	Try
		Output_Parameters[1] = DriverObject.Version;
	Except
	EndTry;

	Return Result;

EndFunction

#EndRegion