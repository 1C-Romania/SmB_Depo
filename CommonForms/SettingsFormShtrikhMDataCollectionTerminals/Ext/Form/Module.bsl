
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)


	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("ID", ID);
	Parameters.Property("HardwareDriver", HardwareDriver);
	
	Title = NStr("en='Equipment:'") + Chars.NBSp  + String(ID);
	
	TextColor = StyleColors.FormTextColor;
	ErrorColor = StyleColors.NegativeTextColor;
	
	ListModel = Items.Model.ChoiceList;
	ListModel.Add("Opticon DWT");
	ListModel.Add("Opticon OPL");
	ListModel.Add("Opticon PHL");
	ListModel.Add("Zebex PDx10");
	ListModel.Add("Zebex PDx20");
	
	ListPort = Items.Port.ChoiceList;
	For IndexOf = 1 To 64 Do
		ListPort.Add(IndexOf, "COM" + TrimAll(IndexOf));
	EndDo;

	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(1,     "300 baud");
	SpeedList.Add(3,    "1200 baud");
	SpeedList.Add(4,    "2400 baud");
	SpeedList.Add(5,    "4800 baud");
	SpeedList.Add(7,    "9600 baud");
	SpeedList.Add(10,  "19200 baud");
	SpeedList.Add(11,  "38400 baud");
	SpeedList.Add(13,  "57600 baud");
	SpeedList.Add(14, "115200 baud");
	
	ParityList = Items.Parity.ChoiceList;
	ParityList.Add(0, "No");
	ParityList.Add(1, "Oddness");
	ParityList.Add(2, "Parity");
	ParityList.Add(3, "Installed");
	ParityList.Add(4, "Reset");
	
	DataBitsList = Items.DataBits.ChoiceList;
	DataBitsList.Add(3, "7 bits");
	DataBitsList.Add(4, "8 bits");
	
	BitStopList = Items.StopBits.ChoiceList;
	BitStopList.Add(0, "1 bit");
	BitStopList.Add(2, "2 bits");

	tempPort            = Undefined;
	tempSpeed           = Undefined;
	tempTimeout         = Undefined;
	tempParity          = Undefined;
	tempDataBits        = Undefined;
	tempStopBits        = Undefined;
	tempExportingTable     = Undefined;
	tempImportingTable       = Undefined;
	TempSeparator       = Undefined;
	tempExportFormat  = Undefined;
	tempImportFormat    = Undefined;
	tempModel           = Undefined;

	Parameters.EquipmentParameters.Property("Port"            , tempPort);
	Parameters.EquipmentParameters.Property("Speed"        , tempSpeed);
	Parameters.EquipmentParameters.Property("Timeout"         , tempTimeout);
	Parameters.EquipmentParameters.Property("Parity"        , tempParity);
	Parameters.EquipmentParameters.Property("DataBits"      , tempDataBits);
	Parameters.EquipmentParameters.Property("StopBits"        , tempStopBits);
	Parameters.EquipmentParameters.Property("ExportingTable" , tempExportingTable);
	Parameters.EquipmentParameters.Property("ImportingTable" , tempImportingTable);
	Parameters.EquipmentParameters.Property("ExportFormat"  , tempExportFormat);
	Parameters.EquipmentParameters.Property("ImportFormat"  , tempImportFormat);
	Parameters.EquipmentParameters.Property("Model"          , tempModel);
	
	Port            = ?(tempPort        = Undefined,    1, tempPort);
	Speed           = ?(tempSpeed       = Undefined,    7, tempSpeed);
	Timeout         = ?(tempTimeout     = Undefined, 3200, tempTimeout);
	Parity          = ?(tempParity      = Undefined,    0, tempParity);
	DataBits        = ?(tempDataBits    = Undefined,    4, tempDataBits);
	StopBits        = ?(tempStopBits    = Undefined,    0, tempStopBits);
	ExportingTable   = ?(tempExportingTable = Undefined,    1, tempExportingTable);
	ImportingTable       = ?(tempImportingTable   = Undefined,    1, tempImportingTable);
	
	If tempExportFormat <> Undefined Then
		For Each BaseRow IN tempExportFormat Do
			TableRow = ExportFormat.Add();
			TableRow.FieldNumber    = BaseRow.FieldNumber;
			TableRow.Description = BaseRow.Description;
		EndDo;
	EndIf;
	
	If tempImportFormat <> Undefined Then
		For Each DocumentRow IN tempImportFormat Do
			TableRow = ImportFormat.Add();
			TableRow.FieldNumber    = DocumentRow.FieldNumber;
			TableRow.Description = DocumentRow.Description;
		EndDo;
	EndIf;
	
	Model = ?(tempModel = Undefined, Items.Model.ChoiceList[0].Value, tempModel);
	
	Items.DeviceTest.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);
	Items.SetupDriver.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateInformationAboutDriver();

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("Port"            , Port);
	ParametersNewValue.Insert("Speed"        , Speed);
	ParametersNewValue.Insert("Timeout"         , Timeout);
	ParametersNewValue.Insert("Parity"        , Parity);
	ParametersNewValue.Insert("DataBits"      , DataBits);
	ParametersNewValue.Insert("StopBits"        , StopBits);
	ParametersNewValue.Insert("ExportingTable" , ExportingTable);
	ParametersNewValue.Insert("ImportingTable" , ImportingTable);
	ParametersNewValue.Insert("Model"          , Model);
	
	tempExportFormat = New Array();
	For Each TableRow IN ExportFormat Do
		NewRow = New Structure("FieldNumber, Description",
		                              TableRow.FieldNumber,
		                              TableRow.Description);
		tempExportFormat.Add(NewRow);
	EndDo;
	ParametersNewValue.Insert("ExportFormat", tempExportFormat);
	
	tempImportFormat = New Array();
	For Each TableRow IN ImportFormat Do
		NewRow = New Structure("FieldNumber, Description",
		                              TableRow.FieldNumber,
		                              TableRow.Description);
		tempImportFormat.Add(NewRow);
	EndDo;
	ParametersNewValue.Insert("ImportFormat", tempImportFormat);
	
	Result = New Structure;
	Result.Insert("ID", ID);
	Result.Insert("EquipmentParameters", ParametersNewValue);
	
	Close(Result);
	
