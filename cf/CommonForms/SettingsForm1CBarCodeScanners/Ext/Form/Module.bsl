
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
	tempPrefix   = Undefined;
	tempSuffix   = Undefined;
	tempTimeout   = Undefined;

	Parameters.EquipmentParameters.Property("Port",      tempPort);
	Parameters.EquipmentParameters.Property("Speed",  tempSpeed);
	Parameters.EquipmentParameters.Property("DataBit", tempDataBit);
	Parameters.EquipmentParameters.Property("StopBit",   tempStopBit);
	Parameters.EquipmentParameters.Property("Prefix",   tempPrefix);
	Parameters.EquipmentParameters.Property("Suffix",   tempSuffix);
	Parameters.EquipmentParameters.Property("Timeout",   tempTimeout);
	
	Port        = ?(tempPort      = Undefined,         1, tempPort);
	Speed       = ?(tempSpeed     = Undefined,      9600, tempSpeed);
	DataBit     = ?(tempDataBit   = Undefined,         8, tempDataBit);
	StopBit     = ?(tempStopBit   = Undefined,         0, tempStopBit);
	Prefix	    = ?(tempPrefix    = Undefined,         "", tempPrefix);
	Suffix      = ?(tempSuffix    = Undefined,      "#13", tempSuffix);
	Timeout     = ?(tempTimeout   = Undefined,         75, tempTimeout);
	
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
Procedure FillChoiceList(control, Attribute)
	ChoiceList = control.ChoiceList;
	ChoiceList.Clear();
    AttributeInList = False;
	For ItemCode = 0 To 127 Do
		Char = "";
		If ItemCode > 32 Then
			Char = " ( " + Char(ItemCode) + " )";
		ElsIf ItemCode = 8 Then
			Char = " (BACKSPACE)";
		ElsIf ItemCode = 9 Then
			Char = " (TAB)";
		ElsIf ItemCode = 10 Then
			Char = " (LF)";
		ElsIf ItemCode = 13 Then
			Char = " (CR)";
		ElsIf ItemCode = 16 Then
			Char = " (SHIFT)";
		ElsIf ItemCode = 17 Then
			Char = " (CONTROL)";
		ElsIf ItemCode = 18 Then
			Char = " (ALT)";
		ElsIf ItemCode = 27 Then
			Char = " (ESCAPE)";
		ElsIf ItemCode = 32 Then
			Char = " (SPACE)";
		EndIf;
		ChoiceList.Add("#" + TrimAll(ItemCode), "#" + TrimAll(ItemCode) + Char);
		If Attribute = "#" + TrimAll(ItemCode) Then
			AttributeInList = True;
		EndIf;
	EndDo;
	If Not AttributeInList Then
		ChoiceList.Add(Attribute);
	EndIf;
EndProcedure

&AtClient
Procedure FillSuffixList()
	Items.Suffix.ChoiceList.Clear();
	Items.Suffix.ChoiceList.Add("8", "(8) BS");
	Items.Suffix.ChoiceList.Add("9", "(9) TAB");
	Items.Suffix.ChoiceList.Add("10","(10) LF");
	Items.Suffix.ChoiceList.Add("13","(13) CR");
	
EndProcedure

