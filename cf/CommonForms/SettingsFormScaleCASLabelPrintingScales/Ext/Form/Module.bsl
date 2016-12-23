
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

	ListInterface = Items.Interface.ChoiceList;
	ListInterface.Add(0,  "RS-232");
	ListInterface.Add(1,  "Ethernet");
	                                             
	ListPort = Items.Port.ChoiceList;
	For Number = 1 To 64 Do
		ListPort.Add(Number, "COM" + Format(Number, "ND=2; NFD=0; NZ=0; NG=0"));
	EndDo;
	
	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(1200 , "1200");
	SpeedList.Add(2400 , "2400");
	SpeedList.Add(4800 , "4800");
	SpeedList.Add(9600 , "9600");
	SpeedList.Add(14400, "14400");
	SpeedList.Add(19200, "19200");  
	
	tempDescription = Undefined;
	tempInterface	 = Undefined;
	tempPort        = Undefined;
	tempSpeed       = Undefined;
	tempIPAddress   = Undefined;
	tempIPPort      = Undefined;
	
	Parameters.EquipmentParameters.Property("Interface"    , tempInterface);
	Parameters.EquipmentParameters.Property("Port"         , tempPort);
	Parameters.EquipmentParameters.Property("Speed"        , tempSpeed);
	Parameters.EquipmentParameters.Property("IPAddress"    , tempIPAddress);
	Parameters.EquipmentParameters.Property("IPPort"       , tempIPPort);
	Parameters.EquipmentParameters.Property("Description"  , tempDescription);
	
	Interface    = ?(tempInterface    = Undefined, 0				, tempInterface);
	Port         = ?(tempPort         = Undefined, 1				, tempPort);
	Speed        = ?(tempSpeed        = Undefined, 9600			, tempSpeed);
	IPAddress		 = ?(tempIPAddress	  = Undefined, "192.168.1.2"	, tempIPAddress);
	IPPort		    = ?(tempIPPort       = Undefined, 20304			, tempIPPort);
	Description  = ?(tempDescription  = Undefined, "CAS CL5000J"	, tempDescription);
	
	Items.DeviceTest.Visible    = (SessionParameters.ClientWorkplace = ID.Workplace);
	Items.SetupDriver.Visible   = (SessionParameters.ClientWorkplace = ID.Workplace);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateInformationAboutDriver();

EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure InterfaceOnChange(Item)
	
	EnabledChecking();

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("Interface"    , Interface);
	ParametersNewValue.Insert("Port"         , Port);
	ParametersNewValue.Insert("Speed"        , Speed);
	ParametersNewValue.Insert("IPAddress"    , IPAddress);
	ParametersNewValue.Insert("IPPort"       , IPPort);
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
	tempDeviceParameters.Insert("Interface"   	, Interface);
    tempDeviceParameters.Insert("Port"      	, Port);
	tempDeviceParameters.Insert("Speed"   	    , Speed);
	tempDeviceParameters.Insert("IPAddress"	 	, IPAddress);
	tempDeviceParameters.Insert("IPPort"      	, IPPort);
	tempDeviceParameters.Insert("Description"	 , Description);

	Result = EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
	                                                                      InputParameters,
	                                                                      Output_Parameters,
	                                                                      ID,
	                                                                      tempDeviceParameters);

	If Result Then
		MessageText = NStr("en='Test successfully performed.';ru='Тест успешно выполнен.'");
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array")
		                           AND Output_Parameters.Count() >= 2,
		                           NStr("en='Additional description:';ru='Дополнительное описание:'") + " " + Output_Parameters[1],
		                           "");


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
	tempDeviceParameters.Insert("Interface"   	, Interface);
    tempDeviceParameters.Insert("Port"      	, Port);
	tempDeviceParameters.Insert("Speed"       	, Speed);
	tempDeviceParameters.Insert("IPAddress"	 	, IPAddress);
	tempDeviceParameters.Insert("IPPort"      	, IPPort);
	tempDeviceParameters.Insert("Description" 	, Description);
		

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
    EnabledChecking();

EndProcedure

&AtClient
Procedure EnabledChecking()

	Items.Port.Enabled       = (Interface = 0);
	Items.Speed.Enabled      = (Interface = 0);
	Items.IPAddress.Enabled  = Not (Interface = 0);
	Items.IPPort.Enabled     = Not (Interface = 0);

EndProcedure

#EndRegion













