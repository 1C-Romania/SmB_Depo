
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
	ListModel.Add("0",  "BP 4149");
	ListModel.Add("1",  "BP 4900");
	ListModel.Add("2",  "Stroke VT");
	ListModel.Add("3",  "Stroke AS");
	ListModel.Add("4",  "STROKE-PRINT protocol CAS LP v.1.5");
	ListModel.Add("04",  "CAS LP v.1.5");
	ListModel.Add("5",  "Stroke AS POS");
	ListModel.Add("6",  "Stroke AS mini POS");
	ListModel.Add("7",  "CAS AP");
	ListModel.Add("8",  "CAS AD");
	ListModel.Add("9",  "CAS SC");
	ListModel.Add("10", "CAS S-2000");
	ListModel.Add("11", "PetWeight Series E");
	ListModel.Add("12", "Tenzo TV-003/05D");
	ListModel.Add("13", "Bolet MD-991");
	ListModel.Add("14", "Weight-K series PV");
	ListModel.Add("15", "MassaK series VT, VTM");
	ListModel.Add("16", "MassaK series MK-A, MK-T");
	ListModel.Add("17", "Measure (Oka) up to 30 kg");
	ListModel.Add("18", "Measure (Oka) to 150 kg");
	ListModel.Add("19", "ACOM PC100W");
	ListModel.Add("20", "ACOM PC100");
	ListModel.Add("21", "ACOM SI-1");
	ListModel.Add("22", "CAS ER");
	ListModel.Add("23", "CAS LP v.1.6");
	ListModel.Add("023", "CAS LP v.2.0");
	ListModel.Add("24", "Mettler Toledo 8217");
	ListModel.Add("25", "Stroke VM100");
	ListModel.Add("26", "Measure (9 bytes) up to 30 kg");
	ListModel.Add("27", "Measure (9 bytes) up to 150 kg");
	// Added       
	ListModel.Add("28", "CAS BW");
	ListModel.Add("29", "MassaK series MK-TV, MK-TN, TV-A");
	ListModel.Add("30", "Mettler Toledo Tiger E");
	ListModel.Add("31", "DIGI DS-788");
	ListModel.Add("32", "MERCURY 314/315");
	ListModel.Add("33", "CAS PDS");
	ListModel.Add("34", "DIGI DS");
	
	ListPort = Items.Port.ChoiceList;
	For Number = 1 To 64 Do
		ListPort.Add(Number, "COM" + Format(Number, "ND=2; NFD=0; NZ=0; NG=0"));
	EndDo;
	
	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(3,  "1200");
	SpeedList.Add(4,  "2400");
	SpeedList.Add(5,  "4800");
	SpeedList.Add(7,  "9600");
	SpeedList.Add(9,  "14400");
	SpeedList.Add(10, "19200");
	
	ParityList = Items.Parity.ChoiceList;
	ParityList.Add(0, NStr("en='No'"));
	ParityList.Add(1, NStr("en='Oddness'"));
	ParityList.Add(2, NStr("en='Parity'"));
	
	tempPort            = Undefined;
	tempSpeed        = Undefined;
	tempParity        = Undefined;
	tempModel          = Undefined;
	tempDescription    = Undefined;
	curDecimalPoint = Undefined;

	Parameters.EquipmentParameters.Property("Port"           , tempPort);
	Parameters.EquipmentParameters.Property("Speed"       , tempSpeed);
	Parameters.EquipmentParameters.Property("Parity"       , tempParity);
	Parameters.EquipmentParameters.Property("Model"         , tempModel);
	Parameters.EquipmentParameters.Property("Description"   , tempDescription);
	Parameters.EquipmentParameters.Property("DecimalPoint", curDecimalPoint);
	
	Port            = ?(tempPort            = Undefined, 1, tempPort);
	Speed        = ?(tempSpeed        = Undefined, 7, tempSpeed);
	Parity        = ?(tempParity        = Undefined, 0, tempParity);
	Model          = ?(tempModel          = Undefined, Items.Model.ChoiceList[0].Value, tempModel);
	DecimalPoint = ?(curDecimalPoint = Undefined, 0, curDecimalPoint);
	Description    = ?(tempDescription    = Undefined, Items.Model.ChoiceList[0].Presentation, tempDescription);
	
	Items.DeviceTest.Visible    = (SessionParameters.ClientWorkplace = ID.Workplace);
	Items.SetupDriver.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateInformationAboutDriver();

EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ModelChoiceProcessing(Item, ValueSelected, StandardProcessing)

	Description = Items.Model.ChoiceList.FindByValue(ValueSelected).Presentation;

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("Port"           , Port);
	ParametersNewValue.Insert("Speed"       , Speed);
	ParametersNewValue.Insert("Parity"       , Parity);
	ParametersNewValue.Insert("Model"         , Model);
	ParametersNewValue.Insert("Description"   , Description);
	ParametersNewValue.Insert("DecimalPoint", DecimalPoint);
	
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
	tempDeviceParameters.Insert("Model"         , Model);
	tempDeviceParameters.Insert("Description"   , Description);
	tempDeviceParameters.Insert("DecimalPoint", DecimalPoint);
	
	Result = EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
	                                                                      InputParameters,
	                                                                      Output_Parameters,
	                                                                      ID,
	                                                                      tempDeviceParameters);
	  
	AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array") AND Output_Parameters.Count(),
	                           NStr("en = 'Additional description:'") + " " + Output_Parameters[1], "");
	If Result Then
		MessageText = NStr("en = 'Test completed successfully. %AdditionalDetails%%Linefeed%'");
		MessageText = StrReplace(MessageText, "%Linefeed%", ?(IsBlankString(AdditionalDetails), "", Chars.LF));
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails), "", AdditionalDetails));
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		MessageText = NStr("en = 'Test failed.%Linefeed% %AdditionalDetails%'");
		MessageText = StrReplace(MessageText, "%Linefeed%", ?(IsBlankString(AdditionalDetails), "", Chars.LF));
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails), "", AdditionalDetails));
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
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
	tempDeviceParameters.Insert("Parity"       , Parity);
	tempDeviceParameters.Insert("Model"         , Model);
	tempDeviceParameters.Insert("Description"   , Description);
	tempDeviceParameters.Insert("DecimalPoint", DecimalPoint);
	
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
