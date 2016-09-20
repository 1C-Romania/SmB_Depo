
#Region ProgramInterface

// Function connects a device.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result  = True;

	// Required output
	If TypeOf(Output_Parameters) <> Type("Array") Then
		Output_Parameters = New Array();
	EndIf;

	// Check set parameters.
	Port             = Undefined;
	Speed         = Undefined;
	StopBit          = Undefined;
	DataBit        = Undefined;
	TracksParameters = Undefined;
	Timeout          = Undefined;

	Parameters.Property("Port",             Port);
	Parameters.Property("Speed",         Speed);
	Parameters.Property("StopBit",          StopBit);
	Parameters.Property("DataBit",        DataBit);
	Parameters.Property("Timeout",          Timeout);
	Parameters.Property("TracksParameters", TracksParameters);

	If Port             = Undefined
	 Or Speed         = Undefined
	 Or StopBit          = Undefined
	 Or DataBit        = Undefined
	 Or TracksParameters = Undefined Then
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

	If Result Then
		Output_Parameters.Add("MagneticCardReader");
		Output_Parameters.Add(New Array());
		Output_Parameters[1].Add("CardCodeReceived");
		
		Try
			Result = (DriverObject.Attach(Output_Parameters[0]) = 0);
		Except
			Result = False;
		EndTry;
		
		If Not Result Then
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='Error while connecting a device.
		|Check port settings.';ru='Ошибка при подключении устройства.
		|Проверьте настройки порта.'"));
		EndIf;

		If Result = True Then
			DriverObject.DataBit  = Parameters.DataBit;
			DriverObject.Port       = Parameters.Port;
			DriverObject.Speed   = Parameters.Speed;

			For IndexOf = 1 To 3 Do
				If Parameters.TracksParameters[3 - IndexOf].Use Then
					// Starting from version 8.0.12.2 there were changes in the driver interface; do not change the value 8001202 to another!
					If VersionStringIntoNumber(DriverObject.GetVersionNumber()) >= 8001202 AND Port=0 Then
						DriverObject.SuffixString = SPVCharacters(Parameters.TracksParameters[3 - IndexOf].Suffix, 13);
					Else
						DriverObject.StopChar = CharCode(SPVCharacters(Parameters.TracksParameters[3 - IndexOf].Suffix, 13));
						DriverObject.Port       = Parameters.Port;
					EndIf;
					Break;
				EndIf;
			EndDo;
			
			If VersionStringIntoNumber(DriverObject.GetVersionNumber()) >= 8001202 AND Parameters.Port=0 Then
				If Parameters.Property("Timeout") AND Not Parameters.Timeout = Undefined Then
					DriverObject.Timeout = Parameters.Timeout;
				Else
					DriverObject.Timeout = 75;
				EndIf;
			EndIf;
			
			DriverObject.EventName = Output_Parameters[1][0];
			
			Try
				Result = (DriverObject.Lock(1) = 0);
			Except
				Result = False;
			EndTry;
			
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
					Output_Parameters.Add(NStr("en='Error while connecting a device.
		|Check port settings.';ru='Ошибка при подключении устройства.
		|Проверьте настройки порта.'"));
				EndIf;
			Else
				DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(NStr("en='Failed to lock the device.
		|Check port settings.';ru='Не удалось занять устройство.
		|Проверьте настройки порта.'"));
			EndIf;
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function disconnects a device.
//
Function DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;

	// Required output
	If TypeOf(Output_Parameters) <> Type("Array") Then
		Output_Parameters = New Array();
	EndIf;

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

// Returns the component version located in the layout.
//
Function GetExternalComponentVersion() 
	
	Return "8.0.17.1";
	
EndFunction

// Function handles the external events of trade equipment.
//
Function ProcessEvent(DriverObject, Parameters, ConnectionParameters, Event, Data, Output_Parameters)

	Result = True;
	CardCode  = Data;

	DriverObject.DataSend = 0;

	PrefixPosition = 0;
	SuffixPosition = 0;
	TempCardCode    = "";
	CardData = "";
	PositionForReading = 1;

	TracksData = New Array();
	For TrackNumber = 1 To 3 Do
		TracksData.Add("");

		CurrentTrack = Parameters.TracksParameters[TrackNumber - 1];
		If CurrentTrack.Use Then
			PrefixDriver = Char(CurrentTrack.Prefix);
			SuffixOfDriver = Char(CurrentTrack.Suffix);

			If PositionForReading < StrLen(CardCode) Then
				CardData = Mid(CardCode, PositionForReading);

				PrefixPosition = Find(CardData, PrefixDriver);
				SuffixPosition = Find(CardData, SuffixOfDriver);

				TempPrefixPosition = ?(PrefixPosition = 0, 1, PrefixPosition + StrLen(PrefixDriver));
				LengthUpToTempSuffix = ?(SuffixPosition = 0,
				    StrLen(CardData) + 1 - TempPrefixPosition, SuffixPosition - TempPrefixPosition);
				TempCardCode = TempCardCode + Mid(CardData, TempPrefixPosition, LengthUpToTempSuffix);

				TracksData[TrackNumber - 1] = Mid(CardData,
				                                  TempPrefixPosition,
				                                  LengthUpToTempSuffix);

				PositionForReading = PositionForReading + ?(SuffixPosition = 0,
				                                        StrLen(CardData),
				                                        SuffixPosition + StrLen(SuffixOfDriver) - 1);
			EndIf;
		EndIf;
	EndDo;

	CardCode = TempCardCode;

	Output_Parameters.Add("TracksData");
	Output_Parameters.Add(New Array());
	Output_Parameters[1].Add(CardCode);
	Output_Parameters[1].Add(New Array);
	Output_Parameters[1][1].Add(Mid(Data,2));
	Output_Parameters[1][1].Add(TracksData);
	Output_Parameters[1][1].Add(0);
	Output_Parameters[1][1].Add(EquipmentManagerServerCall.DecryptMagneticCardCode(TracksData, Parameters.TracksParameters));

	Return Result;

EndFunction

// Procedure is called when the system is ready to accept the following event from the device.
//
Function FinishProcessingEvents(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	DriverObject.DataSend = 1;

	Return Result;

EndFunction

// Open the form of driver parameters check.
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;

	DriverObject.Port      = Parameters.Port;
	DriverObject.Speed  = Parameters.Speed;
	DriverObject.DataBit = Parameters.DataBit;

	DriverObject.DeviceTest();
	
	Return Result;

EndFunction

// Open the form of driver logging settings.
//
Function JournalingParameters(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	DriverObject.Speed  = Parameters.Speed;
	DriverObject.DataBit = Parameters.DataBit;
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
		Version = DriverObject.GetVersionNumber();
		Output_Parameters[1] = Version;
		// Additional parameters
		Output_Parameters.Add(GetExternalComponentVersion());
		Output_Parameters.Add(VersionStringIntoNumber(Version));
		Output_Parameters.Add(VersionStringIntoNumber(GetExternalComponentVersion()));
	Except
	EndTry;

	Return Result;

EndFunction

// Function converts a row presentation of the version (the one with three dots) to numeric (suitable for comparison).
//
Function VersionStringIntoNumber(VersionString) 
	
	Try
		Version = VersionString;	
		Result = Number(Left(Version, Find(Version, ".")-1));
		Version = Mid(Version, Find(Version, ".") + 1);
		Result = Result*100 + Number(Left(Version, Find(Version, ".")-1));
		Version = Mid(Version, Find(Version, ".") + 1);
		Result = Result*100 + Number(Left(Version, Find(Version, ".")-1));
		Version = Mid(Version, Find(Version, ".") + 1);
		Result = Result*100 + Number(Version);
	Except
		Return 0;
	EndTry;
	
	Return Result;
	
EndFunction

// Function converts a suffix/prefix to a character string for
// transfer from the format
// to the driver #13 #10 from
// the format 13(Row) or 10(Number) of the format (13)CR.
//
Function SPVCharacters(SuffixNumber, Default) 
	
	Number           = SuffixNumber;
	SuffixOfDriver = "";
	Position         = Find(Number, "#");
	
	If Position = 0 Then
		Try
			PositionLeft = Find(Number, "(");
			PositionRigh = Find(Number, ")");
			If PositionRigh >= PositionLeft Then
				Number = Mid(Number, PositionLeft+1, PositionRigh-PositionLeft-1);
				Number = Number(Number);
			Else
				Number = Default;
			EndIf;
		Except
			Number = Default;
		EndTry;
		
		Return Char(Number);
	EndIf;
	
	Number = Mid(Number, Find(Number, "#") + 1);
	
	Try
	    While True Do
			TempNumber = Number;
			Position = Find(Number, "#");
			If Position > 0 Then
				TempNumber = Left(Number, Position-1);
			EndIf;	
			SuffixOfDriver = SuffixOfDriver + Char(Number(TempNumber));
			If Position = 0 Then 
				Break 
			EndIf;
			Number = Mid(Number, Find(Number, "#") + 1);
		EndDo;
	Except
	EndTry;
	
	Return SuffixOfDriver;
	
EndFunction

#EndRegion