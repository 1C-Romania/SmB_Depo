
#Region ProgramInterface

// Function connects a device.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;

	Output_Parameters = New Array();

	ConnectionParameters.Insert("DeviceID", "");

	// Check set parameters.
	Port              = Undefined;
	Speed             = Undefined;
	Parity            = Undefined;
	DataBits          = Undefined;
	StopBits          = Undefined;
	Encoding          = Undefined;
	ImportFonts         = Undefined;
	Model             = Undefined;
	DisplaySize       = Undefined;

	Parameters.Property("Port",            Port);
	Parameters.Property("Speed",        Speed);
	Parameters.Property("Parity",        Parity);
	Parameters.Property("DataBits",      DataBits);
	Parameters.Property("StopBits",        StopBits);
	Parameters.Property("Encoding",       Encoding);
	Parameters.Property("ImportFonts", ImportFonts);
	Parameters.Property("Model",          Model);
	Parameters.Property("DisplaySize",   DisplaySize);

	If Port            = Undefined
	 Or Speed          = Undefined
	 Or Parity         = Undefined
	 Or DataBits       = Undefined
	 Or StopBits       = Undefined
	 Or Encoding       = Undefined
	 Or ImportFonts      = Undefined
	 Or Model          = Undefined Then
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

	If Result Then
		DriverObject.AddDevice();
		If DriverObject.Result = 0 Then
			ConnectionParameters.DeviceID = DriverObject.CurrentDeviceNumber;

			DriverObject.CurrentDeviceDescription = Parameters.Model;
			DriverObject.Model                    = GetProtocolCode(Parameters.Model);
			DriverObject.DataBits                 = Parameters.DataBits;
			DriverObject.ImportFonts                = Parameters.ImportFonts;
			DriverObject.NumberPort               = Parameters.Port;
			DriverObject.ExchangeSpeed            = Parameters.Speed;
			DriverObject.StopBits                 = Parameters.StopBits;
			DriverObject.Parity                   = Parameters.Parity;
			DriverObject.Charset                  = Parameters.Encoding;

			DriverObject.DeviceIsOn = 1;
			If DriverObject.Result <> 0 Then
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);
				Result = False;
				
				DriverObject.DeleteDevice();
				ConnectionParameters.DeviceID = Undefined;
			Else
				LineCount    = DriverObject.DisplayLinesQty;
				ColumnQuantity = DriverObject.NumberOfDisplayColumns;
				DriverObject.CreateWindow(0, 0, LineCount + 1, ColumnQuantity, LineCount + 1, ColumnQuantity);
			EndIf;
		EndIf;

		If Result Then
			DriverObject.DeviceIsOn = 1;
			If DriverObject.Result <> 0 Then
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);
				Result = False;
				
				DriverObject.DeviceIsOn = 0;
				DriverObject.DeleteDevice();
			EndIf;
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function disconnects a device.
//
Function DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;

	Output_Parameters = New Array();

	DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;
	DriverObject.DeviceIsOn = 0;
	DriverObject.DeleteDevice();

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
		Result = DisplayText(DriverObject, Parameters, ConnectionParameters, TextString, Output_Parameters);

	// Display clearing
	ElsIf Command = "ClearCustomerDisplay" OR Command = "ClearText" Then
		Result = ClearText(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

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
Function DisplayText(DriverObject, Parameters, ConnectionParameters, TextString, Output_Parameters)

	Result = True;

	DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;	
	
	ColumnQuantity = DriverObject.NumberOfDisplayColumns;
	StringOfTextTemp = EquipmentManagerClient.ConstructField(StrGetLine(TextString, 1), ColumnQuantity)
					 + EquipmentManagerClient.ConstructField(StrGetLine(TextString, 2), ColumnQuantity);
	
	Result = (DriverObject.ShowText(StringOfTextTemp, 0) = 0);
	If Not Result Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);
	EndIf;

	Return Result;

EndFunction

// Function clears the customer display.
//
Function ClearText(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;

	DriverObject.Clear();

	Return Result;

EndFunction

// Function returns output parameters on the customer display.
//
Function GetOutputParameters(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;
	Output_Parameters.Clear();
    
	If Parameters.DisplaySize = 0 Then
		Output_Parameters.Add(20);
		Output_Parameters.Add(2);
	ElsIf Parameters.DisplaySize = 0 Then
		Output_Parameters.Add(16);
		Output_Parameters.Add(1);
	Else	
		Output_Parameters.Add(26);
		Output_Parameters.Add(2);	
	EndIf;	
		
	Return Result;

EndFunction

// Function tests device.
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Result = ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	If Not Result Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='An error occurred while connecting the device';ru='Ошибка при подключении устройства'"));
	Else                  
		TextString = NStr("en='Test row 1';ru='Тестовая строка 1'") + Chars.LF + NStr("en='Test row 2';ru='Тестовая строка 2'") + Chars.LF + NStr("en='Test string 3';ru='Тестовая строка 3'");

		DisplayText(DriverObject, Parameters, ConnectionParameters, TextString, Output_Parameters);
		EquipmentManagerClient.Pause(5);

		Output_Parameters.Add(0);
		Output_Parameters.Add(NStr("en='Test completed successfully';ru='Тест успешно выполнен'"));
	EndIf;

	DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	Return Result;

EndFunction

// Function returns installed driver version.
//
Function GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Output_Parameters.Add(NStr("en='Installed';ru='Установлен'"));
	Output_Parameters.Add(NStr("en='Not defined';ru='Не определена'"));

	Try
		Output_Parameters[1] = DriverObject.Version;
	Except
	EndTry;

	Return Result;

EndFunction

// Returns the device's code protocol by model name.
//
Function GetProtocolCode(Model)

	CodeProtocol = 0;

	Protocols = New Map;
	Protocols["Datecs DPD-201"]          = 0;
	Protocols["EPSON-compatible"]        = 1;
	Protocols["Mercury AH-01"]           = 2;
	Protocols["Mercury AH-02"]           = 3;
	Protocols["Mercury AH-03"]           = 4;
	Protocols["Flytech"]                 = 5;
	Protocols["GIGATEK DSP800"]          = 6;
	Protocols["GIGATEK DSP850A"]         = 6;
	Protocols["Stroke-FrontMaster"]      = 7;
	Protocols["EPSON compatible (USA)"]  = 8;
	Protocols["Posiflex PD2300 USB"]     = 9;
	Protocols["IPC"]                     = 10;
	Protocols["GIGATEK DSP820"]          = 11;
	Protocols["TEC LIUST-51"]            = 12;
	Protocols["Demo-display"]            = 255;

	Try
		CodeProtocol = Protocols[Model];
	Except
	EndTry;

	Return CodeProtocol;

EndFunction

#EndRegion