EndProcedure

&AtClient
Procedure DeviceTest(Command)
	
	ClearMessages();
	
	TestResult = Undefined;
	
	InputParameters  = Undefined;
	Output_Parameters = Undefined;
	
	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"           , Port);
	tempDeviceParameters.Insert("Speed"       , Speed);
	tempDeviceParameters.Insert("Timeout"        , Timeout);
	tempDeviceParameters.Insert("Parity"       , Parity);
	tempDeviceParameters.Insert("DataBits"     , DataBits);
	tempDeviceParameters.Insert("StopBits"       , StopBits);
	tempDeviceParameters.Insert("ExportingTable", ExportingTable);
	tempDeviceParameters.Insert("ImportingTable", ImportingTable);
	tempDeviceParameters.Insert("Model"         , Model);

	tempExportFormat = New Array();
	For Each TableRow IN ExportFormat Do
		NewRow = New Structure("FieldNumber, Description", TableRow.FieldNumber, TableRow.Description);
		tempExportFormat.Add(NewRow);
	EndDo;
	tempDeviceParameters.Insert("ExportFormat", tempExportFormat);
	
	tempImportFormat = New Array();
	For Each TableRow IN ImportFormat Do
		NewRow = New Structure("FieldNumber, Description", TableRow.FieldNumber, TableRow.Description);
		tempImportFormat.Add(NewRow);
	EndDo;
	tempDeviceParameters.Insert("ImportFormat", tempImportFormat);
	
	Result = EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
	                                                                      InputParameters,
	                                                                      Output_Parameters,
	                                                                      ID,
	                                                                      tempDeviceParameters);
	If Result Then
		MessageText = NStr("en = 'Test successfully performed.'");
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array")
		                           AND Output_Parameters.Count() >= 2,
		                           NStr("en = 'Additional description:'") + " " + Output_Parameters[1], "");
		MessageText = NStr("en = 'Test failed.%Linefeed% %AdditionalDetails%'");
		MessageText = StrReplace(MessageText, "%Linefeed%", ?(IsBlankString(AdditionalDetails), "", Chars.LF));
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails), "", AdditionalDetails));
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;

