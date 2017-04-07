&AtClient
Var RefreshInterface;

&AtClient
Var IdleHandlerParameters;

&AtClient
Var LongOperationForm;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	If Not WorkInSafeModeService.SecurityProfilesCanBeUsed() Then
		Raise NStr("en='Security profiles use is unavailable for this configuration.';ru='Использование профилей безопасности недоступно для данной конфигурации!'");
	EndIf;
	
	If Not WorkInSafeModeService.SecurityProfilesSetupAvailable() Then
		Raise NStr("en='Security profile customization is unavailable.';ru='Настройка профилей безопасности недоступна!'");
	EndIf;
	
	If Not RunMode.ThisIsSystemAdministrator Then
		Raise NStr("en='You have no enough access rights!';ru='Недостаточно прав доступа!'");
	EndIf;
	
	// Visible settings on launch.
	ReadSecurityProfilesUseMode();
	
	// Items state update.
	SetEnabled();
	
EndProcedure

&AtClient
Procedure OnClose()
	RefreshApplicationInterface();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure UseModeSecurityProfilesOnChange(Item)
	
	Try
		
		StartUseSecurityProfilesUseSettings(ThisObject.UUID);
		
		PreviousMode = SecurityProfilesUseCurrentMode();
		NewMode = UseModeSecurityProfiles;
		
		If (PreviousMode <> NewMode) Then
			
			If (PreviousMode = 2 Or NewMode = 2) Then
				
				ClosingAlert = New NotifyDescription("AfterClosingSecurityProfilesChangesUseAssistant", ThisObject, True);
				
				If NewMode = 2 Then
					
					PermissionSettingOnExternalResourcesUsageClient.StartEnablingUsingSecurityProfiles(ThisObject, ClosingAlert);
					
				Else
					
					PermissionSettingOnExternalResourcesUsageClient.StartDisablingSecurityProfilesUse(ThisObject, ClosingAlert);
					
				EndIf;
				
			Else
				
				EndSecurityProfilesUseSettingsUse();
				SetEnabled("UseModeSecurityProfiles");
				
			EndIf;
			
		EndIf;
		
	Except
		
		ReadSecurityProfilesUseMode();
		Raise;
		
	EndTry;
	
EndProcedure

&AtClient
Procedure InfobaseSecurityProfileOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RequiredPermissions(Command)
	
	ReportParameters = New Structure();
	ReportParameters.Insert("GenerateOnOpen", True);
	
	OpenForm(
		"Report.UsedExternalResources.ObjectForm",
		ReportParameters);
	
EndProcedure

&AtClient
Procedure RestoreSecurityProfiles(Command)
	
	Try
		
		StartUseSecurityProfilesUseSettings(ThisObject.UUID);
		ClosingAlert = New NotifyDescription("AfterClosingSecurityProfilesChangesUseAssistant", ThisObject, True);
		PermissionSettingOnExternalResourcesUsageClient.StartSecurityProfilesRestoration(ThisObject, ClosingAlert);
		
	Except
		
		ReadSecurityProfilesUseMode();
		Raise;
		
	EndTry;
	
EndProcedure

&AtClient
Procedure OpenExternalDataProcessor(Command)
	
	OpenForm("DataProcessor.PermissionSettingsForExternalResourcesUse.Form.OpenExternalDataProcessorsOrReportWithSecureModeSelection");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure AfterClosingSecurityProfilesChangesUseAssistant(Result, ClientApplicationRestartRequired) Export
	
	If Result = DialogReturnCode.OK Then
		EndSecurityProfilesUseSettingsUse();
	EndIf;
	
	ReadSecurityProfilesUseMode();
	
	If Result = DialogReturnCode.OK AND ClientApplicationRestartRequired Then
		Terminate(True);
	EndIf;
	
EndProcedure

&AtServer
Procedure ReadSecurityProfilesUseMode()
	
	UseModeSecurityProfiles = SecurityProfilesUseCurrentMode();
	SetEnabled("UseModeSecurityProfiles");
	
EndProcedure

&AtServer
Function SecurityProfilesUseCurrentMode()
	
	If WorkInSafeModeService.SecurityProfilesCanBeUsed() AND GetFunctionalOption("SecurityProfilesAreUsed") Then
		
		If Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Get() Then
			
			Result = 2; // From current IB
			
		Else
			
			Result = 1; // From cluster console
			
		EndIf;
		
	Else
		
		Result = 0; // Not used
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Procedure StartUseSecurityProfilesUseSettings(Val UUID)
	
	If Not WorkInSafeModeService.SecurityProfilesCanBeUsed() Then
		Raise NStr("en='Enabling of automatic permissions requests is unavailable.';ru='Включение автоматического запроса разрешений недоступно!'");
	EndIf;
	
	SetExclusiveMode(True);
	
EndProcedure

&AtServer
Procedure EndSecurityProfilesUseSettingsUse()
	
	If UseModeSecurityProfiles = 0 Then
		
		Constants.SecurityProfilesAreUsed.Set(False);
		Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Set(False);
		Constants.InfobaseSecurityProfile.Set("");
		
	ElsIf UseModeSecurityProfiles = 1 Then
		
		Constants.SecurityProfilesAreUsed.Set(True);
		Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Set(False);
		
	ElsIf UseModeSecurityProfiles = 2 Then
		
		Constants.SecurityProfilesAreUsed.Set(True);
		Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Set(True);
		
	EndIf;
	
	If ExclusiveMode() Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	RefreshReusableValues();
	
	If RefreshingInterface Then
		#If Not WebClient Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
		#EndIf
	EndIf;
	
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	#If Not WebClient Then
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	#EndIf
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		StandardSubsystemsClientServer.ExecutionResultAddNotificationOfOpenForms(Result, "Record_ConstantsSet", New Structure, ConstantName);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If RunMode.ThisIsSystemAdministrator Then
		
		If AttributePathToData = "UseModeSecurityProfiles" OR AttributePathToData = "" Then
			
			Items.GroupSecurityProfilesColumnsRight.Enabled = UseModeSecurityProfiles > 0;
			
			Items.InfobaseSecurityProfile.ReadOnly = (UseModeSecurityProfiles = 2);
			Items.GroupSecurityProfileRestoration.Enabled = (UseModeSecurityProfiles = 2);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
