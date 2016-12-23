
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;

	Parameters.Property("ID", ID);
	Parameters.Property("HardwareDriver", HardwareDriver);
	
	Title = NStr("en='Equipment:';ru='Оборудование:'") + Chars.NBSp + String(ID);
	
	TextColor = StyleColors.FormTextColor;
	ErrorColor = StyleColors.NegativeTextColor;

	ListPort = Items.Port.ChoiceList;
	ListPort.Add(100, NStr("en='<Keyboard>';ru='<Keyboard>'"));
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
	DataBitList.Add(3, NStr("en='7 bits';ru='7 бит'"));
	DataBitList.Add(4, NStr("en='8 bits';ru='8 бит'"));
	
	StopBitList = Items.StopBit.ChoiceList;
	StopBitList.Add(0, NStr("en='1 stop-bit';ru='1 стоп-бит'"));
	StopBitList.Add(2, NStr("en='2 stop-bits';ru='2 стоп-бита'"));
	
	ParityList = Items.Parity.ChoiceList;
	ParityList.Add(0, NStr("en='No';ru='Нет'"));
	ParityList.Add(1, NStr("en='Oddness';ru='Нечетность'"));
	ParityList.Add(2, NStr("en='Parity';ru='Четность'"));
	ParityList.Add(3, NStr("en='Installed';ru='Установлен'"));
	ParityList.Add(4, NStr("en='Reset';ru='Сброшен'"));
	
	tempPort             = Undefined;
	tempSpeed         = Undefined;
	tempDataBit        = Undefined;
	tempStopBit          = Undefined;
	tempParity         = Undefined;
	tempSensitivity = Undefined;
	tempModel           = Undefined;
	
	Parameters.EquipmentParameters.Property("Port"            , tempPort);
	Parameters.EquipmentParameters.Property("Speed"        , tempSpeed);
	Parameters.EquipmentParameters.Property("DataBit"       , tempDataBit);
	Parameters.EquipmentParameters.Property("StopBit"         , tempStopBit);
	Parameters.EquipmentParameters.Property("Parity"        , tempParity);
	Parameters.EquipmentParameters.Property("Sensitivity", tempSensitivity);
	Parameters.EquipmentParameters.Property("Model"          , tempModel);

	Port             = ?(tempPort             = Undefined,         1, tempPort);
	Speed         = ?(tempSpeed         = Undefined,         7, tempSpeed);
	DataBit        = ?(tempDataBit        = Undefined,         3, tempDataBit);
	StopBit          = ?(tempStopBit          = Undefined,         0, tempStopBit);
	Parity         = ?(tempParity         = Undefined,         0, tempParity);
	Sensitivity = ?(tempSensitivity = Undefined,        30, tempSensitivity);
	Model           = ?(tempModel           = Undefined, Items.Model.ChoiceList[0], tempModel);

	TempTracksParameters = Undefined;
	If Not Parameters.Property("TracksParameters", TempTracksParameters) Then
		TempTracksParameters = New Array();
		For IndexOf = 1 To 3 Do
			NewRow = New Structure();
			NewRow.Insert("TrackNumber", IndexOf);
			NewRow.Insert("Prefix"     , "");
			NewRow.Insert("Suffix"     , ?(IndexOf = 2, "#13", ""));
			NewRow.Insert("Use", ?(IndexOf = 2, True, False));
			TempTracksParameters.Add(NewRow);
		EndDo;
	EndIf;

	For Each StringPaths IN TempTracksParameters Do
		NewRow = TracksParameters.Add();
		NewRow.TrackNumber = StringPaths.TrackNumber;
		NewRow.Prefix      = StringPaths.Prefix;
		NewRow.Suffix      = StringPaths.Suffix;
		NewRow.Use = StringPaths.Use;
	EndDo;
	
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

	Items.Speed.Enabled  = (Port <> 100);
	Items.DataBit.Enabled = (Port <> 100);
	Items.StopBit.Enabled   = (Port <> 100);
	Items.Parity.Enabled  = (Port <> 100);

EndProcedure