EndProcedure

&AtClient
Procedure SetDriverFromArchiveOnEnd(Result) Export 
	
	CommonUseClientServer.MessageToUser(NStr("en='Driver is installed.'")); 
	UpdateInformationAboutDriver();
	
EndProcedure 

&AtClient
Procedure SettingDriverFromDistributionOnEnd(Result, Parameters) Export 
	
	If Result Then
		CommonUseClientServer.MessageToUser(NStr("en='Driver is installed.'")); 
		UpdateInformationAboutDriver();
	Else
		CommonUseClientServer.MessageToUser(NStr("en='An error occurred when installing the driver from distribution.'")); 
	EndIf;

EndProcedure 

&AtClient
Procedure SetupDriver(Command)

	ClearMessages();
	NotificationsDriverFromDistributionOnEnd = New NotifyDescription("SettingDriverFromDistributionOnEnd", ThisObject);
	NotificationsDriverFromArchiveOnEnd = New NotifyDescription("SetDriverFromArchiveOnEnd", ThisObject);
	EquipmentManagerClient.SetupDriver(HardwareDriver, NotificationsDriverFromDistributionOnEnd, NotificationsDriverFromArchiveOnEnd);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure UpdateInformationAboutDriver()

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"           , Port);
	tempDeviceParameters.Insert("Speed"       , Speed);
	tempDeviceParameters.Insert("Timeout"        , Timeout);
	tempDeviceParameters.Insert("Parity"       , Parity);
	tempDeviceParameters.Insert("DataBits"     , DataBits);
	tempDeviceParameters.Insert("StopBits"       , StopBits);
	tempDeviceParameters.Insert("ExportingTable", ExportingTable);
	tempDeviceParameters.Insert("ImportingTable", ImportingTable);
	tempDeviceParameters.Insert("Model"         , Model);

	tempExportFormat = New Array();
	For Each TableRow IN ExportFormat Do
		NewRow = New Structure("FieldNumber, Description",
		                              TableRow.FieldNumber,
		                              TableRow.Description);
		tempExportFormat.Add(NewRow);
	EndDo;
	tempDeviceParameters.Insert("ExportFormat", tempExportFormat);

	tempImportFormat = New Array();
	For Each TableRow IN ImportFormat Do
		NewRow = New Structure("FieldNumber, Description",
		                              TableRow.FieldNumber,
		                              TableRow.Description);
		tempImportFormat.Add(NewRow);
	EndDo;
	tempDeviceParameters.Insert("ImportFormat", tempImportFormat);

	If EquipmentManagerClient.RunAdditionalCommand("GetDriverVersion",
	                                                               InputParameters,
	                                                               Output_Parameters,
	                                                               ID,
	                                                               tempDeviceParameters) Then
		Driver = Output_Parameters[0];
		Version  = Output_Parameters[1];
	Else
		Driver = Output_Parameters[2];
		Version  = NStr("en='Not defined'");
	EndIf;

	Items.Driver.TextColor = ?(Driver = NStr("en='Not set'"), ErrorColor, TextColor);
	Items.Version.TextColor  = ?(Version  = NStr("en='Not defined'"), ErrorColor, TextColor);

	Items.SetupDriver.Enabled = Not (Driver = NStr("en='Installed'"));

EndProcedure

#EndRegion


// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
