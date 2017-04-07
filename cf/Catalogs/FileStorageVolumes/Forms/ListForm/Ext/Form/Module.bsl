
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.SettingMarkDeletionForm.OnlyInAllActions = False;
	EndIf;
	Items.TransferAllFilesInVolumes.Visible = CommonUse.SubsystemExists("StandardSubsystems.FileOperations");
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure EnableDisableMarkDeletion(Command)
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	StartMarkDeletionChange(Items.List.CurrentData);
	
EndProcedure

&AtClient
Procedure TransferAllFilesInVolumes(Command)
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.FileOperations") Then
		ModuleFileOperationsServiceClient = CommonUseClient.CommonModule("FileOperationsServiceClient");
		ModuleFileOperationsServiceClient.TransferAllFilesInVolumes();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure StartMarkDeletionChange(CurrentData)
	
	If CurrentData.DeletionMark Then
		QuestionText = NStr("en='Unmark ""%1"" for deletion?';ru='Снять с ""%1"" пометку на удаление?'");
	Else
		QuestionText = NStr("en='Mark ""%1"" for deletion?';ru='Пометить ""%1"" на удаление?'");
	EndIf;
	
	QuestionContent = New Array;
	QuestionContent.Add(PictureLib.Question32);
	QuestionContent.Add(StringFunctionsClientServer.SubstituteParametersInString(
		QuestionText, CurrentData.Description));
	
	ShowQueryBox(
		New NotifyDescription("ContinueMarkDeletionChange", ThisObject, CurrentData),
		New FormattedString(QuestionContent),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure ContinueMarkDeletionChange(Response, CurrentData) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Volume = Items.List.CurrentData.Ref;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Volume", Items.List.CurrentData.Ref);
	AdditionalParameters.Insert("DeletionMark", Undefined);
	AdditionalParameters.Insert("Queries", New Array());
	AdditionalParameters.Insert("FormID", UUID);
	
	PreparationForInstallationUnmarkingRemoval(Volume, AdditionalParameters);
	
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(
		AdditionalParameters.Queries, ThisObject, New NotifyDescription(
			"ContinueInstallationUnmarkingRemoval", ThisObject, AdditionalParameters));
	
EndProcedure

&AtServerNoContext
Procedure PreparationForInstallationUnmarkingRemoval(Volume, AdditionalParameters)
	
	LockDataForEdit(Volume, , AdditionalParameters.FormID);
	
	VolumeProperties = CommonUse.ObjectAttributesValues(
		Volume, "DeletionMark,FullPathWindows,FullPathLinux");
	
	AdditionalParameters.DeletionMark = VolumeProperties.DeletionMark;
	
	If AdditionalParameters.DeletionMark Then
		// Marked for deletion and it is required to unmark.
		
		Query = Catalogs.FileStorageVolumes.QueryOnExternalResourcesUseForVolume(
			Volume, VolumeProperties.FullPathWindows, VolumeProperties.FullPathLinux);
	Else
		// Not marked for deletion, it is required to mark.
		Query = WorkInSafeMode.QueryOnClearPermissionToUseExternalResources(Volume)
	EndIf;
	
	AdditionalParameters.Queries.Add(Query);
	
EndProcedure

&AtClient
Procedure ContinueInstallationUnmarkingRemoval(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		CompleteInstallationUnmarkingRemoval(AdditionalParameters);
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure CompleteInstallationUnmarkingRemoval(AdditionalParameters)
	
	Object = AdditionalParameters.Volume.GetObject();
	Object.SetDeletionMark(NOT AdditionalParameters.DeletionMark);
	Object.Write();
	
	UnlockDataForEdit(
	AdditionalParameters.Volume, AdditionalParameters.FormID);
	
EndProcedure

#EndRegion