&AtClient
Var RefreshInterface;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess(Undefined, True, False) Then
		Raise NStr("en='Insufficient rights for administration of data syncronization between applications.';ru='Недостаточно прав для администрирования синхронизации данных между приложениями.'");
	EndIf;
	
	RunMode = CommonUseReUse.ApplicationRunningMode();
	
	SetPrivilegedMode(True);
	
	// Settings of visible on launch
	Items.OfflineWork.Visible = OfflineWorkService.OfflineWorkSupported();
	Items.GroupTemporaryDirectoriesServersCluster.Visible = RunMode.ClientServer AND RunMode.ThisIsSystemAdministrator;
	
	// Update items states
	SetEnabled();
	
EndProcedure

&AtClient
Procedure OnClose()
	RefreshApplicationInterface();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DataExchangeMessagesDirectoryForWindowsOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure DataExchangeMessagesDirectoryForLinuxOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure MonitorSynchronizationData(Command)
	
	OpenForm("CommonForm.DataSynchronizationMonitorSaaS",, ThisObject);
	
EndProcedure

&AtClient
Procedure ExchangeTransportSettings(Command)
	
	OpenForm("InformationRegister.ExchangeTransportSettings.ListForm",, ThisObject);
	
EndProcedure

&AtClient
Procedure DataAreasTransportExchangeSettings(Command)
	
	OpenForm("InformationRegister.DataAreasTransportExchangeSettings.ListForm",, ThisObject);
	
EndProcedure

&AtClient
Procedure DataExchangeRules(Command)
	
	OpenForm("InformationRegister.DataExchangeRules.ListForm",, ThisObject);
	
EndProcedure

&AtClient
Procedure UseDataSynchronizationOnChange(Item)
	
	If ConstantsSet.UseDataSynchronization = False Then
		ConstantsSet.OfflineSaaS = False;
		ConstantsSet.UseDataSynchronizationSaaSWithLocalApplication = False;
		ConstantsSet.UseDataSynchronizationSaaSWithApplicationInInternet = False;
	EndIf;
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure OfflineSaaSOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseDataSynchronizationSaaSWithApplicationInInternetOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseDataSynchronizationSaaSWithLocalApplicationOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
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

////////////////////////////////////////////////////////////////////////////////
// Calling the server

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

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
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		StandardSubsystemsClientServer.ExecutionResultAddNotificationOfOpenForms(Result, "Record_ConstantsSet", New Structure, ConstantName);
		// StandardSubsystems.ReportsVariants
		ReportsVariants.AddNotificationOnValueChangeConstants(Result, ConstantManager);
		// End StandardSubsystems.ReportsVariants
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.UseDataSynchronization" OR AttributePathToData = "" Then
		Items.DataSynchronizationSubordinatedGrouping.Enabled           = ConstantsSet.UseDataSynchronization;
		Items.GroupDataSynchronizationMonitorSynchronizationData.Enabled = ConstantsSet.UseDataSynchronization;
		Items.GroupTemporaryDirectoriesServersCluster.Enabled             = ConstantsSet.UseDataSynchronization;
	EndIf;
	
EndProcedure

#EndRegion
