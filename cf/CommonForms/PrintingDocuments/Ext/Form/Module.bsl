#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Var PrintFormsCollection;
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Users.RolesAvailable("ChangePrintFormsTemplates") Then
		Items.ButtonGoToTemplatesManagement.Visible = False;
	EndIf;
	
	// Check of input parameters.
	If Not ValueIsFilled(Parameters.DataSource) Then 
		CommonUseClientServer.Validate(TypeOf(Parameters.CommandParameter) = Type("Array") Or CommonUse.ReferenceTypeValue(Parameters.CommandParameter),
			StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='Invalid value of the CommandParameter parameter when calliing the PrintManagementClient.ExecutePrintCommand method.
		|Expected: Array, AnyRef.
		|Transferred: %1';ru='Недопустимое значение параметра ПараметрКоманды при вызове метода УправлениеПечатьюКлиент.ВыполнитьКомандуПечати.
		|Ожидалось: Массив, ЛюбаяСсылка.
		|Передано: %1'"), TypeOf(Parameters.CommandParameter)));
	EndIf;

	// Backward compatibility support with 2.1.3.
	PrintParameters = Parameters.PrintParameters;
	If Parameters.PrintParameters = Undefined Then
		PrintParameters = New Structure;
	EndIf;
	If Not PrintParameters.Property("AdditionalParameters") Then
		Parameters.PrintParameters = New Structure("AdditionalParameters", PrintParameters);
		For Each PrintParameter IN PrintParameters Do
			Parameters.PrintParameters.Insert(PrintParameter.Key, PrintParameter.Value);
		EndDo;
	EndIf;
	
	If Parameters.PrintFormsCollection = Undefined Then
		PrintFormsCollection = GeneratePrintForms(Parameters.TemplateNames, Cancel);
		If Cancel Then
			Return;
		EndIf;
	Else
		PrintFormsCollection = Parameters.PrintFormsCollection;
		PrintObjects = Parameters.PrintObjects;
		OutputParameters = PrintManagement.PrepareOutputParametersStructure();
	EndIf;
	
	CreateAttributesAndFormElementsForPrintForms(PrintFormsCollection);
	SaveDefaultSetSettings();
	LoadSettingsOfCopiesCount();
	IsAllowedOutput = IsAllowedOutput();
	ConfigureFormElementsVisible(IsAllowedOutput);
	SetOutputEnabledFlagInPrintFormsPresentations(IsAllowedOutput);
	SetPrinterNameInPrintButtonToolTip();
	SetFormTitle();
	If IsSetPrint() Then
		Items.copies.Title = NStr("en='Kit copies';ru='Копий комплекта'");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If ValueIsFilled(SavingFormatSettings) Then
		Cancel = True; // form opening abort
		SavePrintFormToFile();
	EndIf;
	SetCurrentPage();
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.PrintFormSaving") Then
		
		If ValueSelected <> Undefined AND ValueSelected <> DialogReturnCode.Cancel Then
			FilesInTemporaryStorage = PlaceSpreadsheetDocumentsToTemporaryStorage(ValueSelected);
			If ValueSelected.SavingVariant = "SaveToFolder" Then
				SavePrintFormsToFolder(FilesInTemporaryStorage, ValueSelected.FolderForSaving);
			Else
				WrittenObjects = AttachPrintFormsToObject(FilesInTemporaryStorage, ValueSelected.ObjectForAttaching);
				If WrittenObjects.Count() > 0 Then
					NotifyChanged(TypeOf(WrittenObjects[0]));
				EndIf;
				For Each WrittenObject IN WrittenObjects Do
					Notify("Record_AttachedFile", New Structure, WrittenObject);
				EndDo;
				Status(NStr("en='Saving has been successfully completed.';ru='Сохранение успешно завершено.'"));
			EndIf;
		EndIf;
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("CommonForm.AttachmentFormatSelection")
		Or Upper(ChoiceSource.FormName) = Upper("CommonForm.NewEmailPreparation") Then
		
		If ValueSelected <> Undefined AND ValueSelected <> DialogReturnCode.Cancel Then
			AttachmentsList = PlaceSpreadsheetDocumentsToTemporaryStorage(ValueSelected);
			SendingParameters = OutputParameters.SendingParameters;
			Recipients = SendingParameters.Recipient;
			If ValueSelected.Property("Recipients") Then
				Recipients = ValueSelected.Recipients;
			EndIf;
			
			NewLettersParameters = New Structure;
			NewLettersParameters.Insert("Recipient", Recipients);
			NewLettersParameters.Insert("Subject", SendingParameters.Subject);
			NewLettersParameters.Insert("Text", SendingParameters.Text);
			NewLettersParameters.Insert("Attachments", AttachmentsList);
			// SB. Begin
			BasisDocuments = PrintObjects.UnloadValues();
			NewLettersParameters.Insert("BasisDocuments", BasisDocuments);
			// SB. End
			NewLettersParameters.Insert("DeleteFilesAfterSend", True);
			
			ModuleWorkWithPostalMailClient = CommonUseClient.CommonModule("EmailOperationsClient");
			ModuleWorkWithPostalMailClient.CreateNewEmail(NewLettersParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not IsBlankString(SettingsKey) Then
		PrintFormsSettingsToSave = New Array;
		For Each PrintFormSetting IN PrintFormsSettings Do
			SettingToSave = New Structure;
			SettingToSave.Insert("TemplateName", PrintFormSetting.TemplateName);
			SettingToSave.Insert("Quantity", ?(PrintFormSetting.Print,PrintFormSetting.Quantity, 0));
			SettingToSave.Insert("PositionByDefault", PrintFormSetting.PositionByDefault);
			
			PrintFormsSettingsToSave.Add(SettingToSave);
		EndDo;
		
		SavePrintFormsSettings(SettingsKey, PrintFormsSettingsToSave);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	PrintFormSetting = CurrentPrintFormSetting();
	
	If EventName = "Record_PrintLayouts" 
		AND Source.FormOwner = ThisObject
		AND Parameter.MetadataObjectTemplateName = PrintFormSetting.PathToTemplate Then
			AttachIdleHandler("UpdateCurrentPrintingPlate",0.1,True);
	ElsIf (EventName = "RefusalToChangeLayout"
		Or Eventname = "CancelEditSpreadsheetDocument"
		AND Parameter.MetadataObjectTemplateName = PrintFormSetting.PathToTemplate)
		AND Source.FormOwner = ThisObject Then
			DisplayCurrentPrintFormState();
	ElsIf EventName = "Write_SpreadsheetDocument" 
		AND Parameter.MetadataObjectTemplateName = PrintFormSetting.PathToTemplate 
		AND Source.FormOwner = ThisObject Then
			Template = Parameter.SpreadsheetDocument;
			AddressTemplateInTemporaryStorage = PutToTempStorage(Template);
			WriteTemplate(Parameter.MetadataObjectTemplateName, AddressTemplateInTemporaryStorage);
			AttachIdleHandler("UpdateCurrentPrintingPlate",0.1,True);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CopiesOnChange(Item)
	If PrintFormsSettings.Count() = 1 Then
		PrintFormsSettings[0].Quantity = copies;
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_TableDocumentFieldOnActivateArea(Item)
	CalculateCellsAmount();
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersPrintFormsSettings

&AtClient
Procedure PrintFormsSettingsOnChange(Item)
	
	CanPrint = False;
	CanSave = False;
	
	For Each PrintFormSetting IN PrintFormsSettings Do
		PrintForm = ThisObject[PrintFormSetting.AttributeName];
		SpreadsheetDocumentField = Items[PrintFormSetting.AttributeName];
		
		CanPrint = CanPrint Or PrintFormSetting.Print AND PrintForm.TableHeight > 0
			AND SpreadsheetDocumentField.Output = UseOutput.Enable;
		
		CanSave = CanSave Or PrintFormSetting.Print AND PrintForm.TableHeight > 0
			AND SpreadsheetDocumentField.Output = UseOutput.Enable AND Not SpreadsheetDocumentField.Protection;
	EndDo;
	
	Items.ButtonPrintCommandPanel.Enabled = CanPrint;
	Items.ButtonPrintAllActions.Enabled = CanPrint;
	
	Items.ButtonSave.Enabled = CanSave;
	Items.SaveButtonAllActions.Enabled = CanSave;
	
	Items.ButtonSend.Enabled = CanSave;
	Items.SendButtonAllActions.Enabled = CanSave;
EndProcedure

&AtClient
Procedure PrintFormsSettingsOnActivateRow(Item)
	SetCurrentPage();
EndProcedure

&AtClient
Procedure PrintFormsSettingsCountRegulation(Item, Direction, StandardProcessing)
	PrintFormSetting = CurrentPrintFormSetting();
	PrintFormSetting.Print = PrintFormSetting.Quantity + Direction > 0;
EndProcedure

&AtClient
Procedure PrintFormsSettingsPrintOnChange(Item)
	PrintFormSetting = CurrentPrintFormSetting();
	If PrintFormSetting.Print AND PrintFormSetting.Quantity = 0 Then
		PrintFormSetting.Quantity = 1;
	EndIf;
EndProcedure

&AtClient
Procedure PrintFormsSettingsBeforeStartAdding(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Save(Command)
	FormParameters = New Structure;
	FormParameters.Insert("PrintObjects", PrintObjects);
	OpenForm("CommonForm.PrintFormSaving", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure Send(Command)
	
	SendPrintFormsByMail();
	
EndProcedure

&AtClient
Procedure GoToDocument(Command)
	
	ChoiceList = New ValueList;
	For Each PrintObject IN PrintObjects Do
		ChoiceList.Add(PrintObject.Presentation, String(PrintObject.Value));
	EndDo;
	
	NotifyDescription = New NotifyDescription("GoToDocumentEnd", ThisObject);
	ChoiceList.ShowChooseItem(NOTifyDescription, NStr("en='Go to print form';ru='Перейти к печатной форме'"));
	
EndProcedure

&AtClient
Procedure GoToTemplatesManagement(Command)
	OpenForm("InformationRegister.UserPrintTemplates.Form.PrintFormsTemplates");
EndProcedure

&AtClient
Procedure Print(Command)
	
	DocumentsTable = DocumentsTableForPrinting();
	
	PrintManagementClient.PrintSpreadsheetDocuments(DocumentsTable, PrintObjects,
		DocumentsTable.Count() > 1, ?(PrintFormsSettings.Count() > 1, copies, 1));
	
EndProcedure

&AtClient
Procedure ShowHideCopiesAmountSetting(Command)
	SetNumberOfCopiesSettingVisible();
EndProcedure

&AtClient
Procedure CheckAll(Command)
	SetResetFlags(True);
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	SetResetFlags(False);
EndProcedure

&AtClient
Procedure ResetSettings(Command)
	RestorePrintFormsSettings();
EndProcedure

&AtClient
Procedure ChangeTemplate(Command)
	OpenTemplateForEdit();
EndProcedure

&AtClient
Procedure SwitchEditing(Command)
	SwitchCurrentPrintFormEditing();
EndProcedure

&AtClient
Procedure CalculateAmount(Command)
	PrintFormSetting = CurrentPrintFormSetting();
	If PrintFormSetting <> Undefined Then
		SpreadsheetDocument = ThisObject[PrintFormSetting.AttributeName];
		SelectedAreas = StandardSubsystemsClient.SelectedAreas(SpreadsheetDocument);
		MarkedCellsAmount = CalculateSummServer(SpreadsheetDocument, SelectedAreas);
		Items.CalculateAmount.Enabled = False;
	EndIf;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PrintFormsSettings.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("PrintFormsSettings.Print");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.UnavailableCellTextColor);

EndProcedure

&AtServer
Function GeneratePrintForms(TemplateNames, Cancel)
	
	Result = Undefined;	
	// Generation of table documents.
	If ValueIsFilled(Parameters.DataSource) Then
		If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.PrintByExternalSource(Parameters.DataSource,
				Parameters.SourceParameters, Result, PrintObjects, OutputParameters);
		Else
			Cancel = True;
		EndIf;
	Else
		PrintingObjectsTypes = New Array;
		Parameters.PrintParameters.Property("PrintingObjectsTypes", PrintingObjectsTypes);
		PrintForms = PrintManagement.GeneratePrintForms(Parameters.PrintManagerName, TemplateNames,
			Parameters.CommandParameter, Parameters.PrintParameters.AdditionalParameters, PrintingObjectsTypes);
		PrintObjects = PrintForms.PrintObjects;
		OutputParameters = PrintForms.OutputParameters;
		Result = PrintForms.PrintFormsCollection;
	EndIf;
	
	// Setting the flag of printed form saving to file (do not open the form, immediately save to file).
	If TypeOf(Parameters.PrintParameters) = Type("Structure") AND Parameters.PrintParameters.Property("SavingFormat") Then
		FoundFormat = PrintManagement.SpreadsheetDocumentSavingFormatsSettings().Find(Parameters.PrintParameters.SavingFormat, "SpreadsheetDocumentFileType");
		If FoundFormat <> Undefined Then
			SavingFormatSettings = New Structure("SpreadsheetDocumentFileType,Presentation,Extension,Filter");
			FillPropertyValues(SavingFormatSettings, FoundFormat);
			SavingFormatSettings.Filter = SavingFormatSettings.Presentation + "|*." + SavingFormatSettings.Extension;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure LoadSettingsOfCopiesCount()
	
	SavedPrintFormsSettings = New Array;
	
	UseSavedSettings = True;
	If TypeOf(Parameters.PrintParameters) = Type("Structure") AND Parameters.PrintParameters.Property("OverrideUserCountSettings") Then
		UseSavedSettings = Not Parameters.PrintParameters.OverrideUserCountSettings;
	EndIf;
	
	If UseSavedSettings Then
		If ValueIsFilled(Parameters.DataSource) Then
			SettingsKey = String(Parameters.DataSource.UUID()) + "-" + Parameters.SourceParameters.CommandID;
		Else
			TemplateNames = Parameters.TemplateNames;
			If TypeOf(TemplateNames) = Type("Array") Then
				TemplateNames = StringFunctionsClientServer.RowFromArraySubrows(TemplateNames);
			EndIf;
			
			SettingsKey = Parameters.PrintManagerName + "-" + TemplateNames;
		EndIf;
		SavedPrintFormsSettings = CommonUse.CommonSettingsStorageImport("PrintFormsSettings", SettingsKey, New Array);
	EndIf;

	
	RestorePrintFormsSettings(SavedPrintFormsSettings);
	
	If IsSetPrint() Then
		copies = 1;
	Else
		If PrintFormsSettings.Count() > 0 Then
			copies = PrintFormsSettings[0].Quantity;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure CreateAttributesAndFormElementsForPrintForms(PrintFormsCollection)
	
	// Generation of attributes for table documents.
	NewFormAttributes = New Array;
	For PrintFormNumber = 1 To PrintFormsCollection.Count() Do
		AttributeName = "PrintForm" + Format(PrintFormNumber,"NG=0");
		FormAttribute = New FormAttribute(AttributeName, New TypeDescription("SpreadsheetDocument"),,PrintFormsCollection[PrintFormNumber - 1].TemplateSynonym);
		NewFormAttributes.Add(FormAttribute);
	EndDo;
	ChangeAttributes(NewFormAttributes);
	
	// Generation of pages with table documents in the form.
	PrintFormNumber = 0;
	AddedPrintFormsSettings = New Map;
	For Each FormAttribute IN NewFormAttributes Do
		PrintFormDescription = PrintFormsCollection[PrintFormNumber];
		
		// Table of print forms settings (beginning).
		NewPrintFormSetting = PrintFormsSettings.Add();
		NewPrintFormSetting.Presentation = PrintFormDescription.TemplateSynonym;
		NewPrintFormSetting.Print = PrintFormDescription.Copies > 0;
		NewPrintFormSetting.Quantity = PrintFormDescription.Copies;
		NewPrintFormSetting.TemplateName = PrintFormDescription.TemplateName;
		NewPrintFormSetting.PositionByDefault = PrintFormNumber;
		NewPrintFormSetting.Description = PrintFormDescription.TemplateSynonym;
		NewPrintFormSetting.PathToTemplate = PrintFormDescription.FullPathToTemplate;
		NewPrintFormSetting.FileNamePrintedForm = CommonUse.ValueToXMLString(PrintFormDescription.FileNamePrintedForm);
		
		PreviouslyAddedPrintFormSetting = AddedPrintFormsSettings[PrintFormDescription.TemplateName];
		If PreviouslyAddedPrintFormSetting = Undefined Then
			// Copying of tabular document into form attribute.
			AttributeName = FormAttribute.Name;
			ThisObject[AttributeName] = PrintFormDescription.SpreadsheetDocument;
			
			// Generation of pages for the table documents.
			PageName = "Page" + AttributeName;
			Page = Items.Add(PageName, Type("FormGroup"), Items.Pages);
			Page.Type= FormGroupType.Page;
			Page.Picture = PictureLib.SpreadsheetInsertPageBreak;
			Page.Title = PrintFormDescription.TemplateSynonym;
			Page.ToolTip = PrintFormDescription.TemplateSynonym;
			Page.Visible = ThisObject[AttributeName].TableHeight > 0;
			
			// Generation of items for the table documents.
			NewItem = Items.Add(AttributeName, Type("FormField"), Page);
			NewItem.Type = FormFieldType.SpreadsheetDocumentField;
			NewItem.TitleLocation = FormItemTitleLocation.None;
			NewItem.DataPath = AttributeName;
			NewItem.Output = CalculateOutputUse(PrintFormDescription.SpreadsheetDocument);
			NewItem.Edit = NewItem.Output = UseOutput.Enable AND Not PrintFormDescription.SpreadsheetDocument.ReadOnly;
			NewItem.Protection = PrintFormDescription.SpreadsheetDocument.Protection;
			NewItem.SetAction("OnActivateArea", "Attachable_TableDocumentFieldOnActivateArea");
			
			// Table of printing forms settings (continue).
			NewPrintFormSetting.PageName = PageName;
			NewPrintFormSetting.AttributeName = AttributeName;
			
			AddedPrintFormsSettings.Insert(NewPrintFormSetting.TemplateName, NewPrintFormSetting);
		Else
			NewPrintFormSetting.PageName = PreviouslyAddedPrintFormSetting.PageName;
			NewPrintFormSetting.AttributeName = PreviouslyAddedPrintFormSetting.AttributeName;
		EndIf;
		
		PrintFormNumber = PrintFormNumber + 1;
	EndDo;
	
EndProcedure

&AtServer
Function SaveDefaultSetSettings()
	For Each PrintFormSetting IN PrintFormsSettings Do
		FillPropertyValues(KitSettingsByDefault.Add(), PrintFormSetting);
	EndDo;
EndFunction

&AtServer
Procedure ConfigureFormElementsVisible(Val IsAllowedOutput)
	
	IsAllowedEdit = IsAllowedEdit();
	
	AvailableEmailSending = False;
	If CommonUse.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperations = CommonUse.CommonModule("EmailOperations");
		AvailableEmailSending = ModuleEmailOperations.AvailableEmailSending();
	EndIf;
	IsPossibleMailSend = IsAllowedOutput AND AvailableEmailSending;
	
	IsDataToPrint = IsDataToPrint();
	
	Items.ButtonGoToDocument.Visible = PrintObjects.Count() > 1;
	
	Items.ButtonSave.Visible = IsDataToPrint AND IsAllowedOutput AND IsAllowedEdit;
	Items.SaveButtonAllActions.Visible = Items.ButtonSave.Visible;
	
	Items.ButtonSend.Visible = IsPossibleMailSend AND IsDataToPrint AND IsAllowedEdit;
	Items.SendButtonAllActions.Visible = Items.ButtonSend.Visible;
	
	Items.ButtonPrintCommandPanel.Visible = IsAllowedOutput AND IsDataToPrint;
	Items.ButtonPrintAllActions.Visible = Items.ButtonPrintCommandPanel.Visible;
	
	Items.copies.Visible = IsAllowedOutput AND IsDataToPrint;
	Items.ButtonEditing.Visible = IsAllowedOutput AND IsDataToPrint AND IsAllowedEdit;
	
	Items.GroupAmount.Visible = IsDataToPrint;
	
	Items.ButtonShowHideKitSetting.Visible = IsSetPrint();
	Items.PrintFormsSettings.Visible = IsSetPrint();
	Items.GroupKitSettingPopup.Visible = IsSetPrint();
	
	KitSettingAvailable = True;
	If TypeOf(Parameters.PrintParameters) = Type("Structure") AND Parameters.PrintParameters.Property("FixedKit") Then
		KitSettingAvailable = Not Parameters.PrintParameters.FixedKit;
	EndIf;
	
	Items.GroupKitSettingContextMenu.Visible = KitSettingAvailable;
	Items.GroupKitSettingPopup.Visible = IsSetPrint() AND KitSettingAvailable;
	Items.PrintFormsSettingsToPrint.Visible = KitSettingAvailable;
	Items.PrintFormsSettingsQuantity.Visible = KitSettingAvailable;
	Items.PrintFormsSettings.Header = KitSettingAvailable;
	Items.PrintFormsSettings.HorizontalLines = KitSettingAvailable;
	
	If Not KitSettingAvailable Then
		AddNumberOfInstancesInPrintFormsPresentations();
	EndIf;
	
	IsTemplatesChangingAvailable = Users.RolesAvailable("ChangePrintFormsTemplates") AND IsEditableTemplates();
	Items.ButtonChangeTemplate.Visible = IsTemplatesChangingAvailable AND IsDataToPrint;
	
	// Disabling the "technological" page is required only in the designer mode to modify form design.
	Items.PagePrintFormExample.Visible = False;

EndProcedure

&AtServer
Procedure AddNumberOfInstancesInPrintFormsPresentations()
	For Each PrintFormSetting IN PrintFormsSettings Do
		If PrintFormSetting.Quantity <> 1 Then
			PrintFormSetting.Presentation = PrintFormSetting.Presentation 
				+ " (" + PrintFormSetting.Quantity + " " + NStr("en='copy.';ru='экз.'") + ")";
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure SetOutputEnabledFlagInPrintFormsPresentations(IsAllowedOutput)
	If IsAllowedOutput Then
		For Each PrintFormSetting IN PrintFormsSettings Do
			SpreadsheetDocumentField = Items[PrintFormSetting.AttributeName];
			If SpreadsheetDocumentField.Output = UseOutput.Disable Then
				PrintFormSetting.Presentation = PrintFormSetting.Presentation + " (" + NStr("en='output disabled';ru='вывод не доступен'") + ")";
			ElsIf SpreadsheetDocumentField.Protection Then
				PrintFormSetting.Presentation = PrintFormSetting.Presentation + " (" + NStr("en='Only printing';ru='только печать'") + ")";
			EndIf;
		EndDo;
	EndIf;	
EndProcedure

&AtClient
Procedure SetNumberOfCopiesSettingVisible(Val Visible = Undefined)
	If Visible = Undefined Then
		Visible = Not Items.PrintFormsSettings.Visible;
	EndIf;
	
	Items.PrintFormsSettings.Visible = Visible;
	Items.GroupKitSettingPopup.Visible = Visible AND KitSettingAvailable;
EndProcedure

&AtServer
Procedure SetPrinterNameInPrintButtonToolTip()
	If PrintFormsSettings.Count() > 0 Then
		PrinterName = ThisObject[PrintFormsSettings[0].AttributeName].PrinterName;
		If Not IsBlankString(PrinterName) Then
			ThisObject.Commands["Print"].ToolTip = NStr("en='Print on printer';ru='Напечатать на принтере'") + " (" + PrinterName + ")";
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure SetFormTitle()
	Var FormTitle;
	
	If TypeOf(Parameters.PrintParameters) = Type("Structure") Then
		Parameters.PrintParameters.Property("FormTitle", FormTitle);
	EndIf;
	
	If ValueIsFilled(FormTitle) Then
		Title = FormTitle;
	Else
		If IsSetPrint() Then
			Title = NStr("en='Set print';ru='Печать комплекта'");
		ElsIf TypeOf(Parameters.CommandParameter) <> Type("Array") Or Parameters.CommandParameter.Count() > 1 Then
			Title = NStr("en='Printing Documents';ru='Печать документов'");
		Else
			Title = NStr("en='Document print';ru='Печать документа'");
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure SetCurrentPage()
	
	PrintFormSetting = CurrentPrintFormSetting();
	
	CurrentPage = Items.PagePrintFormUnavailable;
	PrintFormAccessible = PrintFormSetting <> Undefined AND ThisObject[PrintFormSetting.AttributeName].TableHeight > 0;
	If PrintFormAccessible Then
		CurrentPage = Items[PrintFormSetting.PageName];
	EndIf;
	Items.Pages.CurrentPage = CurrentPage;
	
	Items.GroupAmount.Enabled = PrintFormAccessible;
	CalculateCellsAmount();
	
	SwitchEditButtonMark();
	SetChangeTemplateEnabled();
	
EndProcedure

&AtClient
Procedure SetResetFlags(Check)
	For Each PrintFormSetting IN PrintFormsSettings Do
		PrintFormSetting.Print = Check;
		If Check AND PrintFormSetting.Quantity = 0 Then
			PrintFormSetting.Quantity = 1;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Function CalculateOutputUse(SpreadsheetDocument)
	If SpreadsheetDocument.Output = UseOutput.Auto Then
		Return ?(AccessRight("Output", Metadata), UseOutput.Enable, UseOutput.Disable);
	Else
		Return SpreadsheetDocument.Output;
	EndIf;
EndFunction

&AtServerNoContext
Procedure SavePrintFormsSettings(SettingsKey, PrintFormsSettingsToSave)
	CommonUse.CommonSettingsStorageSave("PrintFormsSettings", SettingsKey, PrintFormsSettingsToSave);
EndProcedure

&AtServer
Procedure RestorePrintFormsSettings(SavedPrintFormsSettings = Undefined)
	If SavedPrintFormsSettings = Undefined Then
		SavedPrintFormsSettings = KitSettingsByDefault;
	EndIf;
	
	If SavedPrintFormsSettings = Undefined Then
		Return;
	EndIf;
	
	For Each SavedSetting IN SavedPrintFormsSettings Do
		FoundSettings = PrintFormsSettings.FindRows(New Structure("PositionByDefault", SavedSetting.PositionByDefault));
		For Each PrintFormSetting IN FoundSettings Do
			RowIndex = PrintFormsSettings.IndexOf(PrintFormSetting);
			PrintFormsSettings.Move(RowIndex, PrintFormsSettings.Count()-1 - RowIndex); // shift to the end
			PrintFormSetting.Quantity = SavedSetting.Quantity;
			PrintFormSetting.Print = PrintFormSetting.Quantity > 0;
		EndDo;
	EndDo;
EndProcedure

&AtServer
Function PlaceSpreadsheetDocumentsToTemporaryStorage(SavingSettings)
	Var ZipFileWriter, ArchiveName;
	
	Result = New Array;
	
	// preparation of the archive
	If SavingSettings.PackIntoArchive Then
		ArchiveName = GetTempFileName("zip");
		ZipFileWriter = New ZipFileWriter(ArchiveName);
	EndIf;
	
	// preparation of temporary folders
	TempFolderName = GetTempFileName();
	CreateDirectory(TempFolderName);
	UsedFilesNames = New Map;
	
	SelectedSavingFormats = SavingSettings.SavingFormats;
	FormatsTable = PrintManagement.SpreadsheetDocumentSavingFormatsSettings();
	
	// saving print forms
	ProcessedPrintForms = New Array;
	For Each PrintFormSetting IN PrintFormsSettings Do
		
		If Not PrintFormSetting.Print Then
			Continue;
		EndIf;
		
		PrintForm = ThisObject[PrintFormSetting.AttributeName];
		If ProcessedPrintForms.Find(PrintForm) = Undefined Then
			ProcessedPrintForms.Add(PrintForm);
		Else
			Continue;
		EndIf;
		
		If CalculateOutputUse(PrintForm) = UseOutput.Disable Then
			Continue;
		EndIf;
		
		If PrintForm.Protection Then
			Continue;
		EndIf;
		
		If PrintForm.TableHeight = 0 Then
			Continue;
		EndIf;
		
		PrintFormsByObjects = PrintFormsByObjects(PrintForm);
		For Each ObjectMatchToPrintedForm IN PrintFormsByObjects Do
			PrintForm = ObjectMatchToPrintedForm.Value;
			For Each FileType IN SelectedSavingFormats Do
				FormatSettings = FormatsTable.FindRows(New Structure("SpreadsheetDocumentFileType", FileType))[0];
				
				If ObjectMatchToPrintedForm.Key <> "PrintObjectsNotSpecified" Then
					FileName = ObjectPrintedFormFileName(ObjectMatchToPrintedForm.Key, CommonUse.ValueFromXMLString(PrintFormSetting.FileNamePrintedForm));
					If FileName = Undefined Then
						FileName = DefaultPrintedFormFileName(ObjectMatchToPrintedForm.Key, PrintFormSetting.Description);
					EndIf;
					FileName = FileName + "." + FormatSettings.Extension;
					FileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(FileName);
				Else
					FileName = GetTempFileNameForPrintForm(PrintFormSetting.Description,FormatSettings.Extension,UsedFilesNames);
				EndIf;
				
				FullFileName = UniqueFileName(CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + FileName);
				PrintForm.Write(FullFileName, FileType);
				
				If FileType = SpreadsheetDocumentFileType.HTML Then
					InsertImagesToHTML(FullFileName);
				EndIf;
				
				If ZipFileWriter <> Undefined Then 
					ZipFileWriter.Add(FullFileName);
				Else
					BinaryData = New BinaryData(FullFileName);
					PathInTemStorage = PutToTempStorage(BinaryData, ThisObject.UUID);
					FileDescription = New Structure;
					FileDescription.Insert("Presentation", FileName);
					FileDescription.Insert("AddressInTemporaryStorage", PathInTemStorage);
					If FileType = SpreadsheetDocumentFileType.ANSITXT Then
						FileDescription.Insert("Encoding", "windows-1251");
					EndIf;
					Result.Add(FileDescription);
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	// If the archive is prepared, we record and place it into the temporary storage.
	If ZipFileWriter <> Undefined Then 
		ZipFileWriter.Write();
		FileOfArchive = New File(ArchiveName);
		BinaryData = New BinaryData(ArchiveName);
		PathInTemStorage = PutToTempStorage(BinaryData, ThisObject.UUID);
		FileDescription = New Structure;
		FileDescription.Insert("Presentation", GetFileNameForArchive());
		FileDescription.Insert("AddressInTemporaryStorage", PathInTemStorage);
		Result.Add(FileDescription);
	EndIf;
	
	DeleteFiles(TempFolderName);
	
	Return Result;
	
EndFunction

&AtServer
Function PrintFormsByObjects(PrintForm)
	If PrintObjects.Count() = 0 Then
		Return New Structure("PrintObjectsNotSpecified", PrintForm);
	EndIf;
		
	Result = New Map;
	For Each PrintObject IN PrintObjects Do
		AreaName = PrintObject.Presentation;
		Area = PrintForm.Areas.Find(AreaName);
		If Area = Undefined Then
			Continue;
		EndIf;
		SpreadsheetDocument = PrintForm.GetArea(Area.Top, , Area.Bottom);
		FillPropertyValues(SpreadsheetDocument, PrintForm,
			"FitToPage,Output,PageHeight,DuplexPrinting,Protection,PrinterName,TemplateLanguageCode,Copies,PrintScale,PageOrientation,TopMargin,LeftMargin,BottomMargin,RightMargin,Collate,HeaderSize,FooterSize,PageSize,PrintAccuracy,BlackAndWhite,PageWidth,PerPage");
		Result.Insert(PrintObject.Value, SpreadsheetDocument);
	EndDo;
	Return Result;
EndFunction

&AtServer
Procedure InsertImagesToHTML(HTMLFileName)
	
	TextDocument = New TextDocument();
	TextDocument.Read(HTMLFileName, TextEncoding.UTF8);
	HTMLText = TextDocument.GetText();
	
	HTMLFile = New File(HTMLFileName);
	
	ImagesFolderName = HTMLFile.BaseName + "_files";
	PathToImagesFolder = StrReplace(HTMLFile.FullName, HTMLFile.Name, ImagesFolderName);
	
	// It is expected that the folder will contain only images.
	ImageFiles = FindFiles(PathToImagesFolder, "*");
	
	For Each PictureFile IN ImageFiles Do
		ImageAsText = Base64String(New BinaryData(PictureFile.FullName));
		ImageAsText = "data:image/" + Mid(PictureFile.Extension,2) + ";base64," + Chars.LF + ImageAsText;
		
		HTMLText = StrReplace(HTMLText, ImagesFolderName + "\" + PictureFile.Name, ImageAsText);
	EndDo;
		
	TextDocument.SetText(HTMLText);
	TextDocument.Write(HTMLFileName, TextEncoding.UTF8);
	
EndProcedure

&AtServer
Function ObjectPrintedFormFileName(PrintObject, FileNamePrintedForm)
	If TypeOf(FileNamePrintedForm) = Type("Map") Then
		Return String(FileNamePrintedForm[PrintObject]);
	ElsIf TypeOf(FileNamePrintedForm) = Type("String") AND Not IsBlankString(FileNamePrintedForm) Then
		Return FileNamePrintedForm;
	Else
		Return Undefined;
	EndIf;
EndFunction

&AtServer
Function DefaultPrintedFormFileName(PrintObject, PrintedFormName)
	
	If CommonUse.ThisIsDocument(Metadata.FindByType(TypeOf(PrintObject))) Then
		ParametersForInsert = CommonUse.ObjectAttributesValues(PrintObject, "Date,Number");
		If CommonUse.SubsystemExists("StandardSubsystems.ObjectPrefixation") Then
			ModuleObjectPrefixationClientServer = CommonUse.CommonModule("ObjectPrefixationClientServer");
			ParametersForInsert.Number = ModuleObjectPrefixationClientServer.GetNumberForPrinting(ParametersForInsert.Number);
		EndIf;
		ParametersForInsert.Date = Format(ParametersForInsert.Date, "DLF=D");
		ParametersForInsert.Insert("PrintedFormName", PrintedFormName);
		Pattern = NStr("en='[PrintingFormName] # [Number] dated [Date]';ru='[НазваниеПечатнойФормы] № [Номер] от [Дата]'");
	Else
		ParametersForInsert = New Structure;
		ParametersForInsert.Insert("PrintedFormName",PrintedFormName);
		ParametersForInsert.Insert("ObjectPresentation", CommonUse.SubjectString(PrintObject));
		ParametersForInsert.Insert("CurrentDate",Format(CurrentSessionDate(), "DLF=D"));
		Pattern = NStr("en='[PrintedFormName] - [ObjectPresentation] - [CurrentDate]';ru='[НазваниеПечатнойФормы] - [ПредставлениеОбъекта] - [ТекущаяДата]'");
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersInStringByName(Pattern, ParametersForInsert);
	
EndFunction

&AtServer
Function GetFileNameForArchive()
	
	Result = "";
	
	For Each PrintFormSetting IN PrintFormsSettings Do
		
		If Not PrintFormSetting.Print Then
			Continue;
		EndIf;
		
		PrintForm = ThisObject[PrintFormSetting.AttributeName];
		
		If CalculateOutputUse(PrintForm) = UseOutput.Disable Then
			Continue;
		EndIf;
		
		If IsBlankString(Result) Then
			Result = PrintFormSetting.Description;
		Else
			Result = NStr("en='Documents';ru='Документы'");
			Break;
		EndIf;
	EndDo;
	
	Return Result + ".zip";
	
EndFunction

&AtClient
Procedure SavePrintFormToFile()
	
	SavingFormats = New Array;
	SavingFormats.Add(SavingFormatSettings.SpreadsheetDocumentFileType);
	SavingSettings = New Structure("SavingFormats,PackIntoArchive", SavingFormats, False);
	FilesInTemporaryStorage = PlaceSpreadsheetDocumentsToTemporaryStorage(SavingSettings);
	
	For Each FileToSave IN FilesInTemporaryStorage Do
		#If WebClient Then
		GetFile(FileToSave.AddressInTemporaryStorage, FileToSave.Presentation);
		#Else
		TempFileName = GetTempFileName(SavingFormatSettings.Extension);
		BinaryData = GetFromTempStorage(FileToSave.AddressInTemporaryStorage);
		BinaryData.Write(TempFileName);
		RunApp(TempFileName);
		#EndIf
	EndDo;
	
EndProcedure

&AtClient
Procedure SavePrintFormsToFolder(FilesListInTempStorage, Val Folder = "")
	
	#If WebClient Then
		For Each FileToSave IN FilesListInTempStorage Do
			GetFile(FileToSave.AddressInTemporaryStorage, FileToSave.Presentation);
		EndDo;
		Return;
	#EndIf
	
	Folder = CommonUseClientServer.AddFinalPathSeparator(Folder);
	For Each FileToSave IN FilesListInTempStorage Do
		BinaryData = GetFromTempStorage(FileToSave.AddressInTemporaryStorage);
		BinaryData.Write(UniqueFileName(Folder + FileToSave.Presentation));
	EndDo;
	
	Status(NStr("en='Saving has been successfully completed.';ru='Сохранение успешно завершено.'"), , NStr("en='to folder:';ru='в папку:'") + " " + Folder);
	
EndProcedure

&AtClientAtServerNoContext
Function UniqueFileName(FileName)
	
	File = New File(FileName);
	BaseName = File.BaseName;
	Extension = File.Extension;
	Folder = File.Path;
	
	Counter = 1;
	While File.Exist() Do
		Counter = Counter + 1;
		File = New File(Folder + BaseName + " (" + Counter + ")" + Extension);
	EndDo;
	
	Return File.FullName;
	
EndFunction

&AtServer
Function AttachPrintFormsToObject(FilesInTemporaryStorage, ObjectForAttaching)
	Result = New Array;
	If CommonUse.SubsystemExists("StandardSubsystems.AttachedFiles") Then
		ModuleAttachedFiles = CommonUse.CommonModule("AttachedFiles");
		For Each File IN FilesInTemporaryStorage Do
			Result.Add(ModuleAttachedFiles.AddFile(ObjectForAttaching, 
				File.Presentation, , , , File.AddressInTemporaryStorage, , NStr("en='Print form';ru='Печатная форма'")));
		EndDo;
	EndIf;
	Return Result;
EndFunction

&AtServer
Function IsSetPrint()
	Return PrintFormsSettings.Count() > 1;
EndFunction

&AtServer
Function IsAllowedOutput()
	
	For Each PrintFormSetting IN PrintFormsSettings Do
		If Items[PrintFormSetting.AttributeName].Output = UseOutput.Enable Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Function IsAllowedEdit()
	
	For Each PrintFormSetting IN PrintFormsSettings Do
		If Items[PrintFormSetting.AttributeName].Protection = False Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtClient
Function MoreThenOneRecipient(Recipient)
	If TypeOf(Recipient) = Type("Array") Or TypeOf(Recipient) = Type("ValueList") Then
		Return Recipient.Count() > 1;
	Else
		Return CommonUseClientServer.EmailsFromString(Recipient).Count() > 1;
	EndIf;
EndFunction

&AtServer
Function IsDataToPrint()
	Result = False;
	For Each PrintFormSetting IN PrintFormsSettings Do
		Result = Result Or ThisObject[PrintFormSetting.AttributeName].TableHeight > 0;
	EndDo;
	Return Result;
EndFunction

&AtServer
Function IsEditableTemplates()
	Result = False;
	For Each PrintFormSetting IN PrintFormsSettings Do
		Result = Result Or Not IsBlankString(PrintFormSetting.PathToTemplate);
	EndDo;
	Return Result;
EndFunction

&AtClient
Procedure OpenTemplateForEdit()
	
	PrintFormSetting = CurrentPrintFormSetting();
	
	DisplayCurrentPrintFormState(NStr("en='Template is edited';ru='Макет редактируется'"));
	
	MetadataObjectTemplateName = PrintFormSetting.PathToTemplate;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("MetadataObjectTemplateName", MetadataObjectTemplateName);
	OpenParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	OpenParameters.Insert("DocumentName", PrintFormSetting.Presentation);
	OpenParameters.Insert("TemplateType", "MXL");
	OpenParameters.Insert("Edit", True);
	
	OpenForm("CommonForm.EditSpreadsheetDocument", OpenParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure DisplayCurrentPrintFormState(StatusText = "")
	
	ShowStatus = Not IsBlankString(StatusText);
	
	PrintFormSetting = CurrentPrintFormSetting();
	If PrintFormSetting = Undefined Then
		Return;
	EndIf;
	
	SpreadsheetDocumentField = Items[PrintFormSetting.AttributeName];
	
	StatePresentation = SpreadsheetDocumentField.StatePresentation;
	StatePresentation.Text = StatusText;
	StatePresentation.Visible = ShowStatus;
	StatePresentation.AdditionalShowMode = 
		?(ShowStatus, AdditionalShowMode.Irrelevance, AdditionalShowMode.DontUse);
		
	SpreadsheetDocumentField.ReadOnly = ShowStatus Or SpreadsheetDocumentField.Output = UseOutput.Disable;
	
EndProcedure

&AtClient
Procedure SwitchCurrentPrintFormEditing()
	PrintFormSetting = CurrentPrintFormSetting();
	If PrintFormSetting <> Undefined Then
		SpreadsheetDocumentField = Items[PrintFormSetting.AttributeName];
		SpreadsheetDocumentField.Edit = Not SpreadsheetDocumentField.Edit;
		SwitchEditButtonMark();
	EndIf;
EndProcedure

&AtClient
Procedure SwitchEditButtonMark()
	
	PrintFormAccessible = Items.Pages.CurrentPage <> Items.PagePrintFormUnavailable;
	
	EditPossible = False;
	Check = False;
	
	PrintFormSetting = CurrentPrintFormSetting();
	If PrintFormSetting <> Undefined Then
		SpreadsheetDocumentField = Items[PrintFormSetting.AttributeName];
		EditPossible = PrintFormAccessible AND Not SpreadsheetDocumentField.Protection;
		Check = SpreadsheetDocumentField.Edit AND EditPossible;
	EndIf;
	
	Items.ButtonEditing.Check = Check;
	Items.ButtonEditing.Enabled = EditPossible;
	
EndProcedure

&AtClient
Procedure SetChangeTemplateEnabled()
	PrintFormAccessible = Items.Pages.CurrentPage <> Items.PagePrintFormUnavailable;
	PrintFormSetting = CurrentPrintFormSetting();
	Items.ButtonChangeTemplate.Enabled = PrintFormAccessible AND Not IsBlankString(PrintFormSetting.PathToTemplate);
EndProcedure

&AtClient
Procedure UpdateCurrentPrintingPlate()
	
	PrintFormSetting = CurrentPrintFormSetting();
	If PrintFormSetting = Undefined Then
		Return;
	EndIf;
	
	RegeneratePrintForm(PrintFormSetting.TemplateName, PrintFormSetting.AttributeName);
	DisplayCurrentPrintFormState();
	
EndProcedure

&AtServer
Procedure RegeneratePrintForm(TemplateName, AttributeName)
	
	Cancel = False;
	PrintFormsCollection = GeneratePrintForms(TemplateName, Cancel);
	If Cancel Then
		Raise NStr("en='Print form has not been regenerated.';ru='Печатная форма не была переформирована.'");
	EndIf;
	
	For Each PrintForm IN PrintFormsCollection Do
		If PrintForm.TemplateName = TemplateName Then
			ThisObject[AttributeName] = PrintForm.SpreadsheetDocument;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function CurrentPrintFormSetting()
	Result = Items.PrintFormsSettings.CurrentData;
	If Result = Undefined AND PrintFormsSettings.Count() > 0 Then
		Result = PrintFormsSettings[0];
	EndIf;
	Return Result;
EndFunction

&AtServerNoContext
Procedure WriteTemplate(MetadataObjectTemplateName, AddressTemplateInTemporaryStorage)
	PrintManagement.WriteTemplate(MetadataObjectTemplateName, AddressTemplateInTemporaryStorage);
EndProcedure

&AtClient
Procedure GoToDocumentEnd(SelectedItem, AdditionalParameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
	
	For Each PrintFormSetting IN PrintFormsSettings Do
		SpreadsheetDocumentField = Items[PrintFormSetting.AttributeName];
		SpreadsheetDocument = ThisObject[PrintFormSetting.AttributeName];
		SelectedDocumentRegion = SpreadsheetDocument.Areas.Find(SelectedItem.Value);
		
		SpreadsheetDocumentField.CurrentArea = SpreadsheetDocument.Area("R1C1"); // transition to the beginning
		
		If SelectedDocumentRegion <> Undefined Then
			SpreadsheetDocumentField.CurrentArea = SpreadsheetDocument.Area(SelectedDocumentRegion.Top,,SelectedDocumentRegion.Bottom,);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SendPrintFormsByMail()
	NotifyDescription = New NotifyDescription("SendPrintFormsByMailAccountSetupOffered", ThisObject);
	If CommonUseClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleWorkWithPostalMailClient = CommonUseClient.CommonModule("EmailOperationsClient");
		ModuleWorkWithPostalMailClient.VerifyAccountForEmailSending(NOTifyDescription);
	EndIf;
EndProcedure

&AtClient
Procedure SendPrintFormsByMailAccountSetupOffered(UserAccountIsConfigured, AdditionalParameters) Export
	
	If UserAccountIsConfigured <> True Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	OpenableFormName = "CommonForm.AttachmentFormatSelection";
	If MoreThenOneRecipient(OutputParameters.SendingParameters.Recipient) Then
		FormParameters.Insert("Recipients", OutputParameters.SendingParameters.Recipient);
		OpenableFormName = "CommonForm.NewEmailPreparation";
	EndIf;
	
	OpenForm(OpenableFormName, FormParameters, ThisObject);
	
EndProcedure

&AtServer
Function GetTempFileNameForPrintForm(TemplateName, Extension, UsedFilesNames)
	
	FileNamePattern = "%1%2.%3";
	
	TempFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(
		StringFunctionsClientServer.PlaceParametersIntoString(FileNamePattern, TemplateName, "", Extension));
		
	UsageNumber = ?(UsedFilesNames[TempFileName] <> Undefined,
							UsedFilesNames[TempFileName] + 1,
							1);
	
	UsedFilesNames.Insert(TempFileName, UsageNumber);
	
	// If the name has been previously used, add counter at the end of the name.
	If UsageNumber > 1 Then
		TempFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(
			StringFunctionsClientServer.PlaceParametersIntoString(
				FileNamePattern,
				TemplateName,
				" (" + UsageNumber + ")",
				Extension));
	EndIf;
	
	Return TempFileName;
	
EndFunction

&AtServer
Function DocumentsTableForPrinting()
	DocumentsTable = New ValueList;
	
	For Each PrintFormSetting IN PrintFormsSettings Do
		If Items[PrintFormSetting.AttributeName].Output = UseOutput.Enable AND PrintFormSetting.Print Then
			PrintForm = ThisObject[PrintFormSetting.AttributeName];
			SpreadsheetDocument = New SpreadsheetDocument;
			SpreadsheetDocument.Put(PrintForm);
			FillPropertyValues(SpreadsheetDocument, PrintForm, "FitToPage,Output,PageHeight,DuplexPrinting,Protection,PrinterName,TemplateLanguageCode,Copies,PrintScale,PageOrientation,TopMargin,LeftMargin,BottomMargin,RightMargin,Collate,HeaderSize,FooterSize,PageSize,PrintAccuracy,BlackAndWhite,PageWidth,PerPage");
			SpreadsheetDocument.Copies = PrintFormSetting.Quantity;
			DocumentsTable.Add(SpreadsheetDocument, PrintFormSetting.Presentation);
		EndIf;
	EndDo;
	
	Return DocumentsTable;
EndFunction

#Region Autosum

&AtClient
Procedure CalculateCellsAmount()
	WaitInterval = ?(GetClientConnectionSpeed() = ClientConnectionSpeed.Low, 1, 0.2);
	AttachIdleHandler("Attachable_CalculateCellsAmount", WaitInterval, True);
EndProcedure

&AtClient
Procedure Attachable_CalculateCellsAmount()
	PrintFormSetting = CurrentPrintFormSetting();
	If PrintFormSetting = Undefined Then
		Return;
	EndIf;
	
	SpreadsheetDocument = ThisObject[PrintFormSetting.AttributeName];
	MarkedCellsAmount = StandardSubsystemsClientServer.CellsAmount(SpreadsheetDocument, Undefined);
	Items.CalculateAmount.Enabled = (MarkedCellsAmount = "<");
EndProcedure

&AtServerNoContext
Function CalculateSummServer(Val SpreadsheetDocument, Val SelectedAreas)
	Return StandardSubsystemsClientServer.CellsAmount(SpreadsheetDocument, SelectedAreas);
EndFunction

#EndRegion

#EndRegion
















