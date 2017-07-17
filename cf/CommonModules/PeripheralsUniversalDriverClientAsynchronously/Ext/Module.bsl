                                            
#Region ProgramInterface

Procedure StartConnectionDeviceGetErrorEnd(ExecutionResult, CallParameters, AdditionalParameters) Export
	
	Output_Parameters = AdditionalParameters.Output_Parameters;
	Output_Parameters.Clear();
	Output_Parameters.Add(999);
	Output_Parameters.Add(CallParameters[0]);
	
	ExecutionResult = New Structure("Result, Output_Parameters", False, Output_Parameters);
	If AdditionalParameters.AlertOnEnd <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.AlertOnEnd, ExecutionResult);
	EndIf;
	
EndProcedure

Procedure StartDeviceConnectionConnectEnd(ExecutionResult, CallParameters, AdditionalParameters) Export
	
	If Not ExecutionResult Then
		AlertEnableEnd = New NotifyDescription("StartConnectionDeviceGetErrorEnd", ThisObject, AdditionalParameters);
		Try
			AdditionalParameters.DriverObject.StartCallGetError(AlertEnableEnd, CallParameters[0]) 
		Except
			Output_Parameters = AdditionalParameters.Output_Parameters;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='An error occurred while calling the <DriverObject.GetError> method.';ru='Ошибка вызова метода <DriverObject.GetError>.'") + Chars.LF + ErrorDescription());
			ExecutionResult = New Structure("Result, Output_Parameters", False, Output_Parameters);
			If AdditionalParameters.AlertOnEnd <> Undefined Then
				ExecuteNotifyProcessing(AdditionalParameters.AlertOnEnd, ExecutionResult);
			EndIf;
		EndTry;
	Else
		AdditionalParameters.ConnectionParameters.DeviceID = CallParameters[0];
		Output_Parameters = AdditionalParameters.Output_Parameters;
		ConnectionParameters = AdditionalParameters.ConnectionParameters;
		
		If ConnectionParameters.EquipmentType = "POSTerminal" Then
			ConnectionParameters.Insert("OriginalTransactionCode", Undefined);
			ConnectionParameters.Insert("OperationKind", "");
		ElsIf ConnectionParameters.EquipmentType = "BarCodeScanner" Then
			Output_Parameters.Add(String(CallParameters[0]));
			Output_Parameters.Add(New Array());
			Output_Parameters[1].Add("Barcode");
			Output_Parameters[1].Add("Barcode");
		ElsIf ConnectionParameters.EquipmentType = "MagneticCardReader" Then
			Output_Parameters.Add(String(CallParameters[0]));
			Output_Parameters.Add(New Array());
			Output_Parameters[1].Add("CardData");
			Output_Parameters[1].Add("TracksData");
		EndIf;  
		
		ExecutionResult = New Structure("Result, Output_Parameters", True, Output_Parameters);
		If AdditionalParameters.AlertOnEnd <> Undefined Then
			ExecuteNotifyProcessing(AdditionalParameters.AlertOnEnd, ExecutionResult);
		EndIf;
	EndIf;
	
EndProcedure

Procedure StartConnectionDeviceParametersSettingEnd(Result, Parameters) Export

	AlertEnableEnd = New NotifyDescription("StartDeviceConnectionConnectEnd", ThisObject, Parameters);
	Try
		Parameters.DriverObject.StartCallEnable(AlertEnableEnd, Parameters.ConnectionParameters.DeviceID) 
	Except
		Output_Parameters = Parameters.Output_Parameters;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='An error occurred while calling the <DriverObject.Enable> method.';ru='Ошибка вызова метода <DriverObject.Enable>.'") + Chars.LF + ErrorDescription());
		ExecutionResult = New Structure("Result, Output_Parameters", False, Output_Parameters);
		If Parameters.AlertOnEnd <> Undefined Then
			ExecuteNotifyProcessing(Parameters.AlertOnEnd, ExecutionResult);
		EndIf;
	EndTry;
	
EndProcedure

