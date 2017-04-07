
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Only subscriber administrator can create and disable offline workplace.
	If Not Users.InfobaseUserWithFullAccess() Then
		
		Raise NStr("en='The rights are not sufficient for setting the offline work.';ru='Недостаточно прав для настройки автономной работы.'");
		
	ElsIf Not OfflineWorkService.OfflineWorkSupported() Then
		
		Raise NStr("en='Possibility of autonomous work in the application is not provided.';ru='Возможность автономной работы в программе не предусмотрена.'");
		
	EndIf;
	
	UpdateMonitorBatteryLifeAtServer();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("UpdateMonitorBatteryLife", 60);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If    EventName = "Create_StandAloneWorkingPlace"
		OR EventName = "Record_StandaloneWorkstation"
		OR EventName = "Deletes_HotSeat" Then
		
		UpdateMonitorBatteryLife();
		
	ElsIf EventName = "ClosedFormDataExchangeResults" Then
		
		UpdateTransitionToConflictsTitle();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CreateOfflineWorkplace(Command)
	
	OpenForm("DataProcessor.OfflineWorkplaceCreationAssistant.Form.SettingOnServiceSide",, ThisObject, "1");
	
EndProcedure

&AtClient
Procedure StopSynchronizationWithOfflineWorkplace(Command)
	
	DisableIndividualWorkplace(OfflineWorkplace);
	
EndProcedure

&AtClient
Procedure StopSynchronizationWithOfflineWorkplaceInList(Command)
	
	CurrentData = Items.OfflineWorkplacesList.CurrentData;
	
	If CurrentData <> Undefined Then
		
		DisableIndividualWorkplace(CurrentData.OfflineWorkplace);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeOfflineWorkplace(Command)
	
	If OfflineWorkplace <> Undefined Then
		
		ShowValue(, OfflineWorkplace);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeOfflineWorkplaceInList(Command)
	
	CurrentData = Items.OfflineWorkplacesList.CurrentData;
	
	If CurrentData <> Undefined Then
		
		ShowValue(, CurrentData.OfflineWorkplace);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	UpdateMonitorBatteryLife();
	
EndProcedure

&AtClient
Procedure OfflineWorkplacesListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	ShowValue(, Items.OfflineWorkplacesList.CurrentData.OfflineWorkplace);
	
EndProcedure

