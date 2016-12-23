
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
	For IndexOf = 1 To 64 Do
		ListPort.Add(IndexOf, "COM" + TrimAll(IndexOf));
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
	
	SuffixList = Items.Suffix.ChoiceList;
	SuffixList.Add(8,  "(8) BS");
	SuffixList.Add(9,  "(9) TAB");
	SuffixList.Add(10, "(10) LF");
	SuffixList.Add(13, "(13) CR");

	tempPort      = Undefined;
	tempSpeed     = Undefined;
	tempDataBit   = Undefined;
	tempStopBit   = Undefined;
	tempPrefix    = Undefined;
	tempSuffix    = Undefined;
	
	Parameters.EquipmentParameters.Property("Port",      tempPort);
	Parameters.EquipmentParameters.Property("Speed",  tempSpeed);
	Parameters.EquipmentParameters.Property("DataBit", tempDataBit);
	Parameters.EquipmentParameters.Property("StopBit",   tempStopBit);
	Parameters.EquipmentParameters.Property("Prefix",   tempPrefix);
	Parameters.EquipmentParameters.Property("Suffix",   tempSuffix);
	
	Port        = ?(tempPort      = Undefined,         1, tempPort);
	Speed       = ?(tempSpeed     = Undefined,      9600, tempSpeed);
	DataBit     = ?(tempDataBit   = Undefined,         8, tempDataBit);
	StopBit     = ?(tempStopBit   = Undefined,         0, tempStopBit);
	CodePrefix  = ?(tempPrefix    = Undefined,         0, tempPrefix);
	Suffix      = ?(tempSuffix    = Undefined,        13, tempSuffix);
	
	ActiveWorkplace = SessionParameters.ClientWorkplace = ID.Workplace;
	Items.DeviceTest.Visible          = ActiveWorkplace;
	Items.SetupDriver.Visible       = ActiveWorkplace;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateInformationAboutDriver();

	PrefixCodeOnChange();

	PortOnChange();

EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PrefixOnChange1(Item)

	PrefixOnChange();

EndProcedure

&AtClient
Procedure PrefixCodeOnChange1(Item)

	PrefixCodeOnChange();

EndProcedure

&AtClient
Procedure PortOnChange()

	Items.Speed.Enabled   = (Port <> 101);
	Items.DataBit.Enabled = (Port <> 101);
	Items.StopBit.Enabled = (Port <> 101);

EndProcedure

&AtClient
Procedure PrefixOnChange()

	CodePrefix = CharCode(Prefix);

EndProcedure

&AtClient
Procedure PrefixCodeOnChange()

	Prefix = Char(CodePrefix);

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("Port"        , Port);
	ParametersNewValue.Insert("Speed"    , Speed);
	ParametersNewValue.Insert("DataBit"   , DataBit);
	ParametersNewValue.Insert("StopBit"     , StopBit);
	ParametersNewValue.Insert("CodePrefix" , CodePrefix);
	ParametersNewValue.Insert("Suffix"     , Suffix);
	
	Result = New Structure;
	Result.Insert("ID", ID);
	Result.Insert("EquipmentParameters", ParametersNewValue);
	
	Close(Result);
	
EndProcedure

&AtClient
Procedure DeviceTest(Command)

	InputParameters   = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"     , Port);
	tempDeviceParameters.Insert("Speed" , Speed);
	tempDeviceParameters.Insert("DataBit", DataBit);
	tempDeviceParameters.Insert("StopBit"  , StopBit);
	tempDeviceParameters.Insert("Prefix"  , CodePrefix);
	tempDeviceParameters.Insert("Suffix"  , Suffix);
	
	Result = EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
	                                                                      InputParameters,
	                                                                      Output_Parameters,
	                                                                      ID,
	                                                                      tempDeviceParameters);
	If Not Result Then
		CommonUseClientServer.MessageToUser(NStr("en='Error code:';ru='Код ошибки:'") + Output_Parameters[0]);
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
Procedure UpdateInformationAboutDriver()

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"     , Port);
	tempDeviceParameters.Insert("Speed" , Speed);
	tempDeviceParameters.Insert("DataBit", DataBit);
	tempDeviceParameters.Insert("StopBit"  , StopBit);
	tempDeviceParameters.Insert("Prefix"  , CodePrefix);
	tempDeviceParameters.Insert("Suffix"  , Suffix);
	
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
	
	Items.SetupDriver.Enabled = Not (Driver = NStr("en='Installed';ru='Установлен'"));
	
EndProcedure

#EndRegion