// Function connects the device.
//
Procedure StartEnableDevice(AlertOnEnd, DriverObject, Parameters, ConnectionParameters, AdditionalParameters) Export
	
	ConnectionParameters.Insert("DeviceID", Undefined);
	Output_Parameters = New Array();
	
	AdditionalParameters.Insert("DriverObject"         , DriverObject);
	AdditionalParameters.Insert("Parameters"              , Parameters);
	AdditionalParameters.Insert("ConnectionParameters"   , ConnectionParameters);
	AdditionalParameters.Insert("Output_Parameters"      , Output_Parameters);
	AdditionalParameters.Insert("AlertOnEnd", AlertOnEnd);
	
	AlertOnParametersSetting = New NotifyDescription("StartConnectionDeviceParametersSettingEnd", ThisObject, AdditionalParameters);
	StartParametersInstallation(AlertOnParametersSetting, AdditionalParameters);
	
EndProcedure

Procedure StartDisableDeviceEnd(ExecutionResult, CallParameters, AdditionalParameters) Export
	
	Output_Parameters = New Array();
	
	If ExecutionResult Then
		Output_Parameters.Clear();
		Output_Parameters.Add(0);
	Else
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
	EndIf;
	
	ExecutionResult = New Structure("Result, Output_Parameters", ExecutionResult, Output_Parameters);
	If AdditionalParameters.AlertOnEnd <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.AlertOnEnd, ExecutionResult);
	EndIf;
	
EndProcedure

