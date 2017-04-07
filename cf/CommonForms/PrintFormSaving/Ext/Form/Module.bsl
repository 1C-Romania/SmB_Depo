
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// format list filling
	For Each SavingFormat IN PrintManagement.SpreadsheetDocumentSavingFormatsSettings() Do
		SelectedSavingFormats.Add(SavingFormat.SpreadsheetDocumentFileType, String(SavingFormat.Ref), False, SavingFormat.Picture);
	EndDo;
	SelectedSavingFormats[0].Check = True; // By default only the first format from the list is selected.
	
	// Filling selection list for file attachment to an object.
	For Each PrintObject IN Parameters.PrintObjects Do
		If CanAttachFilesToObject(PrintObject.Value) Then
			Items.SelectedObject.ChoiceList.Add(PrintObject.Value);
		EndIf;
	EndDo;
	
	// Default place for saving.
	SavingVariant = "SaveToFolder";
	
	// Visible setting
	ThisIsWebClient = CommonUseClientServer.ThisIsWebClient();
	ThereIsAttachmentOption = Items.SelectedObject.ChoiceList.Count() > 0;
	Items.SelectFileSavingPlace.Visible = Not ThisIsWebClient Or ThereIsAttachmentOption;
	Items.SavingVariant.Visible = ThereIsAttachmentOption;
	If Not ThereIsAttachmentOption Then
		Items.FolderForFilesSaving.TitleLocation = FormItemTitleLocation.Top;
	EndIf;
	Items.FolderForFilesSaving.Visible = Not ThisIsWebClient;
	
	// Default object for attachment.
	If ThereIsAttachmentOption Then
		SelectedObject = Items.SelectedObject.ChoiceList[0].Value;
	EndIf;
	Items.SelectedObject.ReadOnly = Items.SelectedObject.ChoiceList.Count() = 1;
	
EndProcedure

&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	
	SavingFromSettingsFormats = Settings["SelectedSavingFormats"];
	If SavingFromSettingsFormats <> Undefined Then
		For Each SelectedFormat IN SelectedSavingFormats Do 
			FormatFromSettings = SavingFromSettingsFormats.FindByValue(SelectedFormat.Value);
			If FormatFromSettings <> Undefined Then
				SelectedFormat.Check = FormatFromSettings.Check;
			EndIf;
		EndDo;
		Settings.Delete("SelectedSavingFormats");
	EndIf;
	
	If Items.SelectedObject.ChoiceList.Count() = 0 Then
		SettingSavingVariant = Settings["SavingVariant"];
		If SettingSavingVariant <> Undefined Then
			Settings.Delete("SavingVariant");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetSavingPlacePage();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure SavingVariantOnChange(Item)
	SetSavingPlacePage();
	ClearMessages();
EndProcedure

&AtClient
Procedure FolderForFilesSavingStartChoice(Item, ChoiceData, StandardProcessing)
	FolderChoiceDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	If Not IsBlankString(SelectedFolder) Then
		FolderChoiceDialog.Directory = SelectedFolder;
	EndIf;
	If FolderChoiceDialog.Choose() Then
		SelectedFolder = FolderChoiceDialog.Directory;
		ClearMessages();
	EndIf;
EndProcedure

&AtClient
Procedure SelectedObjectClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Save(Command)
	
	#If Not WebClient Then
	If SavingVariant = "SaveToFolder" AND IsBlankString(SelectedFolder) Then
		CommonUseClientServer.MessageToUser(NStr("en='It is necessary to specify the folder.';ru='Необходимо указать папку.'"),,"SelectedFolder");
		Return;
	EndIf;
	#EndIf
		
	SavingFormats = New Array;
	
	For Each SelectedFormat IN SelectedSavingFormats Do
		If SelectedFormat.Check Then
			SavingFormats.Add(SelectedFormat.Value);
		EndIf;
	EndDo;
	
	If SavingFormats.Count() = 0 Then
		ShowMessageBox(,NStr("en='It is necessary to specify at least one of the offered formats.';ru='Необходимо указать как минимум один из предложенных форматов.'"));
		Return;
	EndIf;
	
	ChoiceResult = New Structure;
	ChoiceResult.Insert("PackIntoArchive", PackIntoArchive);
	ChoiceResult.Insert("SavingFormats", SavingFormats);
	ChoiceResult.Insert("SavingVariant", SavingVariant);
	ChoiceResult.Insert("FolderForSaving", SelectedFolder);
	ChoiceResult.Insert("ObjectForAttaching", SelectedObject);
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetSavingPlacePage()
	
	#If WebClient Then
	Items.SelectedObject.Enabled = SavingVariant = "Join";
	#Else
	If SavingVariant = "Join" Then
		Items.GroupSavingPlace.CurrentPage = Items.AttachToObjectPage;
	Else
		Items.GroupSavingPlace.CurrentPage = Items.SavingIntoFolderPage;
	EndIf;
	#EndIf
	
EndProcedure

&AtServer
Function CanAttachFilesToObject(ObjectReference)
	Result = Undefined;
	
	PrintManagement.OnCanAttachFilesToObjectChecking(ObjectReference, Result);
	
	If Result = Undefined Then
		Result = False;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion
