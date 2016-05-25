
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
	
	ListPort = Items.Port.ChoiceList;
	ListPort.Add(100, NStr("en='<Keyboard>'"));
	For IndexOf = 1 To 64 Do
		ListPort.Add(IndexOf, "COM" + TrimAll(IndexOf));
	EndDo;
	
	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(1,  "300");
	SpeedList.Add(2,  "600");
	SpeedList.Add(3,  "1200");
	SpeedList.Add(4,  "2400");
	SpeedList.Add(5,  "4800");
	SpeedList.Add(7,  "9600");
	SpeedList.Add(9,  "14400");
	SpeedList.Add(10, "19200");
	SpeedList.Add(12, "38400");
	
	DataBitList = Items.DataBit.ChoiceList;
	DataBitList.Add(3, NStr("en='7 bits'"));
	DataBitList.Add(4, NStr("en='8 bits'"));
	
	StopBitList = Items.StopBit.ChoiceList;
	StopBitList.Add(0, NStr("en='1 stop-bit'"));
	StopBitList.Add(2, NStr("en='2 stop-bits'"));
	
	ParityList = Items.Parity.ChoiceList;
	ParityList.Add(0, NStr("en='No'"));
	ParityList.Add(1, NStr("en='Oddness'"));
	ParityList.Add(2, NStr("en='Parity'"));
	ParityList.Add(3, NStr("en='Installed'"));
	ParityList.Add(4, NStr("en='Reset'"));
	
	SetBarcodeParameters(Items.Prefix);
	SetBarcodeParameters(Items.Suffix);

	tempPort             = Undefined;
	tempSpeed         = Undefined;
	tempDataBit        = Undefined;
	tempStopBit          = Undefined;
	tempParity         = Undefined;
	tempSensitivity = Undefined;
	tempPrefix          = Undefined;
	tempSuffix          = Undefined;
	tempModel           = Undefined;

	Parameters.EquipmentParameters.Property("Port"             , tempPort);
	Parameters.EquipmentParameters.Property("Speed"         , tempSpeed);
	Parameters.EquipmentParameters.Property("DataBit"        , tempDataBit);
	Parameters.EquipmentParameters.Property("StopBit"          , tempStopBit);
	Parameters.EquipmentParameters.Property("Parity"         , tempParity);
	Parameters.EquipmentParameters.Property("Sensitivity" , tempSensitivity);
	Parameters.EquipmentParameters.Property("Prefix"          , tempPrefix);
	Parameters.EquipmentParameters.Property("Suffix"          , tempSuffix);
	Parameters.EquipmentParameters.Property("Model"           , tempModel);

	Port             = ?(tempPort             = Undefined,     1, tempPort);
	Speed         = ?(tempSpeed         = Undefined,     7, tempSpeed);
	DataBit        = ?(tempDataBit        = Undefined,     3, tempDataBit);
	StopBit          = ?(tempStopBit          = Undefined,     0, tempStopBit);
	Parity         = ?(tempParity         = Undefined,     0, tempParity);
	Sensitivity = ?(tempSensitivity = Undefined,    30, tempSensitivity);
	Prefix          = ?(tempPrefix          = Undefined,    "", tempPrefix);
	Suffix          = ?(tempSuffix          = Undefined, "#13", tempSuffix);
	
	Model = ?(tempModel = Undefined, Items.Model.ChoiceList[0], tempModel);
	
	Items.SetupDriver.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateInformationAboutDriver();

	PortOnChange();

EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PortOnChange()

	Items.Speed.Enabled  = Port <> 100;
	Items.DataBit.Enabled = Port <> 100;
	Items.StopBit.Enabled   = Port <> 100;
	Items.Parity.Enabled  = Port <> 100;

EndProcedure

&AtClient
Procedure PrefixChoiceProcessing(Item, ValueSelected, StandardProcessing)

	StandardProcessing = False;

	If ValueSelected <> Undefined Then
		Prefix = Prefix + ValueSelected;
	EndIf;

EndProcedure

&AtClient
Procedure SuffixChoiceProcessing(Item, ValueSelected, StandardProcessing)

	StandardProcessing = False;

	If ValueSelected <> Undefined Then
		Suffix = Suffix + ValueSelected;
	EndIf;

EndProcedure

&AtClient
Procedure PortOnChange1(Item)

	PortOnChange();

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ClearMessages();
		
	If Suffix <> "" Then
		
		ParametersNewValue = New Structure;
		ParametersNewValue.Insert("Port"             , Port);
		ParametersNewValue.Insert("Speed"         , Speed);
		ParametersNewValue.Insert("DataBit"        , DataBit);
		ParametersNewValue.Insert("StopBit"          , StopBit);
		ParametersNewValue.Insert("Parity"         , Parity);
		ParametersNewValue.Insert("Sensitivity" , Sensitivity);
		ParametersNewValue.Insert("Prefix"          , Prefix);
		ParametersNewValue.Insert("Suffix"          , Suffix);
		ParametersNewValue.Insert("Model"           , Model);
		
		Result = New Structure;
		Result.Insert("ID", ID);
		Result.Insert("EquipmentParameters", ParametersNewValue);
		
		Close(Result);
		
	Else
		MessageText = NStr("en = 'Barcode scanner suffix is not specified. Suffix must be specified to identify the barcode.'");
		CommonUseClientServer.MessageToUser(MessageText, , "Suffix");
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

&AtServer
Procedure SetBarcodeParameters(Item)

	If (Item.Name = "Prefix"
	 Or Item.Name = "Suffix")
	   AND Item.ChoiceList.Count() = 0 Then
		ListTrackParameters = Item.ChoiceList;

		For ItemCode = 0 To 127 Do
			TrackChar = "";
			If ItemCode > 32 Then
				TrackChar = " ( " + Char(ItemCode) + " )";
			ElsIf ItemCode = 8 Then
				TrackChar = " (BACKSPACE)";
			ElsIf ItemCode = 9 Then
				TrackChar = " (TAB)";
			ElsIf ItemCode = 10 Then
				TrackChar = " (LF)";
			ElsIf ItemCode = 13 Then
				TrackChar = " (CR)";
			ElsIf ItemCode = 16 Then
				TrackChar = " (SHIFT)";
			ElsIf ItemCode = 17 Then
				TrackChar = " (CONTROL)";
			ElsIf ItemCode = 18 Then
				TrackChar = " (ALT)";
			ElsIf ItemCode = 27 Then
				TrackChar = " (ESCAPE)";
			ElsIf ItemCode = 32 Then
				TrackChar = " (SPACE)";
			EndIf;
			ListTrackParameters.Add("#" + TrimAll(ItemCode), "#" + TrimAll(ItemCode) + TrackChar);
		EndDo;
	EndIf;

EndProcedure

&AtClient
Procedure UpdateInformationAboutDriver()

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"            , Port);
	tempDeviceParameters.Insert("Speed"        , Speed);
	tempDeviceParameters.Insert("DataBit"       , DataBit);
	tempDeviceParameters.Insert("StopBit"         , StopBit);
	tempDeviceParameters.Insert("Parity"        , Parity);
	tempDeviceParameters.Insert("Sensitivity", Sensitivity);
	tempDeviceParameters.Insert("Prefix"         , Prefix);
	tempDeviceParameters.Insert("Suffix"         , Suffix);
	tempDeviceParameters.Insert("Model"          , Model);

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
