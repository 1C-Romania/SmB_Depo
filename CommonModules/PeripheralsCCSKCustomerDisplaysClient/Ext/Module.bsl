
#Region ProgramInterface

// Function connects a device.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;
	Output_Parameters = New Array();
	ConnectionParameters.Insert("DeviceID", Undefined);

	// Check set parameters.
	Port     = Undefined;
	Speed    = Undefined;
	Parity   = Undefined;
	DataBits = Undefined;
	StopBits = Undefined;
	
	Parameters.Property("Port",         Port);
	Parameters.Property("Speed",        Speed);
	Parameters.Property("Parity",       Parity);
	Parameters.Property("DataBits",     DataBits);
	Parameters.Property("StopBits",     StopBits);         

	If Port              = Undefined Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set."
"For the correct work of the device it is necessary to specify the parameters of its work."
"You can do it using the Parameters setting"
"form of the peripheral model in the Connection and equipment setting form.';ru='Не настроены параметры устройства."
"Для корректной работы устройства необходимо задать параметры его работы."
"Сделать это можно при помощи формы"
"""Настройка параметров"" модели подключаемого оборудования в форме ""Подключение и настройка оборудования"".'"));

		Result = False;
	EndIf;

	ValueArray = New Array;
	ValueArray.Add(Port);
	ValueArray.Add(Speed);
	ValueArray.Add(Parity);
	ValueArray.Add(DataBits);
	ValueArray.Add(StopBits);
	
	If Result Then
		Response = DriverObject.Connect(ValueArray, ConnectionParameters.DeviceID);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.GetError(Output_Parameters[1])
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function disconnects a device.
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
		Output_Parameters.Add(NStr("en='The %Command% command is not supported by the current driver.';ru='Команда ""%Команда%"" не поддерживается данным драйвером.'"));
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
	RowArray.Add(EquipmentManagerClient.ConstructField(StrGetLine(TextString, 1), 20));
	RowArray.Add(EquipmentManagerClient.ConstructField(StrGetLine(TextString, 2), 20));

	Response = DriverObject.OutputLineToCustomerDisplay(ConnectionParameters.DeviceID, RowArray);

	If Not Response Then
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);
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
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);
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
	TestResult = "";
	
	ValueArray = New Array;
	ValueArray.Add(Parameters.Port);
	ValueArray.Add(Parameters.Speed);
	ValueArray.Add(Parameters.Parity);
	ValueArray.Add(Parameters.DataBits);
	ValueArray.Add(Parameters.StopBits);
	                                                   
	Result = DriverObject.DeviceTest(ValueArray, TestResult);
	
	Output_Parameters.Add(?(Result, 0, 999));
	Output_Parameters.Add(TestResult);
	
	Return Result;

EndFunction

// Function returns installed driver version.
//
Function GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Output_Parameters.Add(NStr("en='Installed';ru='Установлен'"));
	Output_Parameters.Add(NStr("en='Not defined';ru='Не определена'"));

	Try
		Output_Parameters[1] = DriverObject.GetVersionNumber();
	Except
	EndTry;

	Return Result;

EndFunction

#EndRegion