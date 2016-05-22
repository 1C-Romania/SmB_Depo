
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
	ListModel.Add("0", "Zebex PDL-20");
	ListModel.Add("00", "Zebex PDC-10");
	ListModel.Add("000", "Zebex PDL-10");
	ListModel.Add("0000", "Zebex PDW-10");
	ListModel.Add("00000", "Zebex PDM-10");
	ListModel.Add("000000", "Zebex PDT-10");
	ListModel.Add("1", "Zebex Z-1050 (ATOL technology)");
	ListModel.Add("3", "Cipher CPT-711 (connection with PC through cable)");
	ListModel.Add("03", "Cipher CPT-720 (connection with PC through cable)");
	ListModel.Add("003", "Cipher CPT-8300 (connection with PC through cable)");
	ListModel.Add("4", "Cipher CPT-800x (connection with PC through IR supply)");
	ListModel.Add("04", "Cipher CPT-8300 (connection with PC through IR supply)");
	ListModel.Add("5", "Cipher CPT-3510 for series CPT-8x1x");
	ListModel.Add("6", "Zebex Z-2030");
	ListModel.Add("7", "Terminals with WinCE/PocketPC/Windows Mobile and installed ATOL:Mobile Logistics software");
	ListModel.Add("07", "Symbol SPT-1800 terminals with and installed ATOL:Mobile Logistics software");
	ListModel.Add("007", "Symbol SPT-1550 terminals with and installed ATOL:Mobile Logistics software");
	ListModel.Add("8", "Cipher CPT-8x00 (connection with PC through supply)");
	ListModel.Add("9", "Casio DT-900/DT-930");
	ListModel.Add("09", "Cipher CPT-800x/8300 (connection with PC through wire)");
	ListModel.Add("10", "MobileLogistics 4.x");
	
	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(1,     "300 baud");
	SpeedList.Add(2,     "600 baud");
	SpeedList.Add(3,    "1200 baud");
	SpeedList.Add(4,    "2400 baud");
	SpeedList.Add(5,    "4800 baud");
	SpeedList.Add(7,    "9600 baud");
	SpeedList.Add(10,  "19200 baud");
	SpeedList.Add(12,  "38400 baud");
	SpeedList.Add(14,  "57600 baud");
	SpeedList.Add(18, "115200 baud");
	
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
	
	tempPort           = Undefined;
	tempSpeed          = Undefined;
	tempIPPort         = Undefined;
	tempParity         = Undefined;
	tempDataBits       = Undefined;
	tempStopBits       = Undefined;
	tempExportingTable    = Undefined;
	tempImportingTable      = Undefined;
	TempSeparator      = Undefined;
	tempExportFormat = Undefined;
	tempImportFormat   = Undefined;
	tempModel          = Undefined;
	tempDescription    = Undefined;

	Parameters.EquipmentParameters.Property("Port"           , tempPort);
	Parameters.EquipmentParameters.Property("Speed"          , tempSpeed);
	Parameters.EquipmentParameters.Property("IPPort"         , tempIPPort);
	Parameters.EquipmentParameters.Property("Parity"         , tempParity);
	Parameters.EquipmentParameters.Property("DataBits"       , tempDataBits);
	Parameters.EquipmentParameters.Property("StopBits"       , tempStopBits);
	Parameters.EquipmentParameters.Property("ExportingTable"  , tempExportingTable);
	Parameters.EquipmentParameters.Property("ImportingTable"      , tempImportingTable);
	Parameters.EquipmentParameters.Property("Delimiter"      , TempSeparator);
	Parameters.EquipmentParameters.Property("ExportFormat" , tempExportFormat);
	Parameters.EquipmentParameters.Property("ImportFormat"   , tempImportFormat);
	Parameters.EquipmentParameters.Property("Model"          , tempModel);
	Parameters.EquipmentParameters.Property("Description"    , tempDescription);
	
	Port            = ?(tempPort         = Undefined, 1, tempPort);
	Speed           = ?(tempSpeed        = Undefined, 7, tempSpeed);
	IPPort          = ?(tempIPPort       = Undefined, 0, tempIPPort);
	Parity          = ?(tempParity       = Undefined, 0, tempParity);
	DataBits        = ?(tempDataBits     = Undefined, 4, tempDataBits);
	StopBits        = ?(tempStopBits     = Undefined, 0, tempStopBits);
	ExportingTable   = ?(tempExportingTable  = Undefined, 0, tempExportingTable);
	ImportingTable       = ?(tempImportingTable    = Undefined, 0, tempImportingTable);
	Delimiter       = ?(TempSeparator    = Undefined, 0, TempSeparator);

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

	Model       = ?(tempModel       = Undefined, Items.Model.ChoiceList[0].Value     , tempModel);
	Description = ?(tempDescription = Undefined, Items.Model.ChoiceList[0].Presentation, tempDescription);
	
	Items.DeviceTest.Visible    = (SessionParameters.ClientWorkplace = ID.Workplace);
	Items.SetupDriver.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateInformationAboutDriver();
	UpdateAvailablePorts();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ModelOnChange(Item)
	
	UpdateAvailablePorts();
	
