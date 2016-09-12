
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

	Result  = True;

	Output_Parameters = New Array();

	// Check set parameters.
	DataBit  = Undefined;
	Port     = Undefined;
	Speed    = Undefined;
	StopBit  = Undefined;
	Prefix   = Undefined;
	Suffix   = Undefined;

	Parameters.Property("DataBit", DataBit);
	Parameters.Property("Port",      Port);
	Parameters.Property("Speed",  Speed);
	Parameters.Property("StopBit",   StopBit);
	Parameters.Property("Prefix",   Prefix);
	Parameters.Property("Suffix",   Suffix);

	If DataBit  = Undefined
	 OR Port    = Undefined
	 OR Speed   = Undefined
	 OR StopBit = Undefined
	 OR Prefix  = Undefined
	 OR Suffix  = Undefined Then
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
	// End: Check set parameters.

	If Result Then
		Output_Parameters.Add("BarCodeScanner");
		Output_Parameters.Add(New Array());
		Output_Parameters[1].Add("BarcodeReceived");

		Result = (DriverObject.Attach(Output_Parameters[0]) = 0);
		If Not Result Then
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='Error while connecting a device."
"Check port settings.';ru='Ошибка при подключении устройства."
"Проверьте настройки порта.'"));
		EndIf;

		If Result = True Then
			DriverObject.DataBit  = Parameters.DataBit;
			DriverObject.Port     = Parameters.Port;
			DriverObject.Speed    = Parameters.Speed;
			DriverObject.StopBit  = Parameters.StopBit;
			DriverObject.StopChar = Parameters.Suffix;

			DriverObject.EventName = Output_Parameters[1][0];

			Result = (DriverObject.Lock(1) = 0);
			If Result Then
				DriverObject.DeviceIsOn = 1;
				DriverObject.DataSend      = 1;
				DriverObject.ClearEntry();
				DriverObject.ClearExit();

				Result = (DriverObject.DeviceIsOn = 1);
				If Not Result Then
					DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

					Output_Parameters.Clear();
					Output_Parameters.Add(999);
					Output_Parameters.Add(NStr("en='Error while connecting a device."
"Check port settings.';ru='Ошибка при подключении устройства."
"Проверьте настройки порта.'"));
				EndIf;
			Else
				DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(NStr("en='Failed to lock the device."
"Check port settings.';ru='Не удалось занять устройство."
"Проверьте настройки порта.'"));
			EndIf;
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

	DriverObject.DeviceIsOn = 0;
	DriverObject.Release();
	DriverObject.Detach();

	Return Result;

EndFunction

// The function receives, processes and redirects for execution a command to the driver.
//
Function RunCommand(Command, InputParameters = Undefined, Output_Parameters = Undefined,
                         DriverObject, Parameters, ConnectionParameters) Export

	Result = True;

	Output_Parameters = New Array();

	// Processing the event from device.
	If Command = "ProcessEvent" Then
		Event = InputParameters[0];
		Data  = InputParameters[1];

		Result = ProcessEvent(DriverObject, Parameters, ConnectionParameters, Event, Data, Output_Parameters);

	// End of the device event handling.
	ElsIf Command = "FinishProcessingEvents" Then
		ResultDataProcessorsEvents = InputParameters[0];

		Result = FinishProcessingEvents(DriverObject, Parameters, ConnectionParameters,
		                                      ResultDataProcessorsEvents, Output_Parameters);

	// Test device
	ElsIf Command = "CheckHealth" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Setting the parameters of driver logging.
	ElsIf Command = "JournalingParameters" Then
		Result = JournalingParameters(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

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

// Function handles the external events of trade equipment.
//
Function ProcessEvent(DriverObject, Parameters, ConnectionParameters, Event, Data, Output_Parameters)

	Result = True;
	BC        = TrimAll(Data);

	DriverObject.DataSend = 0;

	If Parameters.Prefix <> 0 Then
		If Parameters.Prefix = CharCode(Left(BC, 1)) Then
			BC = Mid(BC, 2);
		EndIf;
	EndIf;

	Output_Parameters.Add("ScanData");
	Output_Parameters.Add(New Array());
	Output_Parameters[1].Add(BC);
	Output_Parameters[1].Add(New Array());
	Output_Parameters[1][1].Add(Data);
	Output_Parameters[1][1].Add(BC);
	Output_Parameters[1][1].Add(0);

	Return Result;

EndFunction

// Procedure is called when the system is ready to accept the following event from the device.
Function FinishProcessingEvents(DriverObject, Parameters, ConnectionParameters,
                                  ResultDataProcessorsEvents, Output_Parameters)

	Result = True;

	DriverObject.DataSend = 1;

	Return Result;

EndFunction

// Open the form of driver parameters check.
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;

	DriverObject.Speed  = Parameters.Speed;
	DriverObject.DataBit = Parameters.DataBit;
	DriverObject.StopBit   = Parameters.StopBit;

	DriverObject.DeviceTest();

	Return Result;

EndFunction

// Open the form of driver logging settings.
Function JournalingParameters(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	DriverObject.Speed  = Parameters.Speed;
	DriverObject.DataBit = Parameters.DataBit;
	DriverObject.StopBit   = Parameters.StopBit;

	DriverObject.JournalingParameters();

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