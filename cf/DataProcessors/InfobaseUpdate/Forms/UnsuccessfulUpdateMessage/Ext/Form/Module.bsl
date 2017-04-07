
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	WriteLogEvent(InfobaseUpdate.EventLogMonitorEvent(), EventLogLevel.Error,
		, , Parameters.DetailedErrorMessage);
	
	ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='An error occurred while updating
		|
		|application version: %1';ru='При обновлении версии
		|
		|программы возникла ошибка: %1'"),
		Parameters.AShortErrorMessage);
	
	Items.ErrorMessageText.Title = ErrorMessageText;
	
	UpdateBeginTime = Parameters.UpdateBeginTime;
	UpdateEndTime = CurrentSessionDate();
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Items.OpenExternalProcessingForm.Visible = False;
	EndIf;
	
	SessionTimeOffset = CurrentSessionDate() - CurrentDate(); // Except.
	
	SecurityProfilesAreUsed = GetFunctionalOption("SecurityProfilesAreUsed");
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ShowAdditionalInformationOnResultsOfUpdateClick(Item)
	
	FormParameters = New Structure;
	FormParameters.Insert("StartDate", UpdateBeginTime - SessionTimeOffset);
	FormParameters.Insert("EndDate", UpdateEndTime - SessionTimeOffset);
	FormParameters.Insert("RunNotInBackground", True);
	
	OpenForm("DataProcessor.EventLogMonitor.Form.EventLogMonitor", FormParameters);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Done(Command)
	Close(True);
EndProcedure

&AtClient
Procedure RestartApplication(Command)
	Close(False);
EndProcedure

&AtClient
Procedure OpenExternalDataProcessor(Command)
	
	If SecurityProfilesAreUsed Then
		
		OpenForm(
			"DataProcessor.PermissionSettingsForExternalResourcesUse.Form.OpenExternalDataProcessorsOrReportWithSecureModeSelection",
			,
			ThisObject,
			,
			,
			,
			,
			FormWindowOpeningMode.LockOwnerWindow);
		
		Return;
		
	EndIf;
	
#If WebClient Then
	Notification = New NotifyDescription("OpenExternalDataProcessorWithoutExtension", ThisObject);
	BeginPutFile(Notification,,, True, UUID);
	Return;
#EndIf
	
	FileOpeningDialog = New FileDialog(FileDialogMode.Open);
	FileOpeningDialog.Filter = NStr("en='External data processor';ru='Внешняя обработка'") + "(*.epf)|*.epf";
	FileOpeningDialog.Multiselect = False;
	FileOpeningDialog.Title = NStr("en='Choose external data processor';ru='Выберите внешнюю обработку'");
	
	NotifyDescription = New NotifyDescription("OpenExternalDataProcessorEnding", ThisObject);
	FileOpeningDialog.Show(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure OpenExternalDataProcessorEnding(Result, AdditionalParameters) Export
	
	If Result.Count() = 1 Then
		FullFileName = Result[0];
		SelectedDataProcessor = New BinaryData(FullFileName);
		AddressInTemporaryStorage = PutToTempStorage(SelectedDataProcessor, UUID);
		ExternalDataProcessorName = ConnectExternalDataProcessor(AddressInTemporaryStorage);
		OpenForm(ExternalDataProcessorName + ".Form");
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenExternalDataProcessorWithoutExtension(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		ExternalDataProcessorName = ConnectExternalDataProcessor(Address);
		OpenForm(ExternalDataProcessorName + ".Form",, ThisObject,,,,, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtServer
Function ConnectExternalDataProcessor(AddressInTemporaryStorage)
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise NStr("en='Insufficient access rights.';ru='Недостаточно прав доступа.'");
	EndIf;
	SelectedDataProcessor = GetFromTempStorage(AddressInTemporaryStorage);
	TempFileName = GetTempFileName("epf");
	SelectedDataProcessor.Write(TempFileName);
	Return ExternalDataProcessors.Create(TempFileName, False).Metadata().FullName();
EndFunction

#EndRegion
