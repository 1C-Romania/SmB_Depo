﻿#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	RestoreSettings();
	DEManagement();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CheckBoxMechanismEnabledOnChanging(Item)
	
	CheckBoxMechanismSwitchedOnChangeServer();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlers
//Procedures and functions code
#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ConfigureProxyServerParameters(Command)
	
	OpenForm("CommonForm.ProxyServerParameters");
	
EndProcedure

&AtClient
Procedure CheckAccessToService(Command)
	
	WarningText = AccessParametersCheckResult();
	ShowMessageBox(, WarningText);
	
EndProcedure

&AtClient
Procedure ClearRegister(Command)
	CounterpartiesCheckServerCall.ClearSavedCounterpartiesCheckResults();
EndProcedure


#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure CheckBoxMechanismSwitchedOnChangeServer()
	
	CounterpartiesCheck.SaveSettingsValues(UseService);
	If UseService Then
		CounterpartiesCheck.CounterpartiesCheckAfterBackgroundJobCheckingSwitch();
	EndIf;
	
EndProcedure

&AtServer
Procedure DEManagement()
	
	Items.WarningAboutTestMode.Title = CounterpartiesCheck.WarningTextAboutServiceOperationTestMode();
	
EndProcedure

&AtServer
Procedure RestoreSettings()
	
	ServiceSettings 	= CounterpartiesCheck.SettingsValues();
	UseService 	= ServiceSettings.UseService;
	
EndProcedure

&AtServerNoContext
Function AccessParametersCheckResult()
	
	If Not CounterpartiesCheck.HasAccessToFTSService() Then
		WarningText = NStr("en = 'Access to the web service is not available'");
		Return WarningText;
	EndIf;
	
	WarningText = NStr("en = 'Checking of acces to the web service is complete successfully!'");
	Return WarningText;
	
EndFunction

&AtClient
Procedure UseExtendedTooltipServiceNavigationLinkProcessing(Item, URL, StandardProcessing)
	CounterpartiesCheckClient.OpenServiceManual(StandardProcessing);
EndProcedure

#EndRegion