// Function disconnects the device.
//
Procedure StartDisableDevice(AlertOnEnd, DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export
	
	CommandParameters = New Structure();
	CommandParameters.Insert("AlertOnEnd", AlertOnEnd);
	CommandParameters.Insert("DriverObject"         , DriverObject);
	CommandParameters.Insert("Parameters"              , Parameters);
	CommandParameters.Insert("ConnectionParameters"   , ConnectionParameters);
	CommandParameters.Insert("Output_Parameters"      , Output_Parameters);
	MethodNotification = New NotifyDescription("StartDisableDeviceEnd", ThisObject, CommandParameters);
	
	Try
		DriverObject.StartCallDisable(MethodNotification, ConnectionParameters.DeviceID);
	Except
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='An error occurred while calling the <DriverObject.Disable> method.';ru='Ошибка вызова метода <DriverObject.Disable>.'") + Chars.LF + ErrorDescription());
		ExecutionResult = New Structure("Result, Output_Parameters", False, Output_Parameters);
		If AlertOnEnd <> Undefined Then
			ExecuteNotifyProcessing(AlertOnEnd, ExecutionResult);
		EndIf;
	EndTry;
	
EndProcedure

// Procedure starts the application, processes and redirects command to driver.
//
Procedure StartCommandExecution(AlertOnEnd, Command, InputParameters = Undefined, DriverObject, Parameters, ConnectionParameters) Export
	
	Output_Parameters = New Array();
	
	// PROCEDURES AND FUNCTIONS OVERALL FOR ALL DRIVER TYPES
	
	// Test device
	If Command = "DeviceTest" OR Command = "CheckHealth" Then
		StartDeviceText(AlertOnEnd, DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	ElsIf Command = "ExecuteAdditionalAction" OR Command = "DoAdditionalAction" Then
		NameActions = InputParameters[0];
		StartExecuteAdditionalAction(AlertOnEnd, DriverObject, Parameters, ConnectionParameters, NameActions, Output_Parameters);
		
	// Receive driver version
	ElsIf Command = "GetDriverVersion" OR Command = "GetVersion" Then
		StartGettingDriverVersion(AlertOnEnd, DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Get the driver description.
	ElsIf Command = "GetDriverDescription" OR Command = "GetDescription" Then
		StarGetDriverDescription(AlertOnEnd, DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// PROCEDURES AND FUNCTIONS OVERALL FOR WORK WITH DATA INPUT DEVICES
	
	// Processing the event from device.
	ElsIf Command = "ProcessEvent" Then
		Event = InputParameters[0];
		Data  = InputParameters[1];
		Result = ProcessEvent(DriverObject, Parameters, ConnectionParameters, Event, Data, Output_Parameters);
		
	Else
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='The %Command% command is not supported by the driver.';ru='Команда ""%Команда%"" не поддерживается данным драйвером.'"));
		Output_Parameters[1] = StrReplace(Output_Parameters[1], "%Command%", Command);
		ExecutionResult = New Structure("Result, Output_Parameters", False, Output_Parameters);
		If AlertOnEnd <> Undefined Then
			ExecuteNotifyProcessing(AlertOnEnd, ExecutionResult);
		EndIf;
	EndIf;

EndProcedure

#EndRegion

#Region ProceduresAndFunctionsCommonForDataInputDevices

// Function processes external data of peripheral.
//
Function ProcessEvent(DriverObject, Parameters, ConnectionParameters, Event, Data, Output_Parameters) Export
	
	Result = True;
	
	If Event = "Barcode" Or Event = "Barcode" Then
		
		Barcode = TrimAll(Data);
		Output_Parameters.Add("ScanData");
		Output_Parameters.Add(New Array());
		Output_Parameters[1].Add(Barcode);
		Output_Parameters[1].Add(New Array());
		Output_Parameters[1][1].Add(Data);
		Output_Parameters[1][1].Add(Barcode);
		Output_Parameters[1][1].Add(0);
		Result = True;
		
	ElsIf Event = "CardData" Or Event = "TracksData" Then
		
		CardData = TrimAll(Data);
		Output_Parameters.Add("TracksData");
		Output_Parameters.Add(New Array());
		Output_Parameters[1].Add(CardData);
		Output_Parameters[1].Add(New Array());
		Output_Parameters[1][1].Add(Data);
		Output_Parameters[1][1].Add(CardData);
		Output_Parameters[1][1].Add(0);
		Result = True;
		
	EndIf;
	
	Return Result;

EndFunction

#EndRegion

#Region ProceduresAndFunctionsCommonForAllDriversTypes

// Procedure returns the version of set driver.
//
Procedure StartGettingDriverVersionEnd(ResultOfCall, CallParameters, AdditionalParameters) Export
	
	AdditionalParameters.Output_Parameters[1] = ResultOfCall;
	ExecutionResult = New Structure("Result, Output_Parameters", True, AdditionalParameters.Output_Parameters);
	
	If AdditionalParameters.AlertOnEnd <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.AlertOnEnd, ExecutionResult);
	EndIf;
	
EndProcedure

// Procedure returns the version of set driver.
//
Procedure StartGettingDriverVersion(AlertOnEnd, DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Output_Parameters.Clear();
	Output_Parameters.Add(NStr("en='Set';ru='Установлен'"));
	Output_Parameters.Add(NStr("en='Not defined';ru='Не определена'"));
	
	CommandParameters = New Structure();
	CommandParameters.Insert("AlertOnEnd", AlertOnEnd);
	CommandParameters.Insert("DriverObject"         , DriverObject);
	CommandParameters.Insert("Parameters"              , Parameters);
	CommandParameters.Insert("ConnectionParameters"   , ConnectionParameters);
	CommandParameters.Insert("Output_Parameters"      , Output_Parameters);
	MethodNotification = New NotifyDescription("StartGettingDriverVersionEnd", ThisObject, CommandParameters);
	
	Try
		DriverObject.StartCallGetVersionNumber(MethodNotification);
	Except
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='An error occurred while calling the <DriverObject.GetVersionNumber> method.';ru='Ошибка вызова метода <DriverObject.GetVersionNumber>.'") + Chars.LF + ErrorDescription());
		ExecutionResult = New Structure("Result, Output_Parameters", False, Output_Parameters);
		If AlertOnEnd <> Undefined Then
			ExecuteNotifyProcessing(AlertOnEnd, ExecutionResult);
		EndIf;
	EndTry;
	
EndProcedure

// Procedure of setting driver parameters end
//
Procedure StartParametersSettingEnd(ExecutionResult, CallParameters, AdditionalParameters) Export
	
	If Not TypeOf(AdditionalParameters.ParametersForSetting) = Type("Structure") Then
		Return;
	EndIf;
	
	If AdditionalParameters.ParametersForSetting.Count() > 0  Then
		For Each Parameter IN AdditionalParameters.ParametersForSetting Do
			CurrParameterName = Parameter.Key;
			ParameterValue = Parameter.Value;
			AdditionalParameters.ParametersForSetting.Delete(CurrParameterName);
			MethodNotification = New NotifyDescription("StartParametersSettingEnd", ThisObject, AdditionalParameters);
			AdditionalParameters.DriverObject.StartCallSetParameter(MethodNotification, Mid(CurrParameterName, 3), ParameterValue);
			Break;
		EndDo;
	Else
		If AdditionalParameters.AlertOnParametersSetting <> Undefined Then
			ExecuteNotifyProcessing(AdditionalParameters.AlertOnParametersSetting, AdditionalParameters);
		EndIf;   
	EndIf;
	
EndProcedure

// Procedure sets driver parameters.
//
Procedure StartParametersInstallation(AlertOnParametersSetting, AdditionalParameters) Export
	
	TempParameters = New Structure();
	If AdditionalParameters.ConnectionParameters.Property("EquipmentType") Then
		EquipmentType = AdditionalParameters.ConnectionParameters.EquipmentType;
		// Predefined parameter with the indication of driver type.
		TempParameters.Insert("P_EquipmentType", EquipmentType) 
	EndIf;
	
	For Each Parameter IN AdditionalParameters.Parameters Do
		If Left(Parameter.Key, 2) = "P_" Then
			TempParameters.Insert(Parameter.Key, Parameter.Value);
		EndIf;
	EndDo;
	
	AdditionalParameters.Insert("ParametersForSetting", TempParameters);
	AdditionalParameters.Insert("AlertOnParametersSetting", AlertOnParametersSetting);
	StartParametersSettingEnd(True, Undefined, AdditionalParameters);
	
EndProcedure

// Procedure of testing device end.
//
Procedure BeginDeviceTestParametersSettingEnd(Result, Parameters) Export
	
	TestResult       = "";
	ActivatedDemoMode = "";  
	
	Try
		AlertOnEnd = New NotifyDescription("StartDeviceTextEnd", ThisObject, Parameters);
		Parameters.DriverObject.StartCallDeviceText(AlertOnEnd, TestResult, ActivatedDemoMode);
	Except
		Output_Parameters = Parameters.Output_Parameters;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='An error occurred while calling the <DriverObject.DeviceText> method.';ru='Ошибка вызова метода <DriverObject.DeviceText>.'") + Chars.LF + ErrorDescription());
		ExecutionResult = New Structure("Result, Output_Parameters", False, Output_Parameters);
		If Parameters.AlertOnEnd <> Undefined Then
			ExecuteNotifyProcessing(Parameters.AlertOnEnd, ExecutionResult);
		EndIf;
	EndTry;
	
EndProcedure

// Procedure tests the device.
//
Procedure StartDeviceTextEnd(ExecutionResult, Parameters, AdditionalParameters) Export
	
	Output_Parameters = AdditionalParameters.Output_Parameters;
	
	If ExecutionResult Then
		Output_Parameters.Clear();
		Output_Parameters.Add(0);
	Else
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
	EndIf;
	Output_Parameters.Add(Parameters[0]);
	Output_Parameters.Add(Parameters[1]);
	
	ExecutionResult = New Structure("Result, Output_Parameters", ExecutionResult, Output_Parameters);
	If AdditionalParameters.AlertOnEnd <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.AlertOnEnd, ExecutionResult);
	EndIf;
	
EndProcedure

// Procedure tests the device.
//
Procedure StartDeviceText(AlertOnEnd, DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("DriverObject"         , DriverObject);
	AdditionalParameters.Insert("Parameters"              , Parameters);
	AdditionalParameters.Insert("ConnectionParameters"   , ConnectionParameters);
	AdditionalParameters.Insert("Output_Parameters"      , Output_Parameters);
	AdditionalParameters.Insert("AlertOnEnd", AlertOnEnd);
	
	AlertOnParametersSetting = New NotifyDescription("BeginDeviceTestParametersSettingEnd", ThisObject, AdditionalParameters);
	StartParametersInstallation(AlertOnParametersSetting, AdditionalParameters);
	
EndProcedure

// Function executes an additional action for a device.
//
Procedure StartExecuteAdditionalAction(AlertOnEnd, DriverObject, Parameters, ConnectionParameters, NameActions, Output_Parameters);
	
	For Each Parameter IN Parameters Do
		If Left(Parameter.Key, 2) = "P_" Then
			ParameterValue = Parameter.Value;
			ParameterName = Mid(Parameter.Key, 3);
			Response = DriverObject.SetParameter(ParameterName, ParameterValue) 
		EndIf;
	EndDo;
	
	Try
		Response = DriverObject.ExecuteAdditionalAction(NameActions);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.GetError(Output_Parameters[1])
		Else
			Output_Parameters.Clear();  
		EndIf;
	Except
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='An error occurred while calling the <DriverObject.ExecuteAdditionalAction> method.';ru='Ошибка вызова метода <DriverObject.ExecuteAdditionalAction>.'") + Chars.LF + ErrorDescription());
	EndTry;
	
EndProcedure

// Procedure returns the description of set driver.
//
Procedure StarGetDriverDescription(AlertOnEnd, DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Output_Parameters.Clear();
	Output_Parameters.Add(NStr("en='Set';ru='Установлен'"));
	Output_Parameters.Add(NStr("en='Not defined';ru='Не определена'"));
	Output_Parameters.Add(NStr("en='Undefined';ru='Неопределено'"));
	Output_Parameters.Add(NStr("en='Undefined';ru='Неопределено'"));
	Output_Parameters.Add(NStr("en='Undefined';ru='Неопределено'"));
	Output_Parameters.Add(Undefined);
	Output_Parameters.Add(Undefined);
	Output_Parameters.Add(Undefined);
	Output_Parameters.Add(Undefined);
	Output_Parameters.Add(Undefined);
	Output_Parameters.Add(Undefined);

	CommandParameters = New Structure();
	CommandParameters.Insert("AlertOnEnd", AlertOnEnd);
	CommandParameters.Insert("DriverObject"         , DriverObject);
	CommandParameters.Insert("Parameters"              , Parameters);
	CommandParameters.Insert("ConnectionParameters"   , ConnectionParameters);
	CommandParameters.Insert("Output_Parameters"      , Output_Parameters);
	
	MethodNotification = New NotifyDescription("StartGettingDriverDescriptionVersionEnd", ThisObject, CommandParameters);
	Try
		DriverObject.StartCallGetVersionNumber(MethodNotification);
	Except
	EndTry;
	
EndProcedure

Procedure StartGettingDriverDescriptionVersionEnd(ResultOfCall, CallParameters, AdditionalParameters) Export
	
	Output_Parameters = AdditionalParameters.Output_Parameters;
	Output_Parameters[1] = ResultOfCall;
	
	DriverDescription      = "";
	DetailsDriver          = "";
	EquipmentType           = "";
	IntegrationLibrary  = True;
	MainDriverIsSet = False;
	AuditInterface         = 1012;
	URLExportDriver       = "";
	
	MethodNotification = New NotifyDescription("StartGetDriverDescriptionGetDescriptionEnd", ThisObject, AdditionalParameters);
	Try
		AdditionalParameters.DriverObject.StartCallGetDescription(MethodNotification, DriverDescription, DetailsDriver, EquipmentType, AuditInterface, 
									IntegrationLibrary, MainDriverIsSet, URLExportDriver);
	Except
	EndTry;

EndProcedure

Procedure StartGetDriverDescriptionGetDescriptionEnd(ResultOfCall, CallParameters, AdditionalParameters) Export
	
	Output_Parameters = AdditionalParameters.Output_Parameters;
	Output_Parameters[2] = CallParameters[0]; // DriverName;
	Output_Parameters[3] = CallParameters[1]; // DriverDescription;
	Output_Parameters[4] = CallParameters[2]; // EquipmentType;
	Output_Parameters[5] = CallParameters[3]; // InterfaceRevision;
	Output_Parameters[6] = CallParameters[4]; // IntegrationLibrary;
	Output_Parameters[7] = CallParameters[5]; // MainDriverInstalled;
	Output_Parameters[8] = CallParameters[6]; // URLDriverExport;
	
	ParametersDriver = "";
	MethodNotification = New NotifyDescription("StartGetDriverDescriptionGetParametersEnd", ThisObject, AdditionalParameters);
	Try
		AdditionalParameters.DriverObject.StartCallGetParameters(MethodNotification, ParametersDriver);
	Except
	EndTry;
	
EndProcedure

Procedure StartGetDriverDescriptionGetParametersEnd(ResultOfCall, CallParameters, AdditionalParameters) Export
	
	Output_Parameters = AdditionalParameters.Output_Parameters;
	Output_Parameters[9] = CallParameters[0];
	
	ExecutionResult = New Structure("Result, Output_Parameters", True, AdditionalParameters.Output_Parameters);
	If AdditionalParameters.AlertOnEnd <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.AlertOnEnd, ExecutionResult);
	EndIf;

EndProcedure

#EndRegion 