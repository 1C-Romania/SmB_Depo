
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
	DataBit        = Undefined;
	StopBit          = Undefined;
	Parity         = Undefined;
	Sensitivity = Undefined;
	TracksParameters = Undefined;
	Model           = Undefined;

	Parameters.Property("Port"            , Port);
	Parameters.Property("Speed"        , Speed);
	Parameters.Property("DataBit"       , DataBit);
	Parameters.Property("StopBit"         , StopBit);
	Parameters.Property("Parity"        , Parity);
	Parameters.Property("Sensitivity", Sensitivity);
	Parameters.Property("TracksParameters", TracksParameters);
	Parameters.Property("Model"          , Model);

	If Port             = Undefined
	 Or Speed         = Undefined
	 Or DataBit        = Undefined
	 Or StopBit          = Undefined
	 Or Parity         = Undefined
	 Or Sensitivity = Undefined
	 Or TracksParameters = Undefined
	 Or Model           = Undefined Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set.
		|For the correct work of the device it is necessary to specify the parameters of its work.
		|You can do it using the Parameters setting
		|form of the peripheral model in the Connection and equipment setting form.'"));

		Result = False;
	EndIf;

	If Result Then
		Output_Parameters.Add("MagneticStripeCardReader");
		Output_Parameters.Add(New Array());
		Output_Parameters[1].Add("MagneticStripeCardValue");

		If Parameters.Port <> 100 Then
			DriverObject.AddDevice();
		EndIf;

		If (Parameters.Port <> 100 AND DriverObject.Result = 0)
		 Or Parameters.Port = 100 Then
			ConnectionParameters.Insert("DeviceID", DriverObject.CurrentDeviceNumber);
			If Parameters.Port <> 100 Then
				ConnectionParameters.DeviceID = DriverObject.CurrentDeviceNumber;
			Else
				DriverObject.CurrentDeviceNumber = 1;
				ConnectionParameters.DeviceID = 1;
			EndIf;
			DriverObject.CurrentDeviceDescription = Parameters.Model;

			DriverObject.NumberPort       = Parameters.Port;
			DriverObject.ExchangeSpeed   = Parameters.Speed;
			DriverObject.Parity         = Parameters.Parity;
			DriverObject.DataBits       = Parameters.DataBit;
			DriverObject.StopBits         = Parameters.StopBit;
			DriverObject.Sensitivity = Parameters.Sensitivity;
			DriverObject.Model           = 1;
			DriverObject.OldVersion     = 0;

			For IndexOf = 1 To 3 Do
				If Parameters.TracksParameters[IndexOf - 1].Use Then
					PrefixDriver = Parameters.TracksParameters[IndexOf - 1].Prefix;
					Break;
				EndIf;
			EndDo;

			For IndexOf = 1 To 3 Do
				If Parameters.TracksParameters[3 - IndexOf].Use Then
					SuffixOfDriver = Parameters.TracksParameters[3 - IndexOf].Suffix;
					Break;
				EndIf;
			EndDo;

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
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.ErrorDescription = DriverObject.ResultDescription;
			Result = False;
		EndIf;
		
		If Result Then
			DriverObject.DeviceIsOn = 1;
			If DriverObject.Result <> 0 Then
				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);
				DriverObject.DeviceIsOn = 0;
				DriverObject.DeleteDevice();
				Result = False;
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

	DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;
	DriverObject.DeviceIsOn = 0;
	If DriverObject.CountDevices > 1 Then
		DriverObject.DeleteDevice();
	EndIf;

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
		Output_Parameters.Add(NStr("en='The %Command% command is not supported by the current driver.'"));
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
	CardCode  = Data;	

	Try
		DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;
		DriverObject.DataSend  = 0;
		DriverObject.MessageNo = Number(Data);
		CardCode                      = Upper(DriverObject.Data);
	Except
		ConnectionParameters.ErrorDescription = DriverObject.ResultDescription;
		Result = False;
	EndTry;
	
	// _TEMPORARY_ problem decision of first colon in code.
	If Left(CardCode, 1) = ":" Then
		CardCode = Right(CardCode, StrLen(CardCode)-1);
	EndIf;

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
			PrefixDriver = CurrentTrack.Prefix;
			SuffixOfDriver = CurrentTrack.Suffix;

			If PositionForReading < StrLen(CardCode) Then
				CardData = Mid(CardCode, PositionForReading);

				// CONVERSION AND SEARCH PREFIX IN DATA STRING
				TechPrefix = StrReplace(PrefixDriver, "#", Chars.LF);
				CharCount = StrLineCount(TechPrefix);
				PrefixDriver = "";
				For CurIndex = 2 To CharCount Do
					PrefixDriver = PrefixDriver + Char(Number(StrGetLine(TechPrefix, CurIndex)));
				EndDo;
				PrefixPosition = Find(CardData, PrefixDriver);

				// CONVERSION AND SEARCH SUFFIX IN DATA STRING
				CurSuffix = StrReplace(SuffixOfDriver, "#", Chars.LF);
				CharCount = StrLineCount(CurSuffix);
				SuffixOfDriver = "";
				For CurIndex = 2 To CharCount Do
					SuffixOfDriver = SuffixOfDriver + Char(Number(StrGetLine(CurSuffix, CurIndex)));
				EndDo;
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
	Output_Parameters[1][1].Add(CardCode);
	Output_Parameters[1][1].Add(TracksData);
	Output_Parameters[1][1].Add(0);
	Output_Parameters[1][1].Add(EquipmentManagerServerCall.DecryptMagneticCardCode(TracksData, Parameters.TracksParameters));
	
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
	EndTry;

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
