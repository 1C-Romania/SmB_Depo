
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;

	Parameters.Property("ID", ID);
	Parameters.Property("HardwareDriver", HardwareDriver);
	
	Title = NStr("en='Equipment:';ru='Оборудование:'") + Chars.NBSp  + String(ID);
	
	TextColor = StyleColors.FormTextColor;
	ErrorColor = StyleColors.NegativeTextColor;

	ListPort = Items.Port.ChoiceList;
	ListPort.Add(0, NStr("en='<Keyboard>';ru='<Keyboard>'"));
	For Number = 1 To 64 Do
		ListPort.Add(Number, "COM" + Format(Number, "ND=2; NFD=0; NZ=0; NG=0"));
	EndDo;

	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(110,    "110");
	SpeedList.Add(300,    "300");
	SpeedList.Add(600,    "600");
	SpeedList.Add(1200,   "1200");
	SpeedList.Add(2400,   "2400");
	SpeedList.Add(4800,   "4800");
	SpeedList.Add(9600,   "9600");
	SpeedList.Add(14400,  "14400");
	SpeedList.Add(19200,  "19200");
	SpeedList.Add(38400,  "38400");
	SpeedList.Add(56000,  "56000");
	SpeedList.Add(57600,  "57600");
	SpeedList.Add(115200, "115200");
	SpeedList.Add(128000, "128000");
	SpeedList.Add(256000, "256000");

	DataBitList = Items.DataBit.ChoiceList;
	For IndexOf = 1 To 8 Do
		DataBitList.Add(IndexOf, TrimAll(IndexOf));
	EndDo;

	StopBitList = Items.StopBit.ChoiceList;
	StopBitList.Add(0, NStr("en='1 stop-bit';ru='1 стоп-бит'"));
	StopBitList.Add(1, NStr("en='1.5 of the stop-bit';ru='1.5 стоп-бита'"));
	StopBitList.Add(2, NStr("en='2 stop-bits';ru='2 стоп-бита'"));

	tempPort      = Undefined;
	tempSpeed  = Undefined;
	tempDataBit = Undefined;
	tempStopBit   = Undefined;
	tempTimeout   = Undefined;
	
	Parameters.EquipmentParameters.Property("Port",      tempPort);
	Parameters.EquipmentParameters.Property("Speed",  tempSpeed);
	Parameters.EquipmentParameters.Property("DataBit", tempDataBit);
	Parameters.EquipmentParameters.Property("StopBit",   tempStopBit);
	Parameters.EquipmentParameters.Property("Timeout",   tempTimeout);
	
	Port        = ?(tempPort      = Undefined,         1, tempPort);
	Speed    = ?(tempSpeed  = Undefined,      9600, tempSpeed);
	DataBit   = ?(tempDataBit = Undefined,         8, tempDataBit);
	StopBit     = ?(tempStopBit   = Undefined,         0, tempStopBit);
	Timeout     = ?(tempTimeout   = Undefined,        75, tempTimeout);
	
	TempTracksParameters = Undefined;
	If Not Parameters.EquipmentParameters.Property("TracksParameters", TempTracksParameters) Then
		TempTracksParameters = New Array();
		For IndexOf = 1 To 3 Do
			NewRow = New Structure();
			NewRow.Insert("TrackNumber", IndexOf);
			NewRow.Insert("Prefix"     , 0);
			NewRow.Insert("Suffix"     , ?(IndexOf = 2, 13, 0));
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
	
	Items.DeviceTest.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);
	Items.SetupDriver.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateInformationAboutDriver();

	CustomizeControlElements();

EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PortOnChange()
	
	CustomizeControlElements();
	
EndProcedure

&AtClient
Procedure TrackParametersOnActivateCell(Item)

	If (Item.CurrentItem.Name = "Prefix"
	 Or Item.CurrentItem.Name = "Suffix")
	   AND Item.CurrentItem.ChoiceList.Count() = 0 Then
		ListTracksParameters = Item.CurrentItem.ChoiceList;

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
			ListTracksParameters.Add(ItemCode, String(ItemCode) + TrackChar);
		EndDo;
	EndIf;

EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtClient
Procedure WriteAndCloseExecute()

	LaneSetup = 0;
	TrackWithEmptySuffix = False;
	TempTracksParameters = New Array();

	For IndexOf = 1 To 3 Do
		If TracksParameters[3 - IndexOf].Use = True Then
			TrackWithEmptySuffix =
			    TrackWithEmptySuffix OR (TracksParameters[3 - IndexOf].Suffix = 0);
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
		
		ClearMessages();
		
		ParametersNewValue = New Structure;
		ParametersNewValue.Insert("Port"      , Port);
		ParametersNewValue.Insert("Speed"  , Speed);
		ParametersNewValue.Insert("DataBit" , DataBit);
		ParametersNewValue.Insert("StopBit"   , StopBit);
		ParametersNewValue.Insert("Timeout"   , Timeout);
		ParametersNewValue.Insert("TracksParameters", TempTracksParameters);
		
		Result = New Structure;
		Result.Insert("ID", ID);
		Result.Insert("EquipmentParameters", ParametersNewValue);
		
		Close(Result);
		
	ElsIf LaneSetup = 0 Then
		MessageText = NStr("en='At least one track is required for the reader';ru='Необходимо указать использование хотя бы одной дорожки для считывателя'");
		CommonUseClientServer.MessageToUser(MessageText);
	ElsIf TrackWithEmptySuffix Then
		MessageText = NStr("en='A suffix not equal to 0 is required for each track';ru='Для каждой используемой дорожки должен быть указан суффикс, отличный от 0'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;

EndProcedure

&AtClient
Procedure DeviceTest(Command)

	ClearMessages();
	
	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"     , Port);
	tempDeviceParameters.Insert("Speed" , Speed);
	tempDeviceParameters.Insert("DataBit", DataBit);
	tempDeviceParameters.Insert("StopBit"  , StopBit);
	tempDeviceParameters.Insert("Timeout"  , Timeout);
	tempDeviceParameters.Insert("TracksParameters", New Array());
	
	EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
	                                                          InputParameters,
	                                                          Output_Parameters,
	                                                          ID,
	                                                          tempDeviceParameters);

EndProcedure

&AtClient
Procedure SetDriverFromArchiveOnEnd(Result) Export 
	
	CommonUseClientServer.MessageToUser(NStr("en='Driver is installed.';ru='Установка драйвера завершена.'")); 
	UpdateInformationAboutDriver();
	
EndProcedure 

&AtClient
Procedure SettingDriverFromDistributionOnEnd(Result, Parameters) Export 
	
	If Result Then
		CommonUseClientServer.MessageToUser(NStr("en='Driver is installed.';ru='Установка драйвера завершена.'")); 
		UpdateInformationAboutDriver();
	Else
		CommonUseClientServer.MessageToUser(NStr("en='An error occurred when installing the driver from distribution.';ru='При установке драйвера из дистрибутива произошла ошибка.'")); 
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

Procedure CustomizeControlElements()
	
	PortEnabled = Port > 0;  
	Items.Speed.Enabled  = PortEnabled;
	Items.DataBit.Enabled = PortEnabled;
	Items.StopBit.Enabled   = PortEnabled;
	Items.Timeout.Enabled   = Not PortEnabled;
	
EndProcedure

&AtClient
Procedure UpdateInformationAboutDriver()

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"     , Port);
	tempDeviceParameters.Insert("Speed" , Speed);
	tempDeviceParameters.Insert("DataBit", DataBit);
	tempDeviceParameters.Insert("StopBit"  , StopBit);
	tempDeviceParameters.Insert("TracksParameters", New Array());
	
	If EquipmentManagerClient.RunAdditionalCommand("GetDriverVersion",
	                                                               InputParameters,
	                                                               Output_Parameters,
	                                                               ID,
	                                                               tempDeviceParameters) Then
		Driver        = Output_Parameters[0];
		Version         = Output_Parameters[1];
		VersionFromBPO    = Output_Parameters[2];
		VersionStr      = Output_Parameters[3];
		VersionFromBPOStr = Output_Parameters[4];
		
		// Check the matching of the driver version number in the BPO and number reported by the driver itself.
		If VersionFromBPOStr > VersionStr Then
			CommonUseClientServer.MessageToUser(NStr("en='The driver version installed on the computer is outdated! It is required to update to version:';ru='Установленная на компьютере версия драйвера устарела! Необходимо обновление до версии:'") + Chars.NBSp + VersionFromBPO);
		EndIf;
	Else
		Driver        = Output_Parameters[2];
		Version         = NStr("en='Not defined';ru='Не определена'");
		VersionStr      = 8000000;
		VersionFromBPOStr = 8000000;
	EndIf;

	Items.Driver.TextColor = ?(Driver = NStr("en='Not set';ru='Не установлен'"), ErrorColor, TextColor);
	Items.Version.TextColor  = ?(Version  = NStr("en='Not defined';ru='Не определена'"), ErrorColor, TextColor);
	
	Items.SetupDriver.Enabled = Not (Driver = NStr("en='Installed';ru='Установлен'"));
	
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
