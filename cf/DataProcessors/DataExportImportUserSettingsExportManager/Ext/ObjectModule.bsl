#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalState

Var CurrentContainer;
Var CurrentHandlers;
Var CurrentSettingsStorageName;
Var CurrentSettingsStorage;
Var CurrentSerializer;

#EndRegion

#Region ServiceProgramInterface

Procedure Initialize(Container, SettingsStorageName, Handlers, Serializer) Export
	
	CurrentContainer = Container;
	CurrentSettingsStorageName = SettingsStorageName;
	CurrentHandlers = Handlers;
	CurrentSerializer = Serializer;
	
	CurrentSettingsStorage = WorkInSafeMode.EvalInSafeMode(SettingsStorageName);
	
EndProcedure

Procedure ExportData() Export
	
	If CurrentSettingsStorageName <> "SystemSettingsStorage" AND Metadata[CurrentSettingsStorageName] <> Undefined Then
		// Exports data only from standard settings storages.
		Return;
	EndIf;
	
	Cancel = False;
	CurrentHandlers.BeforeExportSettingsStorage(
		CurrentContainer,
		CurrentSerializer,
		CurrentSettingsStorageName,
		CurrentSettingsStorage,
		Cancel);
	
	If Not Cancel Then
		
		ExportSettingsStandardStorages();
		
	EndIf;
	
	CurrentHandlers.AfterExportSettingsStorage(
		CurrentContainer,
		CurrentSerializer,
		CurrentSettingsStorageName,
		CurrentSettingsStorage
	);
	
EndProcedure

Procedure Close() Export
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure ExportSettingsStandardStorages()
	
	FileName = CurrentContainer.CreateFile(
		DataExportImportService.UserSettings(),
		CurrentSettingsStorageName);
	
	WriteStream = DataProcessors.DataExportImportInfobaseDataWritingStream.Create();
	WriteStream.OpenFile(FileName, CurrentSerializer);
	
	// Exports settings only of existing info base users.
	IBUsers = InfobaseUsers.GetUsers();
	
	For Each IBUser IN IBUsers Do
	
		Selection = CurrentSettingsStorage.Select(New Structure("User", IBUser.Name));
		
		ToContinueTo = True;
		
		While ToContinueTo Do
			
			Try
				
				ToContinueTo = Selection.Next();
				
			Except
				
				WriteLogEvent(
					NStr("en='DataExportImport.SettingExportSkipped';ru='ВыгрузкаЗагрузкаДанных.ВыгрузкаНастройкиПропущена'", Metadata.DefaultLanguage.LanguageCode),
					EventLogLevel.Warning,,,
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='The setting export is skipped as the setting can not
		|be
		|read:
		|SettingsKey=%1
		|ObjectKey=%2 User=%3 Presentation=%4
		|';ru='Выгрузка настройки пропущена, т.к. настройка не может быть прочитана:
		|КлючНастроек=%1
		|КлючОбъекта=%2
		|Пользователь=%3
		|Представление=%4
		|'", Metadata.DefaultLanguage.LanguageCode),
						Selection.SettingsKey,
						Selection.ObjectKey,
						Selection.User,
						Selection.Presentation
					)
				);
				
				ToContinueTo = True;
				Continue;
				
			EndTry;
		
			ExportSettingsItem(
				WriteStream,
				Selection.SettingsKey,
				Selection.ObjectKey,
				Selection.User,
				Selection.Presentation,
				Selection.Settings);
		
		EndDo;
			
	EndDo;
	
	WriteStream.Close();
	
	ObjectCount = WriteStream.ObjectCount();
	If ObjectCount = 0 Then
		CurrentContainer.DeleteFile(FileName);
	Else
		CurrentContainer.SetObjectsQuantity(FileName, ObjectCount);
	EndIf;
	
EndProcedure

Procedure ExportSettingsItem(WriteStream, Val SettingsKey, Val ObjectKey, Val User, Val Presentation, Val Settings)
	
	Cancel = False;
	
	If FindDisallowedXMLCharacters(SettingsKey) > 0
		OR FindDisallowedXMLCharacters(ObjectKey) > 0
		OR FindDisallowedXMLCharacters(User) > 0
		OR FindDisallowedXMLCharacters(Presentation) > 0 Then
		
		WriteLogEvent(
			NStr("en='DataExportImport.SettingExportSkipped';ru='ВыгрузкаЗагрузкаДанных.ВыгрузкаНастройкиПропущена'", Metadata.DefaultLanguage.LanguageCode),
			EventLogLevel.Warning,,,
			NStr("en='Setting export is skipped as key parameters contain invalid characters.';ru='Выгрузка настройки пропущена, т.к. в ключевых параметрах содержатся недопустимые символы.'", Metadata.DefaultLanguage.LanguageCode));
		
		Cancel = True;
		
	EndIf;
	
	Artifacts = New Array();
	
	CurrentHandlers.BeforeExportSettings(
		CurrentContainer,
		CurrentSerializer,
		CurrentSettingsStorageName,
		SettingsKey,
		ObjectKey,
		Settings,
		User,
		Presentation,
		Artifacts,
		Cancel
	);
	
	SerializationThroughValueStorage = False;
	If Not SettingsSerializedInXDTO(Settings) Then
		Settings = New ValueStorage(Settings);
		SerializationThroughValueStorage = True;
	EndIf;
	
	If Not Cancel Then
		
		WriteSettings = New Structure();
		WriteSettings.Insert("SettingsKey", SettingsKey);
		WriteSettings.Insert("ObjectKey", ObjectKey);
		WriteSettings.Insert("User", User);
		WriteSettings.Insert("Presentation", Presentation);
		WriteSettings.Insert("SerializationThroughValueStorage", SerializationThroughValueStorage);
		WriteSettings.Insert("Settings", Settings);
		
		WriteStream.WriteInfobaseDataObject(WriteSettings, Artifacts);
		
	EndIf;
	
	CurrentHandlers.AfterExportSettings(
		CurrentContainer,
		CurrentSerializer,
		CurrentSettingsStorageName,
		SettingsKey,
		ObjectKey,
		Settings,
		User,
		Presentation
	);
	
EndProcedure

Function SettingsSerializedInXDTO(Val Settings)
	
	Result = True;
	
	Try
		
		StreamChecks = New XMLWriter();
		StreamChecks.SetString();
		
		XDTOSerializer.WriteXML(StreamChecks, Settings);
		
	Except
		
		Result = False;
		
	EndTry;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf