
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("ID", ID);
	Parameters.Property("HardwareDriver", HardwareDriver);
	
	Title = NStr("en='Equipment:'") + Chars.NBSp + String(ID);
	
	TextColor = StyleColors.FormTextColor;
	ErrorColor = StyleColors.NegativeTextColor;

	ListPort = Items.Port.ChoiceList;
	For Number = 1 To 64 Do
		ListPort.Add(Number, "COM" + Format(Number, "ND=2; NFD=0; NZ=0; NG=0"));
	EndDo;

	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(4800,   "4800 baud");
	SpeedList.Add(9600,   "9600 baud");
	SpeedList.Add(14400,  "14400 baud");
	SpeedList.Add(19200,  "19200 baud");
	SpeedList.Add(28800,  "28800 baud");
	SpeedList.Add(38400,  "38400 baud");
	SpeedList.Add(57600,  "57600 baud");
	SpeedList.Add(115200, "115200 baud");

	tempPort                       = Undefined;
	tempSpeed                   = Undefined;
	tempTimeout                    = Undefined;
	tempNetworkNumber               = Undefined;
	TempDevicePassword           = Undefined;
	tempUserPassword         = Undefined;
	tempAdministratorPassword       = Undefined;
	TempCancelCheckOnConnect  = Undefined;
	tempPaymentDescription1        = Undefined;
	tempPaymentDescription2        = Undefined;
	tempSectionNumber                = Undefined;
	tempPartialCuttingSymbolCode = Undefined;
	TempDriverOperationsLog     = Undefined;
	
	Parameters.EquipmentParameters.Property("Port"                      , tempPort);
	Parameters.EquipmentParameters.Property("Speed"                  , tempSpeed);
	Parameters.EquipmentParameters.Property("Timeout"                   , tempTimeout);
	Parameters.EquipmentParameters.Property("NetworkNumber"              , tempNetworkNumber);
	Parameters.EquipmentParameters.Property("DevicePassword"          , TempDevicePassword);
	Parameters.EquipmentParameters.Property("UserPassword"        , tempUserPassword);
	Parameters.EquipmentParameters.Property("AdministratorPassword"      , tempAdministratorPassword);
	Parameters.EquipmentParameters.Property("CancelCheckDuringConnect" , TempCancelCheckOnConnect);
	Parameters.EquipmentParameters.Property("PaymentDescription1"       , tempPaymentDescription1);
	Parameters.EquipmentParameters.Property("PaymentDescription2"       , tempPaymentDescription2);
	Parameters.EquipmentParameters.Property("SectionNumber"               , tempSectionNumber);
	Parameters.EquipmentParameters.Property("PartialCuttingSymbolCode", tempPartialCuttingSymbolCode);
	Parameters.EquipmentParameters.Property("LogDriver"    , TempDriverOperationsLog);
	
	Port                       = ?(tempPort                       = Undefined,      1, tempPort);
	Speed                   = ?(tempSpeed                   = Undefined, 115200, tempSpeed);
	Timeout                    = ?(tempTimeout                    = Undefined,    150, tempTimeout);
	NetworkNumber               = ?(tempNetworkNumber               = Undefined,      0, tempNetworkNumber);
	DevicePassword           = ?(TempDevicePassword           = Undefined,      0, TempDevicePassword);
	UserPassword         = ?(tempUserPassword         = Undefined,    "0", tempUserPassword);
	AdministratorPassword       = ?(tempAdministratorPassword       = Undefined,    "0", tempAdministratorPassword);
	CancelCheckDuringConnect  = ?(TempCancelCheckOnConnect  = Undefined,   False, TempCancelCheckOnConnect);
	PaymentDescription1        = ?(tempPaymentDescription1        = Undefined,     "", tempPaymentDescription1);
	PaymentDescription2        = ?(tempPaymentDescription2        = Undefined,     "", tempPaymentDescription2);
	SectionNumber                = ?(tempSectionNumber                = Undefined,      0, tempSectionNumber);
	PartialCuttingSymbolCode = ?(tempPartialCuttingSymbolCode = Undefined,     22, tempPartialCuttingSymbolCode);
	LogDriver     = ?(TempDriverOperationsLog     = Undefined,   False, TempDriverOperationsLog);
	
	Items.DeviceTest.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);
	Items.SetupDriver.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateInformationAboutDriver();

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("Port"                       , Port);
	ParametersNewValue.Insert("Speed"                   , Speed);
	ParametersNewValue.Insert("Timeout"                    , Timeout);
	ParametersNewValue.Insert("NetworkNumber"               , NetworkNumber);
	ParametersNewValue.Insert("DevicePassword"           , DevicePassword);
	ParametersNewValue.Insert("UserPassword"         , UserPassword);
	ParametersNewValue.Insert("AdministratorPassword"       , AdministratorPassword);
	ParametersNewValue.Insert("CancelCheckDuringConnect"  , CancelCheckDuringConnect);
	ParametersNewValue.Insert("PaymentDescription1"        , PaymentDescription1);
	ParametersNewValue.Insert("PaymentDescription2"        , PaymentDescription2);
	ParametersNewValue.Insert("SectionNumber"                , SectionNumber);
	ParametersNewValue.Insert("PartialCuttingSymbolCode" , PartialCuttingSymbolCode);
	ParametersNewValue.Insert("LogDriver"     , LogDriver);
	
	Result = New Structure;
	Result.Insert("ID", ID);
	Result.Insert("EquipmentParameters", ParametersNewValue);
	
	Close(Result);

EndProcedure

&AtClient
Procedure DeviceTest(Command)
	
	ClearMessages();
	
	TestResult    = Undefined;
	
	InputParameters  = Undefined;
	Output_Parameters = Undefined;
	
	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"                      , Port);
	tempDeviceParameters.Insert("Speed"                  , Speed);
	tempDeviceParameters.Insert("Timeout"                   , Timeout);
	tempDeviceParameters.Insert("NetworkNumber"              , NetworkNumber);
	tempDeviceParameters.Insert("DevicePassword"          , DevicePassword);
	tempDeviceParameters.Insert("UserPassword"        , UserPassword);
	tempDeviceParameters.Insert("AdministratorPassword"      , AdministratorPassword);
	tempDeviceParameters.Insert("CancelCheckDuringConnect" , CancelCheckDuringConnect);
	tempDeviceParameters.Insert("PaymentDescription1"       , PaymentDescription1);
	tempDeviceParameters.Insert("PaymentDescription2"       , PaymentDescription2);
	tempDeviceParameters.Insert("SectionNumber"               , SectionNumber);
	tempDeviceParameters.Insert("PartialCuttingSymbolCode", PartialCuttingSymbolCode);
	tempDeviceParameters.Insert("LogDriver"    , LogDriver);
	
	Result = EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
	                                                                      InputParameters,
	                                                                      Output_Parameters,
	                                                                      ID,
	                                                                      tempDeviceParameters);

	AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array") AND Output_Parameters.Count() >= 2, 
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

&AtClient
Procedure SetDriverFromArchiveOnEnd(Result) Export 
	
	CommonUseClientServer.MessageToUser(NStr("en='Driver is installed.'")); 
	UpdateInformationAboutDriver();
	
EndProcedure 

&AtClient
Procedure SettingDriverFromDistributionOnEnd(Result, Parameters) Export 
	
	If Result Then
		CommonUseClientServer.MessageToUser(NStr("en='Driver is installed.'")); 
		UpdateInformationAboutDriver();
	Else
		CommonUseClientServer.MessageToUser(NStr("en='An error occurred when installing the driver from distribution.'")); 
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
	tempDeviceParameters.Insert("Port"                      , Port);
	tempDeviceParameters.Insert("Speed"                  , Speed);
	tempDeviceParameters.Insert("Timeout"                   , Timeout);
	tempDeviceParameters.Insert("UserPassword"        , UserPassword);
	tempDeviceParameters.Insert("AdministratorPassword"      , AdministratorPassword);
	tempDeviceParameters.Insert("CancelCheckDuringConnect" , CancelCheckDuringConnect);
	tempDeviceParameters.Insert("PaymentDescription1"       , PaymentDescription1);
	tempDeviceParameters.Insert("PaymentDescription2"       , PaymentDescription2);
	tempDeviceParameters.Insert("SectionNumber"               , SectionNumber);
	tempDeviceParameters.Insert("PartialCuttingSymbolCode", PartialCuttingSymbolCode);
	tempDeviceParameters.Insert("LogDriver"    , LogDriver);
	
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