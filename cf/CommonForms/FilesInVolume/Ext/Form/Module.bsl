
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Volume = Parameters.Volume;
	
	// Determine the available file storages.
	FillFileStoragesNames();
	
	If FileStoragesNames.Count() = 0 Then
		Raise NStr("en='File storages are not found.';ru='Не найдены хранилища файлов.'");
		
	ElsIf FileStoragesNames.Count() = 1 Then
		Items.FileStoragePresentation.Visible = False;
	EndIf;
	
	FileStorageName = CommonUse.CommonSettingsStorageImport(
		"CommonForm.FilesInVolume.SelectionByStorages", 
		String(Volume.UUID()) );
	
	If FileStorageName = ""
	 OR FileStoragesNames.FindByValue(FileStorageName) = Undefined Then
	
		FilesVersionItem = FileStoragesNames.FindByValue("FileVersions");
		
		If FilesVersionItem = Undefined Then
			FileStorageName = FileStoragesNames[0].Value;
			FileStoragePresentation = FileStoragesNames[0].Presentation;
		Else
			FileStorageName = FilesVersionItem.Value;
			FileStoragePresentation = FilesVersionItem.Presentation;
		EndIf;
	Else
		FileStoragePresentation = FileStoragesNames.FindByValue(FileStorageName).Presentation;
	EndIf;
	
	ConfigureDynamicList(FileStorageName);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If SaveStoragesSelectionSettings Then
		SaveFilterSettings(Volume, FileStorageName);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FileStoragePresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("FileStoragePresentationStartChoiceChoiceIsMade", ThisObject);
	ShowChooseFromList(NOTifyDescription, FileStoragesNames, Items.FileStoragePresentation,
		FileStoragesNames.FindByValue(FileStorageName));
		
EndProcedure

&AtClient
Procedure FileStoragePresentationStartChoiceChoiceIsMade(CurrentStorage, AdditionalParameters) Export
	
	If TypeOf(CurrentStorage) = Type("ValueListItem") Then
		FileStorageName = CurrentStorage.Value;
		FileStoragePresentation = CurrentStorage.Presentation;
		ConfigureDynamicList(FileStorageName);
		SaveStoragesSelectionSettings = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenFileCard();
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	OpenFileCard();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure ConfigureDynamicList(Val StorageName)
	
	QueryText =
	"SELECT
	|	StorageOfFiles.Ref AS Ref,
	|	StorageOfFiles.PictureIndex AS PictureIndex,
	|	StorageOfFiles.PathToFile AS PathToFile,
	|	StorageOfFiles.Size AS Size,
	|	StorageOfFiles.Author AS Author,
	|	&ThisIsAttachedFiles AS ThisIsAttachedFiles
	|FROM
	|	&CatalogName AS StorageOfFiles
	|WHERE
	|	StorageOfFiles.Volume = &Volume";
	
	QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + StorageName);
	QueryText = StrReplace(QueryText, "&ThisIsAttachedFiles", ?(
		Upper(StorageName) = Upper("FileVersions"), "FALSE", "TRUE"));
	
	List.QueryText = QueryText;
	List.Parameters.SetParameterValue("Volume", Volume);
	List.MainTable = "Catalog." + StorageName;
	
EndProcedure

&AtServer
Procedure FillFileStoragesNames()
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		MetadataCatalogs = Metadata.Catalogs;
		FileStoragesNames.Add(MetadataCatalogs.FileVersions.Name, MetadataCatalogs.FileVersions.Presentation());
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AttachedFiles") Then
		For Each Catalog IN Metadata.Catalogs Do
			If Right(Catalog.Name, 19) = "AttachedFiles" Then
				FileStoragesNames.Add(Catalog.Name, Catalog.Presentation());
			EndIf;
		EndDo;
	EndIf;
	
	FileStoragesNames.SortByPresentation();
	
EndProcedure

&AtServerNoContext
Procedure SaveFilterSettings(Volume, CurrentSettings)
	
	CommonUse.CommonSettingsStorageSave(
		"CommonForm.FilesInVolume.SelectionByStorages",
		String(Volume.UUID()),
		CurrentSettings);
	
EndProcedure

&AtClient
Procedure OpenFileCard()
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.ThisIsAttachedFiles Then
		If CommonUseClient.SubsystemExists("AttachedFiles") Then
			ModuleAttachedFilesClient = CommonUseClient.CommonModule("AttachedFilesClient");
			ModuleAttachedFilesClient.OpenAttachedFileForm(CurrentData.Ref);
		EndIf;
	Else
		ShowValue(, CurrentData.Ref);
	EndIf;
	
EndProcedure

#EndRegion
