
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
	ListPort.Add(0, "<AUTO>");
	For Number = 1 To 64 Do
		ListPort.Add(Number, "COM" + Format(Number, "ND=2; NFD=0; NZ=0; NG=0"));
	EndDo;

	tempPort                        = Undefined;
	tempSpeed                    = Undefined;
	tempTimeout                     = Undefined;
	tempUserPassword          = Undefined;
	tempAdministratorPassword        = Undefined;
	tempImageAtEnd           = Undefined;
	tempImageAtBegin			= Undefined;
	tempImageAfter			= Undefined;
	tempPaymentDescription1			= Undefined;
	tempPaymentDescription2			= Undefined;
	tempSectionNumber					= Undefined;
	tempPaymentByCash				= Undefined;
	tempPartialCuttingSymbolCode	= Undefined;
  
	Parameters.EquipmentParameters.Property("Port"                       , tempPort);
	Parameters.EquipmentParameters.Property("Speed"                   , tempSpeed);
	Parameters.EquipmentParameters.Property("Timeout"                    , tempTimeout);
	Parameters.EquipmentParameters.Property("UserPassword"         , tempUserPassword);
	Parameters.EquipmentParameters.Property("AdministratorPassword"       , tempAdministratorPassword);
	Parameters.EquipmentParameters.Property("ImageAtEnd"          , tempImageAtEnd);
	Parameters.EquipmentParameters.Property("ImageAtStart"         , tempImageAtBegin);
	Parameters.EquipmentParameters.Property("ImageAfter"           , tempImageAfter);
	Parameters.EquipmentParameters.Property("PaymentDescription1"        , tempPaymentDescription1);
	Parameters.EquipmentParameters.Property("PaymentDescription2"        , tempPaymentDescription2);
	Parameters.EquipmentParameters.Property("SectionNumber"                , tempSectionNumber);
	Parameters.EquipmentParameters.Property("PaymentByCash"             , tempPaymentByCash);
	Parameters.EquipmentParameters.Property("PartialCuttingSymbolCode" , tempPartialCuttingSymbolCode);
	
	Port                       = ?(tempPort                   		= Undefined,    	0, tempPort);
	Speed                   = ?(tempSpeed                     = Undefined, 19200, tempSpeed);
	Timeout                    = ?(tempTimeout                   	= Undefined,  1500, tempTimeout);
	UserPassword         = ?(tempUserPassword     		= Undefined,   	1, tempUserPassword);
	AdministratorPassword       = ?(tempAdministratorPassword   		= Undefined,    22, tempAdministratorPassword);
	ImageAtEnd     	   = ?(tempImageAtEnd      		= Undefined,   	0, tempImageAtEnd);
	ImageAtStart		   = ?(tempImageAtBegin     		= Undefined,   	0, tempImageAtBegin);
	ImageAfter       	   = ?(tempImageAfter       		= Undefined,   	0, tempImageAfter);
	PaymentDescription1        = ?(tempPaymentDescription1    		= Undefined,    "", tempPaymentDescription1);
	PaymentDescription2        = ?(tempPaymentDescription2    		= Undefined,    "", tempPaymentDescription2);
	PaymentByCash             = ?(tempPaymentByCash            	= Undefined,     0, tempPaymentByCash);
	SectionNumber                = ?(tempSectionNumber            		= Undefined,     0, tempSectionNumber);
	PartialCuttingSymbolCode = ?(tempPartialCuttingSymbolCode 	= Undefined,    22, tempPartialCuttingSymbolCode);
	
	Items.DeviceTest.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);
	Items.SetupDriver.Visible = (SessionParameters.ClientWorkplace = ID.Workplace);
	Items.SectionNumber.Enabled = PaymentByCash;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateInformationAboutDriver();

EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PaymentByCashOnChange(Item)
	Items.SectionNumber.Enabled = PaymentByCash;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()

	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("Port"                       , Port);
	ParametersNewValue.Insert("Speed"                   , Speed);
	ParametersNewValue.Insert("Timeout"                    , Timeout);
	ParametersNewValue.Insert("UserPassword"         , UserPassword);
	ParametersNewValue.Insert("AdministratorPassword"       , AdministratorPassword);
	ParametersNewValue.Insert("ImageAtEnd"          , ImageAtEnd);
	ParametersNewValue.Insert("ImageAtStart"         , ImageAtStart);
	ParametersNewValue.Insert("ImageAfter"           , ImageAfter);
	ParametersNewValue.Insert("PaymentDescription1"        , PaymentDescription1);
	ParametersNewValue.Insert("PaymentDescription2"        , PaymentDescription2);
	ParametersNewValue.Insert("SectionNumber"                , SectionNumber);
	ParametersNewValue.Insert("PaymentByCash"             , PaymentByCash);
	ParametersNewValue.Insert("PartialCuttingSymbolCode" , PartialCuttingSymbolCode);
	
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
	tempDeviceParameters.Insert("Port"							, Port);
	tempDeviceParameters.Insert("Speed"						, Speed);
	tempDeviceParameters.Insert("Timeout"						, Timeout);
    tempDeviceParameters.Insert("UserPassword"			, UserPassword);
	tempDeviceParameters.Insert("AdministratorPassword"			, AdministratorPassword);
	tempDeviceParameters.Insert("ImageAtEnd"			, ImageAtEnd);
	tempDeviceParameters.Insert("ImageAtStart"			, ImageAtStart);
	tempDeviceParameters.Insert("ImageAfter"				, ImageAfter);
	tempDeviceParameters.Insert("PaymentDescription1"			, PaymentDescription1);
	tempDeviceParameters.Insert("PaymentDescription2"			, PaymentDescription2);
	tempDeviceParameters.Insert("SectionNumber"					, SectionNumber);
	tempDeviceParameters.Insert("PaymentByCash"				, PaymentByCash);
	tempDeviceParameters.Insert("PartialCuttingSymbolCode"	, PartialCuttingSymbolCode);
	
	Result = EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
																		  InputParameters,
																		  Output_Parameters,
																		  ID,
																		  tempDeviceParameters);

	AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array")
							   AND Output_Parameters.Count(),
							   NStr("en = 'Additional description:'") + " " + Output_Parameters[1],
							   "");
	If Result Then
		MessageText = NStr("en = 'Test completed successfully. %AdditionalDetails%%Linefeed%'");
		MessageText = StrReplace(MessageText, "%Linefeed%", ?(IsBlankString(AdditionalDetails),
																		  "",
																		  Chars.LF));
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails),
																				   "",
																				   AdditionalDetails));
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		MessageText = NStr("en = 'Test failed.%Linefeed% %AdditionalDetails%'");
		MessageText = StrReplace(MessageText, "%Linefeed%", ?(IsBlankString(AdditionalDetails),
																		  "",
																		  Chars.LF));
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails),
																				   "",
																				   AdditionalDetails));
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
	tempDeviceParameters.Insert("Port"							, Port);
	tempDeviceParameters.Insert("Speed"						, Speed);
	tempDeviceParameters.Insert("Timeout"						, Timeout);
	tempDeviceParameters.Insert("UserPassword"			, UserPassword);
	tempDeviceParameters.Insert("AdministratorPassword"			, AdministratorPassword);
	tempDeviceParameters.Insert("ImageAtEnd"			, ImageAtEnd);
	tempDeviceParameters.Insert("ImageAtStart"			, ImageAtStart);
	tempDeviceParameters.Insert("ImageAfter"				, ImageAfter);
	tempDeviceParameters.Insert("PaymentDescription1"			, PaymentDescription1);
	tempDeviceParameters.Insert("PaymentDescription2"			, PaymentDescription2);
	tempDeviceParameters.Insert("SectionNumber"					, SectionNumber);
	tempDeviceParameters.Insert("PaymentByCash"				, PaymentByCash);
	tempDeviceParameters.Insert("PartialCuttingSymbolCode"	, PartialCuttingSymbolCode);


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
