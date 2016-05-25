
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
	ListModel.Add("Datecs DPD-201");
	ListModel.Add("EPSON-compatible");
	ListModel.Add("EPSON compatible (USA)");
	ListModel.Add("Mercury AH-01");
	ListModel.Add("Mercury AH-02");
	ListModel.Add("Mercury AH-03");
	ListModel.Add("Flytech");
	ListModel.Add("GIGATEK DSP800");
	ListModel.Add("GIGATEK DSP850A");
	ListModel.Add("Stroke-FrontMaster");
	ListModel.Add("Posiflex PD2300 USB");
	ListModel.Add("IPC");
	ListModel.Add("GIGATEK DSP820");
	ListModel.Add("TEC LIUST-51");
	ListModel.Add("Demo-display");

	ListPort = Items.Port.ChoiceList;
	For Number = 1 To 64 Do // 1001 - COM1
		ListPort.Add(1000 + Number, "COM" + Format(Number, "ND=2; NFD=0; NZ=0; NG=0"));
	EndDo;
	ListPort.Add(66, "Posiflex USB");
	ListPort.Add(101, "ComProxy 1");
	ListPort.Add(102, "ComProxy 2");

	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(4,  "2400");
	SpeedList.Add(5,  "4800");
	SpeedList.Add(7,  "9600");
	SpeedList.Add(9,  "14400");
	SpeedList.Add(10, "19200");

	ParityList = Items.Parity.ChoiceList;
	ParityList.Add(0, NStr("en='No'"));
	ParityList.Add(1, NStr("en='Oddness'"));
	ParityList.Add(2, NStr("en='Parity'"));
	ParityList.Add(3, NStr("en='Installed'"));
	ParityList.Add(4, NStr("en='Reset'"));

	DataBitsList = Items.DataBits.ChoiceList;
	DataBitsList.Add(3, "7 bits");
	DataBitsList.Add(4, "8 bits");

	BitStopList = Items.StopBits.ChoiceList;
	BitStopList.Add(0, "1 bit");
	BitStopList.Add(2, "2 bits");

	ListScript = Items.Encoding.ChoiceList;
	ListScript.Add(437, NStr("en='437 (OEM - USA)'"));
	ListScript.Add(850, NStr("en='850 (OEM - multilingual Latin 1)'"));
	ListScript.Add(852, NStr("en='852 (OEM - traditional Cyrillic)'"));
	ListScript.Add(860, NStr("en='860 (OEM - Portuguese)'"));
	ListScript.Add(863, NStr("en='863 (OEM - French-Canadian)'"));
	ListScript.Add(865, NStr("en='865 (OEM - Scandinavian)'"));
	ListScript.Add(866, NStr("en='866 (OEM - Russian)'"));
	ListScript.Add(932, NStr("en='932 (ANSI/OEM - Japanese Shift-JIS)'"));
	ListScript.Add(988, "988 (ASCII)");

	ListDisplaySize = Items.DisplaySize.ChoiceList;
	ListDisplaySize.Add(0, "20x2");
	ListDisplaySize.Add(1, "16x1");
	ListDisplaySize.Add(2, "26x2");
	
	tempPort          = Undefined;
	tempSpeed         = Undefined;
	tempParity        = Undefined;
	tempDataBits      = Undefined;
	tempStopBits      = Undefined;
	TempCoding        = Undefined;
	TempExportFonts = Undefined;
	tempModel         = Undefined;
	tempDisplaySize   = Undefined;

	Parameters.EquipmentParameters.Property("Port",            tempPort);
	Parameters.EquipmentParameters.Property("Speed",        tempSpeed);
	Parameters.EquipmentParameters.Property("Parity",        tempParity);
	Parameters.EquipmentParameters.Property("DataBits",      tempDataBits);
	Parameters.EquipmentParameters.Property("StopBits",        tempStopBits);
	Parameters.EquipmentParameters.Property("Encoding",       TempCoding);
	Parameters.EquipmentParameters.Property("ImportFonts", TempExportFonts);
	Parameters.EquipmentParameters.Property("Model",          tempModel);
	Parameters.EquipmentParameters.Property("DisplaySize",   tempDisplaySize);

	Port        = ?(tempPort          = Undefined, 1001, tempPort);
	Speed       = ?(tempSpeed         = Undefined,    7, tempSpeed);
	Parity      = ?(tempParity        = Undefined,    0, tempParity);
	DataBits    = ?(tempDataBits      = Undefined,    4, tempDataBits);
	StopBits    = ?(tempStopBits      = Undefined,    0, tempStopBits);
	Encoding    = ?(TempCoding        = Undefined,  866, TempCoding);
	DisplaySize = ?(tempDisplaySize   = Undefined,    0, tempDisplaySize);
	ImportFonts   = ?(TempExportFonts = Undefined, False, TempExportFonts);
	Model       = ?(tempModel         = Undefined, Items.Model.ChoiceList[0], tempModel);

	Items.DeviceTest.Visible    = (SessionParameters.ClientWorkplace = ID.Workplace);
	Items.SetupDriver.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);

EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateInformationAboutDriver();

	SetEnabledOfItems();

EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ModelOnChange(Item)

	SetEnabledOfItems();

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ParametersNewValue = New Structure;
	
	ParametersNewValue.Insert("Port"            , Port);
	ParametersNewValue.Insert("Speed"        , Speed);
	ParametersNewValue.Insert("Parity"        , Parity);
	ParametersNewValue.Insert("DataBits"      , DataBits);
	ParametersNewValue.Insert("StopBits"        , StopBits);
	ParametersNewValue.Insert("Encoding"       , Encoding);
	ParametersNewValue.Insert("ImportFonts" , ImportFonts);
	ParametersNewValue.Insert("Model"          , Model);
	ParametersNewValue.Insert("DisplaySize"   , DisplaySize);
	
	Result = New Structure;
	Result.Insert("ID", ID);
	Result.Insert("EquipmentParameters", ParametersNewValue);
	
	Close(Result);
	
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

&AtClient
Procedure DeviceTest(Command)
	
	ClearMessages();
	
	TestResult = Undefined;

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"           , Port);
	tempDeviceParameters.Insert("Speed"       , Speed);
	tempDeviceParameters.Insert("Parity"       , Parity);
	tempDeviceParameters.Insert("DataBits"     , DataBits);
	tempDeviceParameters.Insert("StopBits"       , StopBits);
	tempDeviceParameters.Insert("Encoding"      , Encoding);
	tempDeviceParameters.Insert("ImportFonts", ImportFonts);
	tempDeviceParameters.Insert("Model"         , Model);
	tempDeviceParameters.Insert("DisplaySize"  , DisplaySize);

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
		                           NStr("en = 'Additional description:'") + " " + Output_Parameters[1],
		                           "");


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

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetEnabledOfItems()

	EnabledImportFonts = (Model = "EPSON-compatible") Or (Model = "Stroke-FrontMaster");
	EnabledPortParameters  = (Model <> "Demo-display");
	
	Items.ImportFonts.Enabled   = EnabledImportFonts;
	Items.Port.Enabled        = EnabledPortParameters;
	Items.Speed.Enabled       = EnabledPortParameters;
	Items.Parity.Enabled      = EnabledPortParameters;
	Items.DataBits.Enabled    = EnabledPortParameters;
	Items.StopBits.Enabled    = EnabledPortParameters;

EndProcedure

&AtClient
Procedure UpdateInformationAboutDriver()

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"           , Port);
	tempDeviceParameters.Insert("Speed"       , Speed);
	tempDeviceParameters.Insert("Parity"       , Parity);
	tempDeviceParameters.Insert("DataBits"     , DataBits);
	tempDeviceParameters.Insert("StopBits"       , StopBits);
	tempDeviceParameters.Insert("Encoding"      , Encoding);
	tempDeviceParameters.Insert("ImportFonts", ImportFonts);
	tempDeviceParameters.Insert("Model"         , Model);
	tempDeviceParameters.Insert("DisplaySize"  , DisplaySize);

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
