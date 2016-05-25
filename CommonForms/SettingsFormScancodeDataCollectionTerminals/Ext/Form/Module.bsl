
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
	ListModel.Add("CipherLab CPT-711");
	ListModel.Add("CipherLab CPT-720");
	ListModel.Add("CipherLab CPT-800x");
	ListModel.Add("CipherLab CPT-8300");
	ListModel.Add("CipherLab CPT-8400");
	ListModel.Add("CipherLab CPT-8500");

	ListPort = Items.Port.ChoiceList;
	IndexOf = Undefined;
	For IndexOf = 1 To 256 Do
		ListPort.Add(IndexOf, "COM" + TrimAll(IndexOf));
	EndDo;

	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(1, "115200");
	SpeedList.Add(2, "57600");
	SpeedList.Add(3, "38400");
	SpeedList.Add(4, "19200");
	SpeedList.Add(5, "9600");
	
	ListSourceImports = Items.ImportingSource.ChoiceList;
	ListSourceImports.Add("Document", NStr("en='Data collector document'"));
	ListSourceImports.Add("Base",     NStr("en='Data collector database'"));
	
	tempPort                  = Undefined;
	tempSpeed                 = Undefined;
	tempTimeout               = Undefined;
	tempIRSupport             = Undefined;
	TempBaseSeparator         = Undefined;
	TempDocumentSeparator     = Undefined;
	tempBaseNumber            = Undefined;
	tempDocumentNumber            = Undefined;
	tempClearDocument         = Undefined;
	TempBaseFormat            = Undefined;
	TempDocumentFormat        = Undefined;
	tempModel                 = Undefined;
	tempSourceImports         = Undefined;
	
	Parameters.EquipmentParameters.Property("Port"                    , tempPort);
	Parameters.EquipmentParameters.Property("Speed"                , tempSpeed);
	Parameters.EquipmentParameters.Property("Timeout"                 , tempTimeout);
	Parameters.EquipmentParameters.Property("IRStand"             , tempIRSupport);
	Parameters.EquipmentParameters.Property("BaseSeparator"         , TempBaseSeparator);
	Parameters.EquipmentParameters.Property("DocumentSeparator"    , TempDocumentSeparator);
	Parameters.EquipmentParameters.Property("NumberBase"               , tempBaseNumber);
	Parameters.EquipmentParameters.Property("DocumentNumber"          , tempDocumentNumber);
	Parameters.EquipmentParameters.Property("ToClearDocument"         , tempClearDocument);
	Parameters.EquipmentParameters.Property("BaseFormat"              , TempBaseFormat);
	Parameters.EquipmentParameters.Property("DocumentFormat"         , TempDocumentFormat);
	Parameters.EquipmentParameters.Property("Model"                  , tempModel);
	Parameters.EquipmentParameters.Property("ImportingSource"        , tempSourceImports);
	
	Port                     = ?(tempPort                   = Undefined,          1, tempPort);
	Speed                    = ?(tempSpeed                  = Undefined,          1, tempSpeed);
	Timeout                  = ?(tempTimeout                = Undefined,        500, tempTimeout);
	IRStand                  = ?(tempIRSupport              = Undefined,       False, tempIRSupport);
	BaseSeparator            = ?(TempBaseSeparator          = Undefined,          9, TempBaseSeparator);
	DocumentSeparator        = ?(TempDocumentSeparator      = Undefined,          9, TempDocumentSeparator);
	NumberBase               = ?(tempBaseNumber             = Undefined,          1, tempBaseNumber);
	DocumentNumber               = ?(tempDocumentNumber             = Undefined,          0, tempDocumentNumber);
	ToClearDocument          = ?(tempClearDocument          = Undefined,       False, tempClearDocument);
	ImportingSource            = ?(tempSourceImports          = Undefined, "Document", tempSourceImports);
	
	If TempBaseFormat <> Undefined Then
		For Each BaseRow IN TempBaseFormat Do
			TableRow = BaseFormat.Add();
			TableRow.FieldNumber    = BaseRow.FieldNumber;
			TableRow.Description = BaseRow.Description;
		EndDo;
	EndIf;
	
	If TempDocumentFormat <> Undefined Then
		For Each DocumentRow IN TempDocumentFormat Do
			TableRow = DocumentFormat.Add();
			TableRow.FieldNumber    = DocumentRow.FieldNumber;
			TableRow.Description = DocumentRow.Description;
		EndDo;
	EndIf;
	
	Model = ?(tempModel = Undefined,  Items.Model.ChoiceList[0], tempModel);
	
	Items.SetupDriver.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);
	
	If BaseFormat.Count() = 0 Then
		FillBaseFormatByDefaultAtServer();
	EndIf;
	If DocumentFormat.Count() = 0 Then
		FillDocumentFormatByDefaultAtServer();
	EndIf;

EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateInformationAboutDriver();

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ClearMessages();
	
	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("Port"                     , Port);
	ParametersNewValue.Insert("Speed"                 , Speed);
	ParametersNewValue.Insert("Timeout"                  , Timeout);
	ParametersNewValue.Insert("IRStand"              , IRStand);
	ParametersNewValue.Insert("BaseSeparator"          , BaseSeparator);
	ParametersNewValue.Insert("DocumentSeparator"     , DocumentSeparator);
	ParametersNewValue.Insert("NumberBase"                , NumberBase);
	ParametersNewValue.Insert("DocumentNumber"           , DocumentNumber);
	ParametersNewValue.Insert("ToClearDocument"          , ToClearDocument);
	ParametersNewValue.Insert("Model"                   , Model);
	ParametersNewValue.Insert("ImportingSource"         , ImportingSource);
	
	TempBaseFormat = New Array();
	For Each TableRow IN BaseFormat Do
		NewRow = New Structure("FieldNumber, Description", TableRow.FieldNumber, TableRow.Description);
		TempBaseFormat.Add(NewRow);
	EndDo;
	ParametersNewValue.Insert("BaseFormat", TempBaseFormat);
	
	TempDocumentFormat = New Array();
	For Each TableRow IN DocumentFormat Do
		NewRow = New Structure("FieldNumber, Description", TableRow.FieldNumber, TableRow.Description);
		TempDocumentFormat.Add(NewRow);
	EndDo;
	ParametersNewValue.Insert("DocumentFormat", TempDocumentFormat);
	
	Result = New Structure;
	Result.Insert("ID", ID);
	Result.Insert("EquipmentParameters", ParametersNewValue);
	
	Close(Result);
	
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

&AtClient
Procedure DeviceTest(Command)
	
	ClearMessages();
	
	TestResult = Undefined;
	
	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"                    , Port);
	tempDeviceParameters.Insert("Speed"                   , Speed);
	tempDeviceParameters.Insert("Timeout"                 , Timeout);
	tempDeviceParameters.Insert("IRStand"                 , IRStand);
	tempDeviceParameters.Insert("BaseSeparator"           , BaseSeparator);
	tempDeviceParameters.Insert("DocumentSeparator"       , DocumentSeparator);
	tempDeviceParameters.Insert("NumberBase"              , NumberBase);
	tempDeviceParameters.Insert("DocumentNumber"              , DocumentNumber);
	tempDeviceParameters.Insert("ToClearDocument"         , ToClearDocument);
	tempDeviceParameters.Insert("Model"                   , Model);
	tempDeviceParameters.Insert("ImportingSource"           , ImportingSource);
	
	Result = EquipmentManagerClient.RunAdditionalCommand("DeviceTest",
	                                                               InputParameters,
	                                                               Output_Parameters,
	                                                               ID,
	                                                               tempDeviceParameters);
	
EndProcedure

&AtClient
Procedure FillBaseFormatByDefault(Command)
	FillBaseFormatByDefaultAtServer();
EndProcedure

&AtClient
Procedure FillDocumentFormatByDefault(Command)
	FillDocumentFormatByDefaultAtServer();
EndProcedure

&AtServer
Procedure FillBaseFormatByDefaultAtServer()
	BaseFormat.Clear();
	NewRow = BaseFormat.Add();
	NewRow.FieldNumber 		= 1;
	NewRow.Description 	= Items.BaseFormatDescription.ChoiceList[0];
	NewRow = BaseFormat.Add();
	NewRow.FieldNumber 		= 2;
	NewRow.Description 	= Items.BaseFormatDescription.ChoiceList[1];
	NewRow = BaseFormat.Add();
	NewRow.FieldNumber 		= 3;
	NewRow.Description 	= Items.BaseFormatDescription.ChoiceList[6];
	NewRow = BaseFormat.Add();
	NewRow.FieldNumber 		= 4;
	NewRow.Description 	= Items.BaseFormatDescription.ChoiceList[7];
EndProcedure

&AtServer
Procedure FillDocumentFormatByDefaultAtServer()
	DocumentFormat.Clear();
	NewRow = DocumentFormat.Add();
	NewRow.FieldNumber 		= 1;
	NewRow.Description 	= Items.DocumentFormatDescription.ChoiceList[0];
	NewRow = DocumentFormat.Add();
	NewRow.FieldNumber 		= 2;
	NewRow.Description 	= Items.DocumentFormatDescription.ChoiceList[7];
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure UpdateInformationAboutDriver()

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"                    , Port);
	tempDeviceParameters.Insert("Speed"                   , Speed);
	tempDeviceParameters.Insert("Timeout"                 , Timeout);
	tempDeviceParameters.Insert("IRStand"                 , IRStand);
	tempDeviceParameters.Insert("BaseSeparator"           , BaseSeparator);
	tempDeviceParameters.Insert("DocumentSeparator"       , DocumentSeparator);
	tempDeviceParameters.Insert("NumberBase"              , NumberBase);
	tempDeviceParameters.Insert("DocumentNumber"              , DocumentNumber);
	tempDeviceParameters.Insert("ToClearDocument"         , ToClearDocument);
	tempDeviceParameters.Insert("Model"                   , Model);
	tempDeviceParameters.Insert("ImportingSource"           , ImportingSource);
	
	TempBaseFormat = New Array();
	For Each TableRow IN BaseFormat Do
		NewRow = New Structure("FieldNumber, Description",
		                              TableRow.FieldNumber,
		                              TableRow.Description);
		TempBaseFormat.Add(NewRow);
	EndDo;
	tempDeviceParameters.Insert("BaseFormat", TempBaseFormat);

	TempDocumentFormat = New Array();
	For Each TableRow IN DocumentFormat Do
		NewRow = New Structure("FieldNumber, Description",
		                              TableRow.FieldNumber,
		                              TableRow.Description);
		TempDocumentFormat.Add(NewRow);
	EndDo;
	tempDeviceParameters.Insert("DocumentFormat", TempDocumentFormat);

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