EndProcedure

&AtClient
Procedure SeparatorOnChange(Item)
	
	SeparatorChar = Char(Delimiter);
	
EndProcedure

&AtClient
Procedure SeparatorSymbolOnChange(Item)
	
	Delimiter = CharCode(SeparatorChar);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("Port"            , Port);
	ParametersNewValue.Insert("Speed"        , Speed);
	ParametersNewValue.Insert("IPPort"          , IPPort);
	ParametersNewValue.Insert("Parity"        , Parity);
	ParametersNewValue.Insert("DataBits"      , DataBits);
	ParametersNewValue.Insert("StopBits"        , StopBits);
	ParametersNewValue.Insert("ExportingTable" , ExportingTable);
	ParametersNewValue.Insert("ImportingTable" , ImportingTable);
	ParametersNewValue.Insert("Delimiter"     , Delimiter);
	ParametersNewValue.Insert("Model"          , Model);
	ParametersNewValue.Insert("Description"    , Description);
	
	tempExportFormat = New Array();
	For Each TableRow IN ExportFormat Do
		NewRow = New Structure("FieldNumber, Description", TableRow.FieldNumber, TableRow.Description);
		tempExportFormat.Add(NewRow);
	EndDo;
	ParametersNewValue.Insert("ExportFormat", tempExportFormat);
	
	tempImportFormat = New Array();
	For Each TableRow IN ImportFormat Do
		NewRow = New Structure("FieldNumber, Description", TableRow.FieldNumber, TableRow.Description);
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
	tempDeviceParameters.Insert("IPPort"         , IPPort);
	tempDeviceParameters.Insert("Parity"       , Parity);
	tempDeviceParameters.Insert("DataBits"     , DataBits);
	tempDeviceParameters.Insert("StopBits"       , StopBits);
	tempDeviceParameters.Insert("ExportingTable", ExportingTable);
	tempDeviceParameters.Insert("ImportingTable", ImportingTable);
	tempDeviceParameters.Insert("Delimiter"    , Delimiter);
	tempDeviceParameters.Insert("Model"         , Model);
	tempDeviceParameters.Insert("Description"   , Description);

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
Procedure DriverSettingEnd(Result, Parameters) Export 
	
	If Result = DialogReturnCode.Yes Then
		DriverImportAddress = "http://atol-global.com/exports/";
		GotoURL(DriverImportAddress);
	EndIf;
	
EndProcedure 

&AtClient
Procedure SetupDriver(Command)

	ClearMessages();
	Text = NStr("en = 'Software is installed with the help of the supplier's distribution.
		|Go to the supplier's site for exporting?'");
	Notification = New NotifyDescription("DriverSettingEnd",  ThisObject);
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
	
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
	tempDeviceParameters.Insert("IPPort"         , IPPort);
	tempDeviceParameters.Insert("Parity"       , Parity);
	tempDeviceParameters.Insert("DataBits"     , DataBits);
	tempDeviceParameters.Insert("StopBits"       , StopBits);
	tempDeviceParameters.Insert("ExportingTable", ExportingTable);
	tempDeviceParameters.Insert("ImportingTable", ImportingTable);
	tempDeviceParameters.Insert("Delimiter"    , Delimiter);
	tempDeviceParameters.Insert("Model"         , Model);
	tempDeviceParameters.Insert("Description"   , Description);

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

&AtClient
Procedure UpdateAvailablePorts()

	Items.Port.ChoiceList.Clear();
	LstPort = Items.Port.ChoiceList;
	For IndexOf = 1 To 64 Do
		LstPort.Add(IndexOf, "COM" + TrimAll(IndexOf));
	EndDo;

	If Number(Model) = 7 Then
		LstPort.Add(65,  "USB");
		LstPort.Add(101, "TCP/IP");
		LstPort.Add(102, "IRComm (client)");
	ElsIf Number(Model) = 9 Then
		LstPort.Add(103, "IRComm (server)");
	ElsIf Number(Model) = 10 Then
		LstPort.Add(65,  "USB");
		LstPort.Add(101, "TCP/IP");
		LstPort.Add(102, "IRComm (client)");
		LstPort.Add(103, "IRComm (server)");
	EndIf;

	If LstPort.FindByValue(Port) = Undefined Then
		Port = 1;
	EndIf;

EndProcedure

#EndRegion