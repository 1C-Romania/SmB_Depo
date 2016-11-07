
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

	ListSlipReceiptWidth = Items.SlipReceiptWidth.ChoiceList;
	ListSlipReceiptWidth.Add(24,  NStr("en='24 ch.';ru='24 сим.'"));
	ListSlipReceiptWidth.Add(32,  NStr("en='32 ch.';ru='32 сим.'"));
	ListSlipReceiptWidth.Add(36,  NStr("en='36 ch.';ru='36 сим.'"));
	ListSlipReceiptWidth.Add(40,  NStr("en='40 ch.';ru='40 сим.'"));
	ListSlipReceiptWidth.Add(48,  NStr("en='48 ch.';ru='48 сим.'"));

	tempSlipReceiptWidth             = Undefined;
	tempPartialCuttingSymbolCode = Undefined;
	
	Parameters.EquipmentParameters.Property("SlipReceiptWidth"            , tempSlipReceiptWidth);
	Parameters.EquipmentParameters.Property("PartialCuttingSymbolCode", tempPartialCuttingSymbolCode);
	
	SlipReceiptWidth = ?(tempSlipReceiptWidth = Undefined, 32, tempSlipReceiptWidth);
	PartialCuttingSymbolCode = ?(tempPartialCuttingSymbolCode = Undefined, 22, tempPartialCuttingSymbolCode);
	
EndProcedure

// Procedure - form event handler "OnOpen".
//
&AtClient
Procedure OnOpen(Cancel)

	UpdateInformationAboutDriver();

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndCloseExecute()
	
	ParametersNewValue = New Structure;
	ParametersNewValue.Insert("SlipReceiptWidth"             , SlipReceiptWidth);
	ParametersNewValue.Insert("PartialCuttingSymbolCode" , PartialCuttingSymbolCode);
	
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

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure UpdateInformationAboutDriver()

	InputParameters  = Undefined;
	Output_Parameters = Undefined;
	
	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("SlipReceiptWidth"            , SlipReceiptWidth);
	tempDeviceParameters.Insert("PartialCuttingSymbolCode", PartialCuttingSymbolCode);
	
	If EquipmentManagerClient.RunAdditionalCommand("GetDriverVersion",
	                                                               InputParameters,
	                                                               Output_Parameters,
	                                                               ID,
	                                                               tempDeviceParameters) Then
		Driver = Output_Parameters[0];
	Else
		Driver = Output_Parameters[2];
	EndIf;
	
	Items.Driver.TextColor = ?(Driver = NStr("en='Not set';ru='Не установлен'"), ErrorColor, TextColor);
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