&AtClient
Procedure PrefixChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If Port=0 Then
		StandardProcessing = False;
		If ValueSelected <> Undefined Then
			Item.ChoiceList.Add(Prefix + ValueSelected);
			Prefix = Prefix + ValueSelected;
		EndIf;
	Else
		StandardProcessing = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure SuffixChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If Port=0  Then
		StandardProcessing = False;
		If ValueSelected <> Undefined Then
			Item.ChoiceList.Add(Suffix + ValueSelected);
			Suffix = Suffix + ValueSelected;
		EndIf;
	Else
		StandardProcessing = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("Port"      , Port);
	ParametersNewValue.Insert("Speed"  , Speed);
	ParametersNewValue.Insert("DataBit" , DataBit);
	ParametersNewValue.Insert("StopBit"   , StopBit);
	ParametersNewValue.Insert("Prefix"   , Prefix);
	ParametersNewValue.Insert("Suffix"   , Suffix);
	ParametersNewValue.Insert("Timeout"   , Timeout);
	
	Result = New Structure;
	Result.Insert("ID", ID);
	Result.Insert("EquipmentParameters", ParametersNewValue);
	
	Close(Result);
	
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
	tempDeviceParameters.Insert("Prefix"  , Prefix);
	tempDeviceParameters.Insert("Suffix"  , Suffix);
	tempDeviceParameters.Insert("Timeout"  , Timeout);
	
	Result = EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
	                                                                      InputParameters,
	                                                                      Output_Parameters,
	                                                                      ID,
	                                                                      tempDeviceParameters);
	  
	tempDeviceParameters.Property("Timeout", Timeout);
	 
	If Not Result Then
		CommonUseClientServer.MessageToUser(Output_Parameters[1] + "(" + NStr("en='Error code:';ru='Код ошибки:'") + Output_Parameters[0] + ")");
	EndIf;

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

&AtClient
Procedure CustomizeControlElements()
	 // Set the management items according to the driver version.
	If Port = 0 Then
		Items.Speed.Enabled  = False;
		Items.DataBit.Enabled = False;
		Items.StopBit.Enabled   = False;
		
		If Port = 0 Then
			Items.Timeout.Enabled   = True;
			Items.Prefix.Enabled   = True;
			Items.Prefix.ClearButton = True;
			Prefix = SPVNumber(Prefix);
			FillChoiceList(Items.Prefix, Prefix);
			Items.Suffix.ClearButton = True;
			Suffix = SPVNumber(Suffix);
			FillChoiceList(Items.Suffix, Suffix);
		Else	
			Items.Timeout.Enabled   = False;
		    Items.Prefix.ClearButton = False;
			Items.Prefix.Enabled = False;
			Items.Suffix.ClearButton = False;
			Suffix = SPVText(Suffix);
			FillSuffixList();
		EndIf;
	Else
		Items.Speed.Enabled  = True;
		Items.DataBit.Enabled = True;
		Items.StopBit.Enabled   = True;
		
		Items.Timeout.Enabled   = False;
		Items.Timeout.Enabled   = False;
	    Items.Prefix.ClearButton = False;
		Items.Prefix.Enabled   = False;
		Items.Suffix.ClearButton = False;
		Suffix = SPVText(Suffix);
		FillSuffixList();
	EndIf;	
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
	tempDeviceParameters.Insert("Prefix"  , Prefix);
	tempDeviceParameters.Insert("Suffix"  , Suffix);
	tempDeviceParameters.Insert("Timeout"  , Timeout);
	
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

// Function converts a suffix/prefix from the new format #13#10 to
// the old format #10 old format is passed without changes.
//
&AtClient
Function SPVText(Number) 
	Result = Number;	
	FirstOccurence = Find(Result, "#");
	If FirstOccurence = 0 Then
		Return Result;
	EndIf;
	
	Temp = Mid(Result, FirstOccurence+1);
	SecondOccurence = Find(Temp, "#") + FirstOccurence;
	
	If SecondOccurence > FirstOccurence Then
		Result = Mid(Result, SecondOccurence);
	EndIf;
	
	If Result = "#8" Then
		Result = "8";
	ElsIf Result = "#9" Then
		Result = "9";
	ElsIf Result = "#10" Then
		Result = "10";
	ElsIf Result = "#13" Then
		Result = "13";
	EndIf;
	
	Return Result;
	
EndFunction

// Function converts a single suffix/prefix from the format "9"
// to the format "# 9" for values conversions from the old configurations and leaves as there are for the new configurations.
//
&AtClient
Function SPVNumber(CharCode) 
	Result=CharCode;	
	If CharCode = "8" Then
		Result = "#8";
	ElsIf CharCode = "9" Then
		Result = "#9";
	ElsIf CharCode = "10" Then
		Result = "#10";
	ElsIf CharCode = "13" Then
		Result = "#13";
	EndIf;
	Return Result;
EndFunction

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
