#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalState

Var CurrentContainer;
Var CurrentSettingsStorageName;
Var CurrentSettingsStorage;
Var CurrentHandlers;

#EndRegion

#Region ServiceProgramInterface

Procedure Initialize(Container, SettingsStorageName, Handlers) Export
	
	CurrentContainer = Container;
	CurrentHandlers = Handlers;
	
	CurrentSettingsStorageName = SettingsStorageName;
	CurrentSettingsStorage = WorkInSafeMode.EvalInSafeMode(CurrentSettingsStorageName);
	
EndProcedure

Procedure ImportData() Export
	
	Cancel = False;
	CurrentHandlers.BeforeLoadSettingsStorage(
		CurrentContainer,
		CurrentSettingsStorageName,
		CurrentSettingsStorage,
		Cancel);
	
	If Not Cancel Then
		
		LoadSettingsToStandardStorage();
		
	EndIf;
	
	CurrentHandlers.AfterLoadSettingsStorage(
		CurrentContainer,
		CurrentSettingsStorageName,
		CurrentSettingsStorage);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure LoadSettingsToStandardStorage()
	
	FileName = CurrentContainer.GetFileFromDirectory(DataExportImportService.UserSettings(), CurrentSettingsStorageName);
	If FileName = Undefined Then 
		Return;
	EndIf;
	
	ReadStream = DataProcessors.DataExportImportInfobaseDataReadingStream.Create();
	ReadStream.OpenFile(FileName);
	
	While ReadStream.ReadInfobaseDataObject() Do
		
		Cancel = False;
		
		WriteSettings = ReadStream.CurrentObject();
		Artifacts = ReadStream.CurrentObjectArtifacts();
		
		SettingsKey = WriteSettings.SettingsKey;
		ObjectKey = WriteSettings.ObjectKey;
		User = WriteSettings.User;
		Presentation = WriteSettings.Presentation;
		
		If WriteSettings.SerializationThroughValueStorage Then
			Settings = WriteSettings.Settings.Get();
		Else
			Settings = WriteSettings.Settings;
		EndIf;
		
		CurrentHandlers.BeforeLoadSettings(
			CurrentContainer,
			CurrentSettingsStorageName,
			SettingsKey,
			ObjectKey,
			Settings,
			User,
			Presentation,
			Artifacts,
			Cancel);
		
		If Not Cancel Then
			
			SettingsDescription = New SettingsDescription;
			SettingsDescription.Presentation = Presentation;
			
			CurrentSettingsStorage.Save(
				ObjectKey,
				SettingsKey,
				Settings,
				SettingsDescription,
				User);
			
		EndIf;
		
		CurrentHandlers.AfterLoadSettings(
			CurrentContainer,
			CurrentSettingsStorageName,
			SettingsKey,
			ObjectKey,
			Settings,
			User,
			Presentation,
			Artifacts
		);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
