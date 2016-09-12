
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

	ValueList = Items.Port.ChoiceList;
	For IndexOf = 1 To 64 Do
		ValueList.Add(IndexOf, "COM" + String(IndexOf));
	EndDo;
	
	ValueList = Items.Speed.ChoiceList;
	ValueList.Add(9600,     "9600");
	ValueList.Add(19200,   "19200");
	ValueList.Add(38400,   "38400");
	ValueList.Add(57600,   "57600");
	ValueList.Add(115200, "115200");
	
	tempTerminalID = Undefined;
	tempPort        = Undefined;
	tempSpeed    = Undefined;
	tempDataBits  = Undefined;
	tempParity    = Undefined;
	tempStopBits    = Undefined;
	tempFlowControl    = Undefined;
	tempCurrencyCode            = Undefined;
	tempCopiesCount      = Undefined;
	tempSlipReceiptWidth       = Undefined;
	tempCutCharCode     = Undefined;
	TempHeaderText           = Undefined;
	TempFooterText         = Undefined;
	tempSlipReceiptTemplateData = Undefined;
	
	Parameters.EquipmentParameters.Property("TerminalID"       , tempTerminalID);
	Parameters.EquipmentParameters.Property("Port"              ,   tempPort);
	Parameters.EquipmentParameters.Property("Speed"          , tempSpeed);
	Parameters.EquipmentParameters.Property("DataBits"        , tempDataBits);
	Parameters.EquipmentParameters.Property("Parity"          , tempParity);
	Parameters.EquipmentParameters.Property("StopBits"          , tempStopBits);
	Parameters.EquipmentParameters.Property("FlowControl" , tempFlowControl);	
	Parameters.EquipmentParameters.Property("CurrencyCode"         , tempCurrencyCode);
	Parameters.EquipmentParameters.Property("CopiesCount"   , tempCopiesCount);
	Parameters.EquipmentParameters.Property("CutCharCode"  , tempCutCharCode);
	Parameters.EquipmentParameters.Property("HeaderText"        , TempHeaderText);
	Parameters.EquipmentParameters.Property("FooterText"      , TempFooterText);
	Parameters.EquipmentParameters.Property("SlipReceiptTemplateData", tempSlipReceiptTemplateData);
	
	TerminalID = ?(tempTerminalID = Undefined, "00000", tempTerminalID);
	Port = ?(tempPort  = Undefined, 1, tempPort);
	Speed = ?(tempSpeed  = Undefined, 9600, tempSpeed);
	DataBits = ?(tempDataBits  = Undefined, 8, tempDataBits);
	Parity = ?(tempParity  = Undefined, 0, tempParity);
	StopBits = ?(tempStopBits  = Undefined, 1, tempStopBits);
	FlowControl    = ?(tempFlowControl  = Undefined, 2, tempFlowControl);
	CurrencyCode = ?(tempCurrencyCode  = Undefined, 643, tempCurrencyCode);
	SlipReceiptWidth = ?(tempSlipReceiptWidth = Undefined, 36, tempSlipReceiptWidth);
	CopiesCount = ?(tempCopiesCount  = Undefined, 2, tempCopiesCount);
	HeaderText = ?(TempHeaderText  = Undefined, "", TempHeaderText);	
	FooterText = ?(TempFooterText  = Undefined, "", TempFooterText);
	CutCharCode = ?(tempCutCharCode  = Undefined, 22, tempCutCharCode);
	SlipReceiptTemplateData = tempSlipReceiptTemplateData;
	
	ReadTemplateData();
	
	Items.DeviceTest.Visible    = (SessionParameters.ClientWorkplace = ID.Workplace);
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

	WriteTemplateData();
	
	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("TerminalID"          , TerminalID);
	ParametersNewValue.Insert("Port"                 , Port);
	ParametersNewValue.Insert("Speed"             , Speed);
	ParametersNewValue.Insert("DataBits"           , DataBits);
	ParametersNewValue.Insert("Parity"             , Parity);
	ParametersNewValue.Insert("StopBits"             , StopBits);
	ParametersNewValue.Insert("FlowControl"    , FlowControl);
	ParametersNewValue.Insert("CurrencyCode"            , CurrencyCode);
	ParametersNewValue.Insert("SlipReceiptWidth"       , SlipReceiptWidth);
	ParametersNewValue.Insert("CopiesCount"      , CopiesCount);
	ParametersNewValue.Insert("CutCharCode"     , CutCharCode);
	ParametersNewValue.Insert("HeaderText"           , HeaderText);
	ParametersNewValue.Insert("FooterText"         , FooterText);
	ParametersNewValue.Insert("SlipReceiptTemplateData" , SlipReceiptTemplateData);
	
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
	tempDeviceParameters.Insert("TerminalID", TerminalID);
	tempDeviceParameters.Insert("Port", Port);
	tempDeviceParameters.Insert("Speed", Speed);
	tempDeviceParameters.Insert("DataBits", DataBits);
	tempDeviceParameters.Insert("Parity", Parity);
	tempDeviceParameters.Insert("StopBits", StopBits);
	tempDeviceParameters.Insert("FlowControl", FlowControl);
	tempDeviceParameters.Insert("CurrencyCode", CurrencyCode);
	tempDeviceParameters.Insert("CutCharCode", CutCharCode);
	tempDeviceParameters.Insert("HeaderText", HeaderText);
	tempDeviceParameters.Insert("FooterText", FooterText);
	

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
	
	If EquipmentManagerClient.RunAdditionalCommand("GetVersionNumber",
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
	
	Items.SetupDriver.Enabled = Not (Driver = NStr("en='Installed';ru='Установлен'"));
	Items.Driver.TextColor = ?(Driver = NStr("en='Not set';ru='Не установлен'"), ErrorColor, TextColor);
	Items.Version.TextColor  = ?(Version  = NStr("en='Not defined';ru='Не определена'"), ErrorColor, TextColor);

EndProcedure

Procedure ReadTemplateData()

	If SlipReceiptTemplateData.Count() = 0 Then
		SlipReceiptTemplateData.Add("Bank"   , "Bank");
		SlipReceiptTemplateData.Add(""       , "Company");
		SlipReceiptTemplateData.Add(""       , "City");
		SlipReceiptTemplateData.Add(""       , "Address");
		SlipReceiptTemplateData.Add("DEPARTMENT1" , "Department");
		SlipReceiptTemplateData.Add("CASHIER" , "Cashier");
		SlipReceiptTemplateData.Add("Hello", "HeaderText");
		SlipReceiptTemplateData.Add("THANKYOU", "FooterText");
	EndIf;

	Bank         = SlipReceiptTemplateData[0].Value;
	Company  = SlipReceiptTemplateData[1].Value;
	City        = SlipReceiptTemplateData[2].Value;
	Address        = SlipReceiptTemplateData[3].Value;
	Department        = SlipReceiptTemplateData[4].Value;
	Cashier       = SlipReceiptTemplateData[5].Value;
	FooterText = SlipReceiptTemplateData[6].Value;
	HeaderText   = SlipReceiptTemplateData[7].Value;

EndProcedure

Procedure WriteTemplateData()

	SlipReceiptTemplateData[0].Value = Bank;
	SlipReceiptTemplateData[1].Value = Company;
	SlipReceiptTemplateData[2].Value = City;
	SlipReceiptTemplateData[3].Value = Address;
	SlipReceiptTemplateData[4].Value = Department;
	SlipReceiptTemplateData[5].Value = Cashier;
	SlipReceiptTemplateData[6].Value = FooterText;
	SlipReceiptTemplateData[7].Value = HeaderText;
	
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
