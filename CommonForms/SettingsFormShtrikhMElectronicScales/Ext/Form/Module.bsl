                         
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
	
	WeightTypeList = Items.ScalesType.ChoiceList;
	WeightTypeList.Add("3",  NStr("en='Stroke AS';ru='Штрих АС'"));
	WeightTypeList.Add("5",  NStr("en='Stroke AS POS';ru='Штрих АС POS'"));
	WeightTypeList.Add("11", NStr("en='Stroke POS2';ru='Штрих POS2'"));
	
	ListPort = Items.Port.ChoiceList;
	For Number = 1 To 64 Do
		ListPort.Add(Number, "COM" + Format(Number, "ND=2; NFD=0; NZ=0; NG=0"));
	EndDo;
	
	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(3,  "1200");
	SpeedList.Add(4,  "2400");
	SpeedList.Add(5,  "4800");
	SpeedList.Add(7,  "9600");
	
	ParityList = Items.Parity.ChoiceList;
	ParityList.Add(0, NStr("en='No';ru='Нет'"));
	ParityList.Add(1, NStr("en='Oddness';ru='Нечетность'"));
	ParityList.Add(2, NStr("en='Parity';ru='Четность'"));
	
	tempPort        = Undefined;
	tempSpeed       = Undefined;
	tempParity      = Undefined;
	TempTypeWeights = Undefined;
	tempDescription = Undefined;
	
	Parameters.EquipmentParameters.Property("Port"        , tempPort);
	Parameters.EquipmentParameters.Property("Speed"    , tempSpeed);
	Parameters.EquipmentParameters.Property("Parity"    , tempParity);
	Parameters.EquipmentParameters.Property("ScalesType"    , TempTypeWeights);
	Parameters.EquipmentParameters.Property("Description", tempDescription);
	
	Port         = ?(tempPort         = Undefined, 1, tempPort);
	Speed        = ?(tempSpeed        = Undefined, 7, tempSpeed);
	Parity       = ?(tempParity       = Undefined, 0, tempParity);
	ScalesType   = ?(TempTypeWeights  = Undefined, Items.ScalesType.ChoiceList[0].Value, TempTypeWeights);
	Description = ?(tempDescription = Undefined, Items.ScalesType.ChoiceList[0].Presentation, tempDescription);
	
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
	
	Description = Items.ScalesType.ChoiceList.FindByValue(ValueSelected).Presentation;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()

	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("Port"         , Port);
	ParametersNewValue.Insert("Speed"        , Speed);
	ParametersNewValue.Insert("Parity"       , Parity);
	ParametersNewValue.Insert("ScalesType"   , ScalesType);
	ParametersNewValue.Insert("Description"  , Description);
	
	Result = New Structure;
	Result.Insert("ID", ID);
	Result.Insert("EquipmentParameters", ParametersNewValue);
	
	Close(Result);
	
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

&AtClient
Procedure DeviceTest(Command)

	ClearMessages();
	
	TestResult = Undefined;

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"         , Port);
	tempDeviceParameters.Insert("Speed"        , Speed);
	tempDeviceParameters.Insert("Parity"       , Parity);
	tempDeviceParameters.Insert("ScalesType"   , ScalesType);
	tempDeviceParameters.Insert("Description"  , Description);

	Result = EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
	                                                                      InputParameters,
	                                                                      Output_Parameters,
	                                                                      ID,
	                                                                      tempDeviceParameters);

	AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array")
	                           AND Output_Parameters.Count(),
	                           NStr("en='Additional description:';ru='Дополнительное описание:'") + " " + Output_Parameters[1],
	                           "");
	If Result Then
		MessageText = NStr("en='Test completed successfully. %AdditionalDetails%%Linefeed%';ru='Тест успешно выполнен.%ПереводСтроки%%ДополнительноеОписание%'");
		
		MessageText = StrReplace(MessageText, "%Linefeed%", ?(IsBlankString(AdditionalDetails),
		                                                                  "",
		                                                                  Chars.LF));
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails),
		                                                                           "",
		                                                                           AdditionalDetails));
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		MessageText = NStr("en='Test failed.%Linefeed% %AdditionalDetails%';ru='Тест не пройден.%ПереводСтроки%%ДополнительноеОписание%'");
	
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
Procedure UpdateInformationAboutDriver()

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"        , Port);
	tempDeviceParameters.Insert("Speed"       , Speed);
	tempDeviceParameters.Insert("Parity"      , Parity);
	tempDeviceParameters.Insert("ScalesType"  , ScalesType);
	tempDeviceParameters.Insert("Description" , Description);

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
