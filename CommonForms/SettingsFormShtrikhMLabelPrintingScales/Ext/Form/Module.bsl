
#Region FormCommandsHandlers

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
	For Number = 1 To 64 Do
		ListPort.Add(Number, "COM" + Format(Number, "ND=2; NFD=0; NZ=0; NG=0"));
	EndDo;  
	
	ListInterface = Items.Interface.ChoiceList;
	ListInterface.Add(0, "RS-232");
	ListInterface.Add(1, "Ethernet");

    SpeedList = Items.Speed.ChoiceList; 
	SpeedList.Add(0,  "2400");
	SpeedList.Add(1,  "4800");
	SpeedList.Add(2,  "9600");
	SpeedList.Add(3, "19200");
	SpeedList.Add(4, "38400");
	SpeedList.Add(5, "57600");
	SpeedList.Add(6,"115200");
	
	tempDescription     = Undefined;
	tempInterface       = Undefined;
	tempPort            = Undefined;
	tempSpeed           = Undefined;
	tempTimeout         = Undefined;
	tempIPAddress       = Undefined;
	tempUDPReceiverPort = Undefined;
	tempUDPTimeout      = Undefined;
	tempPassword        = Undefined;
	TempQuickImport       = Undefined;
	
	Parameters.EquipmentParameters.Property("Interface"        , tempInterface);
	Parameters.EquipmentParameters.Property("Port"             , tempPort);
	Parameters.EquipmentParameters.Property("Speed"            , tempSpeed);
	Parameters.EquipmentParameters.Property("Timeout"          , tempTimeout);
	Parameters.EquipmentParameters.Property("IPAddress"        , tempIPAddress);
	Parameters.EquipmentParameters.Property("UDPReceiverPort"  , tempUDPReceiverPort);
	Parameters.EquipmentParameters.Property("UDPTimeout"       , tempUDPTimeout);
	Parameters.EquipmentParameters.Property("Password"         , tempPassword);
	Parameters.EquipmentParameters.Property("QuickImport"        , TempQuickImport);
	Parameters.EquipmentParameters.Property("Description"      , tempDescription);
	                          
	Interface          = ?(tempInterface           = Undefined, 0, tempInterface);
	Port               = ?(tempPort                = Undefined, 1, tempPort);
	Speed              = ?(tempSpeed               = Undefined, 2, tempSpeed);
	Timeout            = ?(tempTimeout             = Undefined, 50, tempTimeout);
	IPAddress          = ?(tempIPAddress           = Undefined, "192.168.0.1", tempIPAddress);
	UDPReceiverPort    = ?(tempUDPReceiverPort     = Undefined, 1111, tempUDPReceiverPort);
	UDPTimeout         = ?(tempUDPTimeout          = Undefined, 500, tempUDPTimeout);
	Password           = ?(tempPassword            = Undefined, "0030", tempPassword);
	QuickImport          = ?(TempQuickImport           = Undefined, False, TempQuickImport);
	
	Description = ?(tempDescription = Undefined, NStr("en='Stroke-PRINT';ru='ШТРИХ-ПРИНТ'"), tempDescription);
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
Procedure InterfaceOnChange(Item)
	
	EnabledChecking();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("Interface"        , Interface);
	ParametersNewValue.Insert("Port"             , Port);
	ParametersNewValue.Insert("Speed"            , Speed);
	ParametersNewValue.Insert("Timeout"          , Timeout);
	ParametersNewValue.Insert("IPAddress"        , IPAddress);
	ParametersNewValue.Insert("UDPReceiverPort"  , UDPReceiverPort);
	ParametersNewValue.Insert("UDPTimeout"       , UDPTimeout);
	ParametersNewValue.Insert("Password"         , Password);
	ParametersNewValue.Insert("QuickImport"        , QuickImport);
	ParametersNewValue.Insert("Description"      , Description);
	
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

	TestResult = Undefined;

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Interface"    		, Interface);
	tempDeviceParameters.Insert("Port"     	  		, Port);
	tempDeviceParameters.Insert("Speed" 	  	   	, Speed);
	tempDeviceParameters.Insert("Timeout"			   	, Timeout);	
	tempDeviceParameters.Insert("IPAddress"			 	, IPAddress);
	tempDeviceParameters.Insert("UDPReceiverPort"	, UDPReceiverPort);
	tempDeviceParameters.Insert("UDPTimeout"   		, UDPTimeout);
	tempDeviceParameters.Insert("Password"		  		, Password);
	tempDeviceParameters.Insert("Description"			, Description);
	tempDeviceParameters.Insert("QuickImport"	    	, QuickImport);
  
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
Procedure EnabledChecking()

	Items.Port.Enabled          		= (Interface = 0);
	Items.Speed.Enabled      		= (Interface = 0);
	Items.Timeout.Enabled      		= (Interface = 0);
	Items.IPAddress.Enabled       		= Not (Interface = 0);
	Items.UDPReceiverPort.Enabled  = Not (Interface = 0);
	Items.UDPTimeout.Enabled         = Not (Interface = 0);
           
EndProcedure

&AtClient
Procedure UpdateInformationAboutDriver()

	InputParameters  = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Interface"    		, Interface);
	tempDeviceParameters.Insert("Port"     	 		, Port);
	tempDeviceParameters.Insert("Speed" 	  		, Speed);
	tempDeviceParameters.Insert("Timeout"				, Timeout);	
	tempDeviceParameters.Insert("IPAddress"				, IPAddress);
	tempDeviceParameters.Insert("UDPReceiverPort"	, UDPReceiverPort);
	tempDeviceParameters.Insert("UDPTimeout"      		, UDPTimeout);
	tempDeviceParameters.Insert("Password"				, Password);
	tempDeviceParameters.Insert("Description"			, Description);
	tempDeviceParameters.Insert("QuickImport"		, QuickImport);
	
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
