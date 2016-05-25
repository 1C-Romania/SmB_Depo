                                    
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
	ListModel.Add(0, "Stroke-M: ELWES-MICRO-F");
	ListModel.Add(13, "ATOL: Trium-F version 01");
	ListModel.Add(14, "ATOL: FELIX-RF version 02");
	ListModel.Add(15, "ATOL: FELIX-02K version 01");
	ListModel.Add(16, "ATOL: Mercury-140F version 02");
	ListModel.Add(16, "ATOL: MERCURY-140F version 03");
	ListModel.Add(17, "Incotex: MERCURY 114.1F version 01");
	ListModel.Add(17, "Incotex: MERCURY 114.1f version 02");
	ListModel.Add(18, "Shtrikh-M: SHTRIKH-FR-F version 03");
	ListModel.Add(18, "Shtrikh-M: SHTRIKH-FR-F version 04");
	ListModel.Add(19, "Shtrikh-M: ELVES-MINI-FR-F version 02");
	ListModel.Add(20, "ATOL: TORNADO (MERCURY-114.1 f version 04)");
	ListModel.Add(23, "ATOL: TORNADO-K (MERCURY MS-K version 02)");
	ListModel.Add(24, "ATOL: FELIX-RC version 01");
	ListModel.Add(25, "Shtrikh-M: SHTRIKH-FR-K version 01");
	ListModel.Add(26, "Shtrikh-M: ELVES-FR-K version 01");
	ListModel.Add(27, "ATOL: FELIX-3CK version 01");
	ListModel.Add(28, "Shtrikh-M: SHTRIKH-MINI-FR-K version 01");
	ListModel.Add(30, "ATOL: FPrint-02K");
	ListModel.Add(31, "ATOL: FPrint-03K");
	ListModel.Add(32, "ATOL: FPrint-88K");
	ListModel.Add(33, "ATOL: BIXOLON-01K");
	ListModel.Add(35, "ATOL: FPrint-5200K");
	ListModel.Add(41, "ATOL: PayVKP-80K");
	ListModel.Add(45, "ATOL: PayPPU-700K");
	ListModel.Add(46, "ATOL: PayCTS-2000K");
	ListModel.Add(42, "ATOL: FPrint-02KZ");
	ListModel.Add(43, "ATOL: PayVKP-80KZ");      
	ListModel.Add(47, "ATOL: FPrint-55K");
	ListModel.Add(51, "ATOL: FPrint-11K");
	ListModel.Add(52, "ATOL: FPrint-22K");
	ListModel.Add(101, "Pilot: POSPrint FP410K");
	ListModel.Add(102, "MultiSoft: MSTAR-F");
	ListModel.Add(103, "Maria-301 MTM T7");
	ListModel.Add(104, "Flash: WHEN-88TK");
	ListModel.Add(105, "Flash: WHEN-08TK");
	ListModel.Add(106, "SERVICE PLUS: SP101FR-K");
	ListModel.Add(107, "Shtrikh-M: SHTRIKH-COMBO-FR-K");
	ListModel.Add(108, "Flash: WHEN-07K");
	ListModel.Add(109, "Unisystem: MINI-FP6");
	ListModel.Add(110, "Shtrikh-M: SHTRIKH-M-FR-K");
	ListModel.Add(111, "MultiSoft: MSTAR-TK.1");
	ListModel.Add(113, "Shtrikh-M: SHTRIKH-LIGHT-FR-K");
	ListModel.Add(114, "KristallServis: PYRITE FR01K");
	ListModel.SortByPresentation();
	
	ListPort = Items.Port.ChoiceList;
	For Number = 1 To 64 Do
		ListPort.Add(Number, "COM" + Format(Number, "ND=2; NFD=0; NZ=0; NG=0"));
	EndDo;

	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(1200,   "1200");
	SpeedList.Add(2400,   "2400");
	SpeedList.Add(4800,   "4800");
	SpeedList.Add(9600,   "9600");
	SpeedList.Add(19200,  "19200");
	SpeedList.Add(38400,  "38400");
	SpeedList.Add(57600,  "57600");
	SpeedList.Add(115200, "115200");
	
	tempPort                      = Undefined;
	tempSpeed                     = Undefined;
	tempTimeout                   = Undefined;
	tempUserPassword              = Undefined;
	TempDevicePassword            = Undefined;
	TempTaxPrintInCheck           = Undefined;
	tempSectionNumber             = Undefined;
	tempPartialCuttingSymbolCode  = Undefined;
	tempModel                     = Undefined;

	Parameters.EquipmentParameters.Property("Port"                      , tempPort);
	Parameters.EquipmentParameters.Property("Speed"                  , tempSpeed);
	Parameters.EquipmentParameters.Property("Timeout"                   , tempTimeout);
	Parameters.EquipmentParameters.Property("UserPassword"        , tempUserPassword);
	Parameters.EquipmentParameters.Property("DevicePassword"          , TempDevicePassword);
	Parameters.EquipmentParameters.Property("TaxPrintInCheck"       , TempTaxPrintInCheck);
	Parameters.EquipmentParameters.Property("SectionNumber"               , tempSectionNumber);
	Parameters.EquipmentParameters.Property("PartialCuttingSymbolCode", tempPartialCuttingSymbolCode);
	Parameters.EquipmentParameters.Property("Model"                    , tempModel);

	Port                     = ?(tempPort                     = Undefined,      1, tempPort);
	Speed                    = ?(tempSpeed                    = Undefined, 115200, tempSpeed);
	Timeout                  = ?(tempTimeout                  = Undefined,    150, tempTimeout);
	UserPassword             = ?(tempUserPassword             = Undefined,   "30", tempUserPassword);
	DevicePassword           = ?(TempDevicePassword           = Undefined,    "0", TempDevicePassword);
	TaxPrintInCheck          = ?(TempTaxPrintInCheck          = Undefined,   False, TempTaxPrintInCheck);
	SectionNumber            = ?(tempSectionNumber            = Undefined,      0, tempSectionNumber);
	PartialCuttingSymbolCode = ?(tempPartialCuttingSymbolCode = Undefined,     22, tempPartialCuttingSymbolCode);
	Model                    = ?(tempModel                    = Undefined, Items.Model.ChoiceList[0].Value, tempModel);

	Items.DeviceTest.Visible    = (SessionParameters.ClientWorkplace = ID.Workplace);
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
	ParametersNewValue.Insert("Port"                       , Port);
	ParametersNewValue.Insert("Speed"                   , Speed);
	ParametersNewValue.Insert("Timeout"                    , Timeout);
	ParametersNewValue.Insert("UserPassword"         , UserPassword);
	ParametersNewValue.Insert("DevicePassword"           , DevicePassword);
	ParametersNewValue.Insert("TaxPrintInCheck"        , TaxPrintInCheck);
	ParametersNewValue.Insert("SectionNumber"                , SectionNumber);
	ParametersNewValue.Insert("PartialCuttingSymbolCode" , PartialCuttingSymbolCode);
	ParametersNewValue.Insert("Model"                     , Model);
	
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
	tempDeviceParameters.Insert("Port"                      , Port);
	tempDeviceParameters.Insert("Speed"                  , Speed);
	tempDeviceParameters.Insert("Timeout"                   , Timeout);
	tempDeviceParameters.Insert("UserPassword"        , UserPassword);
	tempDeviceParameters.Insert("DevicePassword"          , DevicePassword);
	tempDeviceParameters.Insert("TaxPrintInCheck"       , TaxPrintInCheck);
	tempDeviceParameters.Insert("SectionNumber"               , SectionNumber);
	tempDeviceParameters.Insert("PartialCuttingSymbolCode", PartialCuttingSymbolCode);
	tempDeviceParameters.Insert("Model"                    , Model);

	Result = EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
	                                                                      InputParameters,
	                                                                      Output_Parameters,
	                                                                      ID,
	                                                                      tempDeviceParameters);

	AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array")
	                           AND Output_Parameters.Count() >= 2,
	                           NStr("en = 'Additional description:'") + " " + Output_Parameters[1],
	                           "");
	If Result Then
		MessageText = NStr("en = 'Test completed successfully. %AdditionalDetails%%Linefeed%'");
		MessageText = StrReplace(MessageText, "%Linefeed%", ?(IsBlankString(AdditionalDetails),
		                                                                  "",
		                                                                  Chars.LF));
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails),
		                                                                           "",
		                                                                           AdditionalDetails));
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		MessageText = NStr("en = 'Test failed.%Linefeed% %AdditionalDetails%'");
		MessageText = StrReplace(MessageText, "%Linefeed%", ?(IsBlankString(AdditionalDetails),
		                                                                  "",
		                                                                  Chars.LF));
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails),
		                                                                           "",
		                                                                           AdditionalDetails));
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
	tempDeviceParameters.Insert("Port"                      , Port);
	tempDeviceParameters.Insert("Speed"                  , Speed);
	tempDeviceParameters.Insert("Timeout"                   , Timeout);
	tempDeviceParameters.Insert("UserPassword"        , UserPassword);
	tempDeviceParameters.Insert("DevicePassword"          , DevicePassword);
	tempDeviceParameters.Insert("TaxPrintInCheck"       , TaxPrintInCheck);
	tempDeviceParameters.Insert("SectionNumber"               , SectionNumber);
	tempDeviceParameters.Insert("PartialCuttingSymbolCode", PartialCuttingSymbolCode);
	tempDeviceParameters.Insert("Model"                    , Model);

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
