
#Region ProgramInterface

// Function connects a device.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;

	// Required output
	If TypeOf(Output_Parameters) <> Type("Array") Then
		Output_Parameters = New Array();
	EndIf;

	// Check set parameters.
	Port              = Undefined;
	Speed             = Undefined;
	DataBit           = Undefined;
	StopBit           = Undefined;
	Parity            = Undefined;
	Sensitivity       = Undefined;
	Prefix            = Undefined;
	Suffix            = Undefined;
	Model             = Undefined;

	Parameters.Property("Port"            , Port);
	Parameters.Property("Speed"           , Speed);
	Parameters.Property("DataBit"         , DataBit);
	Parameters.Property("StopBit"         , StopBit);
	Parameters.Property("Parity"          , Parity);
	Parameters.Property("Sensitivity"     , Sensitivity);
	Parameters.Property("Prefix"          , Prefix);
	Parameters.Property("Suffix"          , Suffix);
	Parameters.Property("Model"           , Model);

	If Port              = Undefined
	 Or Speed            = Undefined
	 Or DataBit          = Undefined
	 Or StopBit          = Undefined
	 Or Parity           = Undefined
	 Or Sensitivity      = Undefined
	 Or Prefix           = Undefined
	 Or Suffix           = Undefined
	 Or Model            = Undefined Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set.
		|For the correct work of the device it is necessary to specify the parameters of its work.
		|You can do it using the Parameters setting
		|form of the peripheral model in the Connection and equipment setting form.';ru='Не настроены параметры устройства.
		|Для корректной работы устройства необходимо задать параметры его работы.
		|Сделать это можно при помощи формы
		|""Настройка параметров"" модели подключаемого оборудования в форме ""Подключение и настройка оборудования"".'"));

		Result = False;
	EndIf;
	// End: Check set parameters.

	If Result Then
		Output_Parameters.Add("BarCodeScaner");
		Output_Parameters.Add(New Array());
		Output_Parameters[1].Add("BarCodeValue");

		PrefixDriver = "";
		SuffixOfDriver = "";

		DriverObject.AddDevice();
		If DriverObject.Result = 0 Then
			ConnectionParameters.Insert("DeviceID", DriverObject.CurrentDeviceNumber);
			DriverObject.CurrentDeviceDescription = Parameters.Model;

			DriverObject.NumberPort       = Parameters.Port;
			DriverObject.ExchangeSpeed    = Parameters.Speed;
			DriverObject.Parity           = Parameters.Parity;
			DriverObject.DataBits         = Parameters.DataBit;
			DriverObject.StopBits         = Parameters.StopBit;
			DriverObject.Sensitivity      = Parameters.Sensitivity;
			DriverObject.Model            = 0;
			DriverObject.OldVersion       = 0;

			PrefixDriver = Parameters.Prefix;
			SuffixOfDriver = Parameters.Suffix;

			TechPrefix = StrReplace(PrefixDriver, "#", Chars.LF);
			CharCount = StrLineCount(TechPrefix);
			PrefixDriver = "";
			For CurIndex = 2 To CharCount Do
				PrefixDriver = PrefixDriver + Char(Number(StrGetLine(TechPrefix, CurIndex)));
			EndDo;

			CurSuffix = StrReplace(SuffixOfDriver, "#", Chars.LF);
			CharCount = StrLineCount(CurSuffix);
			SuffixOfDriver = "";
			For CurIndex = 2 To CharCount Do
				SuffixOfDriver = SuffixOfDriver + Char(Number(StrGetLine(CurSuffix, CurIndex)));
			EndDo;

			DriverObject.Prefix = PrefixDriver;
			DriverObject.Suffix = SuffixOfDriver;
		Else
			Result = False;
			DriverObject.ErrorDescription = DriverObject.ResultDescription;
		EndIf;

		If Result Then
			DriverObject.DeviceIsOn = 1;
			If DriverObject.Result <> 0 Then
				Result = False;

				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);

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

	// Required output
	If TypeOf(Output_Parameters) <> Type("Array") Then
		Output_Parameters = New Array();
	EndIf;

	// Processing the event from device.
	If Command = "ProcessEvent" Then
		Event = InputParameters[0];
		Data  = InputParameters[1];

		Result = ProcessEvent(DriverObject, Parameters, ConnectionParameters, Event, Data, Output_Parameters);

	// End of the device event handling.
	ElsIf Command = "FinishProcessingEvents" Then
		Result = FinishProcessingEvents(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

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
	BC = "";
	
	Try
		DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;
		DriverObject.DataSend  = 0;
		DriverObject.MessageNo = Number(Data);
		BC = TrimAll(DriverObject.Data);
	Except
		DriverObject.ErrorDescription = DriverObject.ResultDescription;
		Result = False;
	EndTry;
	
	Output_Parameters.Add("ScanData");
	Output_Parameters.Add(New Array());
	Output_Parameters[1].Add(BC);
	Output_Parameters[1].Add(New Array);
	Output_Parameters[1][1].Add(BC);
	Output_Parameters[1][1].Add(BC);
	Output_Parameters[1][1].Add(0);

	Return Result;

EndFunction

// Procedure is called when the system is ready to accept the following event from the device.
//
Function FinishProcessingEvents(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Try
		DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;
		DriverObject.DataSend = 1;
	Except
		DriverObject.ErrorDescription = DriverObject.ResultDescription;
		Result = False;
	EndTry;

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

#EndRegion