&AtClient
Procedure PrefixChoiceProcessing(Item, ValueSelected, StandardProcessing)

	If ValueSelected <> Undefined Then
		Items.TracksParameters.CurrentData.Prefix = 
		    Items.TracksParameters.CurrentData.Prefix + ValueSelected;
	EndIf;
	StandardProcessing = False;

EndProcedure

&AtClient
Procedure SuffixChoiceProcessing(Item, ValueSelected, StandardProcessing)

	If ValueSelected <> Undefined Then
		Items.TracksParameters.CurrentData.Suffix = 
		    Items.TracksParameters.CurrentData.Suffix + ValueSelected;
	EndIf;
	StandardProcessing = False;

EndProcedure

&AtClient
Procedure TrackParametersOnActivateCell(Item)
	
	If (Item.CurrentItem.Name = "Prefix" Or Item.CurrentItem.Name = "Suffix")
		AND Item.CurrentItem.ChoiceList.Count() = 0 Then
		
		ListTrackParameters = Item.CurrentItem.ChoiceList;
		
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

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ClearMessages();
	
	LaneSetup = 0;
	TrackWithEmptySuffix = False;
	TempTracksParameters = New Array();

	For IndexOf = 1 To 3 Do
		If TracksParameters[3 - IndexOf].Use = True Then
			TrackWithEmptySuffix = TrackWithEmptySuffix OR (TracksParameters[3 - IndexOf].Suffix = "");
			LaneSetup = LaneSetup + 1;
		EndIf;
	EndDo;

	If Not TrackWithEmptySuffix Then
		For IndexOf = 1 To 3 Do
			NewRow = New Structure();
			NewRow.Insert("TrackNumber", TracksParameters[IndexOf - 1].TrackNumber);
			NewRow.Insert("Use", TracksParameters[IndexOf - 1].Use);
			NewRow.Insert("Prefix"     , TracksParameters[IndexOf - 1].Prefix);
			NewRow.Insert("Suffix"     , TracksParameters[IndexOf - 1].Suffix);
			TempTracksParameters.Add(NewRow);
		EndDo;
	EndIf;

	If LaneSetup > 0 AND Not TrackWithEmptySuffix Then
		
		ParametersNewValue = New Structure;
		ParametersNewValue.Insert("Port"             , Port);
		ParametersNewValue.Insert("Speed"         , Speed);
		ParametersNewValue.Insert("DataBit"        , DataBit);
		ParametersNewValue.Insert("StopBit"          , StopBit);
		ParametersNewValue.Insert("Parity"         , Parity);
		ParametersNewValue.Insert("Sensitivity" , Sensitivity);
		ParametersNewValue.Insert("TracksParameters" , TempTracksParameters);
		ParametersNewValue.Insert("Model"           , Model);
		
		Result = New Structure;
		Result.Insert("ID", ID);
		Result.Insert("EquipmentParameters", ParametersNewValue);
		
		Close(Result);
		
	ElsIf LaneSetup = 0 Then
		MessageText = NStr("en='It is necessary to specify at least one track for the reader.';ru='Необходимо указать использование хотя бы одной дорожки для считывателя.'");
		CommonUseClientServer.MessageToUser(MessageText);
	ElsIf TrackWithEmptySuffix Then
		MessageText = NStr("en='For the each used track must be specified not the blank suffix.';ru='Для каждой используемой дорожки должен быть указан не пустой суффикс.'");
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
	tempDeviceParameters.Insert("Port"            , Port);
	tempDeviceParameters.Insert("Speed"        , Speed);
	tempDeviceParameters.Insert("DataBit"       , DataBit);
	tempDeviceParameters.Insert("StopBit"         , StopBit);
	tempDeviceParameters.Insert("Parity"        , Parity);
	tempDeviceParameters.Insert("Sensitivity", Sensitivity);
	tempDeviceParameters.Insert("TracksParameters", New Array());
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
		Version  = NStr("en='Not defined';ru='Не определена'");
	EndIf;

	Items.Driver.TextColor = ?(Driver = NStr("en='Not set';ru='Не установлен'"), ErrorColor, TextColor);
	Items.Version.TextColor  = ?(Version  = NStr("en='Not defined';ru='Не определена'"), ErrorColor, TextColor);

EndProcedure

#EndRegion