&AtClient
Procedure HowToInstallOrUpdate1CEnterprisePlatformVersion(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateName", "HowToInstallOrUpdate1CEnterprisePlatformVersion");
	FormParameters.Insert("Title", NStr("en='How to install or update the 1C:Enterprise platform version';ru='Как установить или обновить версию платформы 1С:Предприятие'"));
	
	OpenForm("DataProcessor.OfflineWorkplaceCreationAssistant.Form.AdditionalDetails", FormParameters, ThisObject, "HowToInstallOrUpdate1CEnterprisePlatformVersion");
	
EndProcedure

&AtClient
Procedure HowToSetOfflineWorkplace(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TemplateName", "InstructionForSettingOfflineWorkplace");
	FormParameters.Insert("Title", NStr("en='Hot to configure the offline workplace';ru='Как настроить автономное рабочее место'"));
	
	OpenForm("DataProcessor.OfflineWorkplaceCreationAssistant.Form.AdditionalDetails", FormParameters, ThisObject, "InstructionForSettingOfflineWorkplace");
	
EndProcedure

&AtClient
Procedure GoToConflicts(Command)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ExchangeNodes", UsedNodesArray(OfflineWorkplace, OfflineWorkplacesList));
	
	OpenForm("InformationRegister.DataExchangeResults.Form.Form", OpenParameters);
	
EndProcedure

&AtClient
Procedure SentDataContent(Command)
	
	CurrentPage = Items.OfflineWork.CurrentPage;
	OfflineNode  = Undefined;
	
	If CurrentPage = Items.OneOfflineWorkplace Then
		OfflineNode = OfflineWorkplace;
		
	ElsIf CurrentPage = Items.SeveralOfflineWorkplaces Then
		CurrentData = Items.OfflineWorkplacesList.CurrentData;
		If CurrentData <> Undefined Then
			OfflineNode = CurrentData.OfflineWorkplace;
		EndIf;
		
	EndIf;
		
	If ValueIsFilled(OfflineNode) Then
		DataExchangeClient.OpenSentDataContent(OfflineNode);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure UpdateMonitorBatteryLifeAtServer()
	
	SetPrivilegedMode(True);
	
	OfflineWorkplaceCount = OfflineWorkService.OfflineWorkplaceCount();
	UpdateTransitionToConflictsTitle();
	
	If OfflineWorkplaceCount = 0 Then
		
		Items.OfflineWorkIsNotCustomized.Visible = True;
		
		Items.OfflineWork.CurrentPage = Items.OfflineWorkIsNotCustomized;
		Items.OneOfflineWorkplace.Visible = False;
		Items.SeveralOfflineWorkplaces.Visible = False;
		
	ElsIf OfflineWorkplaceCount = 1 Then
		
		Items.OneOfflineWorkplace.Visible = True;
		
		Items.OfflineWork.CurrentPage = Items.OneOfflineWorkplace;
		Items.OfflineWorkIsNotCustomized.Visible = False;
		Items.SeveralOfflineWorkplaces.Visible = False;
		
		OfflineWorkplace = OfflineWorkService.OfflineWorkplace();
		OfflineWorkplacesList.Clear();
		
		Items.InformationAboutLastSynchronization.Title = DataExchangeServer.SynchronizationDatePresentation(
			OfflineWorkService.LastSuccessfulSynchronizationDate(OfflineWorkplace)
		) + ".";
		
		Items.DataTransferRestrictionsDescriptionFull.Title = OfflineWorkService.DataTransferRestrictionsDescriptionFull(OfflineWorkplace);
		
	ElsIf OfflineWorkplaceCount > 1 Then
		
		Items.SeveralOfflineWorkplaces.Visible = True;
		
		Items.OfflineWork.CurrentPage = Items.SeveralOfflineWorkplaces;
		Items.OfflineWorkIsNotCustomized.Visible = False;
		Items.OneOfflineWorkplace.Visible = False;
		
		OfflineWorkplace = Undefined;
		OfflineWorkplacesList.Load(OfflineWorkService.OfflineWorkplacesMonitor());
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateTransitionToConflictsTitle()
	
	If DataExchangeReUse.UseVersioning() Then
		
		HeaderStructure = DataExchangeServer.HeaderStructureHyperlinkMonitorProblems(
			UsedNodesArray(OfflineWorkplace, OfflineWorkplacesList));
		
		FillPropertyValues (Items.GoToConflicts, HeaderStructure);
		FillPropertyValues (Items.GoToConflicts1, HeaderStructure);
		
	Else
		
		Items.GoToConflicts.Visible = False;
		Items.GoToConflicts1.Visible = False;
		
	EndIf;
	
EndProcedure

&AtClient
Function GetRowCurrentIndex(TableName)
	
	// Return value
	RowIndex = Undefined;
	
	// Determining the cursor position during the monitor update
	CurrentData = Items[TableName].CurrentData;
	
	If CurrentData <> Undefined Then
		
		RowIndex = ThisObject[TableName].IndexOf(CurrentData);
		
	EndIf;
	
	Return RowIndex;
EndFunction

&AtClient
Procedure RunCursorPositioning(TableName, RowIndex)
	
	If RowIndex <> Undefined Then
		
		// Checking the cursor position once new data is received
		If ThisObject[TableName].Count() <> 0 Then
			
			If RowIndex > ThisObject[TableName].Count() - 1 Then
				
				RowIndex = ThisObject[TableName].Count() - 1;
				
			EndIf;
			
			// Determining the cursor position
			Items[TableName].CurrentRow = ThisObject[TableName][RowIndex].GetID();
			
		EndIf;
		
	EndIf;
	
	// if it wasn't succeeded to position a string, we establish current the first string
	If Items[TableName].CurrentRow = Undefined
		AND ThisObject[TableName].Count() <> 0 Then
		
		Items[TableName].CurrentRow = ThisObject[TableName][0].GetID();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateMonitorBatteryLife()
	
	RowIndex = GetRowCurrentIndex("OfflineWorkplacesList");
	
	UpdateMonitorBatteryLifeAtServer();
	
	// Determining the cursor position
	RunCursorPositioning("OfflineWorkplacesList", RowIndex);
	
EndProcedure

&AtClientAtServerNoContext
Function UsedNodesArray(OfflineWorkplace, OfflineWorkplacesList)
	
	ExchangeNodes = New Array;
	
	If ValueIsFilled(OfflineWorkplace) Then
		ExchangeNodes.Add(OfflineWorkplace);
	Else
		For Each NodeString IN OfflineWorkplacesList Do
			ExchangeNodes.Add(NodeString.OfflineWorkplace);
		EndDo;
	EndIf;
	
	Return ExchangeNodes;
	
EndFunction

&AtClient
Procedure DisableIndividualWorkplace(DeactivatebleOfflineWorkplace)
	
	FormParameters = New Structure("OfflineWorkplace", DeactivatebleOfflineWorkplace);
	
	OpenForm("CommonForm.OfflineWorkplaceDisconnection", FormParameters, ThisObject, DeactivatebleOfflineWorkplace);
	
EndProcedure

#EndRegion
