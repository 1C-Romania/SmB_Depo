&AtClient
Var SelectContext;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	FillPrintFormsTemplatesTable();
	If Parameters.Property("ShowOnlyUserModified") Then
		FilterByTemplateUse = "UsedModified";
	Else
		FilterByTemplateUse = Items.FilterByTemplateUse.ChoiceList[0].Value;
	EndIf;
	
	AskTemplateOpeningMode = CommonUse.CommonSettingsStorageImport(
		"SettingOpeningTemplates", "AskTemplateOpeningMode", True);
	TemplateOpeningModeView = CommonUse.CommonSettingsStorageImport(
		"SettingOpeningTemplates", "TemplateOpeningModeView", False);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_PrintLayouts" Then
		UpdateTemplateReflection(Parameter.MetadataObjectTemplateName);
	ElsIf EventName = "Write_SpreadsheetDocument" AND Source.FormOwner = ThisObject Then
		Template = Parameter.SpreadsheetDocument;
		AddressTemplateInTemporaryStorage = PutToTempStorage(Template);
		WriteTemplate(Parameter.MetadataObjectTemplateName, AddressTemplateInTemporaryStorage);
		UpdateTemplateReflection(Parameter.MetadataObjectTemplateName)
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("InformationRegister.UserPrintTemplates.Form.TemplateOpenModeChoice") Then
		
		If TypeOf(ValueSelected) <> Type("Structure") Then
			Return;
		EndIf;
		
		TemplateOpeningModeView = ValueSelected.OpeningModeView;
		AskTemplateOpeningMode = Not ValueSelected.DontAskAgain;
		
		If SelectContext = "OpenPrintFormTemplate" Then
			
			If ValueSelected.DontAskAgain Then
				SaveSettingsOfTemplateOpeningMode(AskTemplateOpeningMode, TemplateOpeningModeView);
			EndIf;
			
			If TemplateOpeningModeView Then
				OpenPrintFormTemplateForView();
			Else
				OpenPrintFormTemplateForEdit();
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Parameter = New Structure("Cancel", False);
	Notify("ClosingOfOwnersForm", Parameter, ThisObject);
	
	If Parameter.Cancel Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetTemplatesFilter();
EndProcedure

#EndRegion

#Region FormTableItemEventsHandlersPrintFormsTemplates

&AtClient
Procedure PrintFormsTemplatesChoice(Item, SelectedRow, Field, StandardProcessing)
	OpenPrintFormTemplate();
EndProcedure

&AtClient
Procedure PrintFormsTemplatesOnActivateRow(Item)
	SetCommandBarButtonsAvailability();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ChangeTemplate(Command)
	OpenPrintFormTemplateForEdit();
EndProcedure

&AtClient
Procedure OpenTemplate(Command)
	OpenPrintFormTemplateForView();
EndProcedure

&AtClient
Procedure UseModifiedTemplate(Command)
	SwitchSelectedTemplatesUse(True);
EndProcedure

&AtClient
Procedure UseStandardTemplate(Command)
	SwitchSelectedTemplatesUse(False);
EndProcedure

&AtClient
Procedure SetActionOnPrintFormTemplateSelect(Command)
	
	SelectContext = "SetActionOnPrintFormTemplateSelect";
	OpenForm("InformationRegister.UserPrintTemplates.Form.TemplateOpenModeChoice", , ThisObject);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Initial filling

&AtServer
Procedure FillPrintFormsTemplatesTable()
	
	CollectionsOfMetadataObjects = New Array;
	CollectionsOfMetadataObjects.Add(Metadata.Catalogs);
	CollectionsOfMetadataObjects.Add(Metadata.Documents);
	CollectionsOfMetadataObjects.Add(Metadata.DataProcessors);
	CollectionsOfMetadataObjects.Add(Metadata.BusinessProcesses);
	CollectionsOfMetadataObjects.Add(Metadata.Tasks);
	CollectionsOfMetadataObjects.Add(Metadata.DocumentJournals);
	
	For Each MetadataObjectCollection IN CollectionsOfMetadataObjects Do
		For Each CollectionMetadataObject IN MetadataObjectCollection Do
			For Each MetadataObjectTemplate IN CollectionMetadataObject.Templates Do
				TemplateType = TemplateType(MetadataObjectTemplate.Name);
				If TemplateType = Undefined Then
					Continue;
				EndIf;
				If CommonUse.MetadataObjectAvailableByFunctionalOptions(CollectionMetadataObject) Then
					AddDetailsTemplate(CollectionMetadataObject.FullName() + "." + MetadataObjectTemplate.Name, MetadataObjectTemplate.Synonym, CollectionMetadataObject.Synonym, TemplateType);
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	For Each MetadataObjectTemplate IN Metadata.CommonTemplates Do
		TemplateType = TemplateType(MetadataObjectTemplate.Name);
		If TemplateType = Undefined Then
			Continue;
		EndIf;
		AddDetailsTemplate("CommonTemplate." + MetadataObjectTemplate.Name, MetadataObjectTemplate.Synonym, NStr("en='Common template';ru='Общий шаблон'"), TemplateType);
	EndDo;
	
	PrintFormsTemplates.Sort("TemplatePresentation asc");
	
	SetModifiedTemplatesUsageFlags();
EndProcedure

&AtServer
Function AddDetailsTemplate(MetadataObjectTemplateName, TemplatePresentation, OwnerPresentation, TemplateType)
	TemplateDescription = PrintFormsTemplates.Add();
	TemplateDescription.TemplateType = TemplateType;
	TemplateDescription.MetadataObjectTemplateName = MetadataObjectTemplateName;
	TemplateDescription.OwnerPresentation = OwnerPresentation;
	TemplateDescription.TemplatePresentation = TemplatePresentation;
	TemplateDescription.Picture = PictureIndex(TemplateType);
	TemplateDescription.SearchString = MetadataObjectTemplateName + " "
								+ OwnerPresentation + " "
								+ TemplatePresentation + " "
								+ TemplateType;
	Return TemplateDescription;
EndFunction

&AtServer
Procedure SetModifiedTemplatesUsageFlags()
	
	QueryText =
	"SELECT
	|	ModifiedTemplates.TemplateName,
	|	ModifiedTemplates.Object,
	|	ModifiedTemplates.Use
	|FROM
	|	InformationRegister.UserPrintTemplates AS ModifiedTemplates";
	
	Query = New Query(QueryText);
	ModifiedTemplates = Query.Execute().Unload();
	For Each Template IN ModifiedTemplates Do
		MetadataObjectTemplateName = Template.Object + "." + Template.TemplateName;
		FoundStrings = PrintFormsTemplates.FindRows(New Structure("MetadataObjectTemplateName", MetadataObjectTemplateName));
		For Each TemplateDescription IN FoundStrings Do
			TemplateDescription.Changed = True;
			TemplateDescription.UseModified = Template.Use;
			TemplateDescription.UsagePicture = Number(TemplateDescription.Changed) + Number(TemplateDescription.UseModified);
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Function TemplateType(MetadataObjectTemplateName)
	
	TemplateTypes = New Array;
	TemplateTypes.Add("MXL");
	TemplateTypes.Add("DOC");
	TemplateTypes.Add("ODT");
	
	For Each TemplateType IN TemplateTypes Do
		Position = Find(MetadataObjectTemplateName, "PF_" + TemplateType);
		If Position > 0 Then
			Return TemplateType;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtServer
Function PictureIndex(Val TemplateType)
	
	TemplateTypes = New Array;
	TemplateTypes.Add("DOC");
	TemplateTypes.Add("ODT");
	TemplateTypes.Add("MXL");
	
	Result = TemplateTypes.Find(Upper(TemplateType));
	Return ?(Result = Undefined, -1, Result);
	
EndFunction 

// Filters

&AtClient
Procedure SetTemplatesFilter(Text = Undefined);
	If Text = Undefined Then
		Text = SearchString;
	EndIf;
	
	FilterStructure = New Structure;
	FilterStructure.Insert("SearchString", TrimAll(Text));
	If FilterByTemplateUse = "modified" Then
		FilterStructure.Insert("Changed", True);
	ElsIf FilterByTemplateUse = "NotChanged" Then
		FilterStructure.Insert("Changed", False);
	ElsIf FilterByTemplateUse = "UsedModified" Then
		FilterStructure.Insert("UseModified", True);
	ElsIf FilterByTemplateUse = "NotChanged" Then
		FilterStructure.Insert("UseModified", False);
		FilterStructure.Insert("Changed", True);
	EndIf;
	
	Items.PrintFormsTemplates.RowFilter = New FixedStructure(FilterStructure);
	SetCommandBarButtonsAvailability();
EndProcedure

&AtClient
Procedure SearchStringAutoPickup(Item, Text, ChoiceData, Wait, StandardProcessing)
	SetTemplatesFilter(Text);
EndProcedure

&AtClient
Procedure SearchStringClearing(Item, StandardProcessing)
	SetTemplatesFilter();
EndProcedure

&AtClient
Procedure SearchStringOnChange(Item)
	SetTemplatesFilter();
	If Items.SearchString.ChoiceList.FindByValue(SearchString) = Undefined Then
		Items.SearchString.ChoiceList.Add(SearchString);
	EndIf;
EndProcedure

&AtClient
Procedure FilterByUsedTemplateKindOnChange(Item)
	SetTemplatesFilter();
EndProcedure

&AtClient
Procedure FilterByTemplateUseClearing(Item, StandardProcessing)
	StandardProcessing = False;
	FilterByTemplateUse = Items.FilterByTemplateUse.ChoiceList[0].Value;
	SetTemplatesFilter();
EndProcedure

// Template opening

&AtClient
Procedure OpenPrintFormTemplate()
	
	If AskTemplateOpeningMode Then
		SelectContext = "OpenPrintFormTemplate";
		OpenForm("InformationRegister.UserPrintTemplates.Form.TemplateOpenModeChoice", , ThisObject);
		Return;
	EndIf;
	
	If TemplateOpeningModeView Then
		OpenPrintFormTemplateForView();
	Else
		OpenPrintFormTemplateForEdit();
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenPrintFormTemplateForView()
	
	CurrentData = Items.PrintFormsTemplates.CurrentData;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("MetadataObjectTemplateName", CurrentData.MetadataObjectTemplateName);
	OpenParameters.Insert("TemplateType", CurrentData.TemplateType);
	OpenParameters.Insert("OnlyOpening", True);
	
	If CurrentData.TemplateType = "MXL" Then
		OpenParameters.Insert("DocumentName", CurrentData.TemplatePresentation);
		OpenForm("CommonForm.EditSpreadsheetDocument", OpenParameters, ThisObject);
		Return;
	EndIf;
	
	OpenForm("InformationRegister.UserPrintTemplates.Form.TemplateEditing", OpenParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure OpenPrintFormTemplateForEdit()
	
	CurrentData = Items.PrintFormsTemplates.CurrentData;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("MetadataObjectTemplateName", CurrentData.MetadataObjectTemplateName);
	OpenParameters.Insert("TemplateType", CurrentData.TemplateType);
	
	If CurrentData.TemplateType = "MXL" Then
		OpenParameters.Insert("DocumentName", CurrentData.TemplatePresentation);
		OpenParameters.Insert("Edit", True);
		OpenForm("CommonForm.EditSpreadsheetDocument", OpenParameters, ThisObject);
		Return;
	EndIf;
	
	OpenForm("InformationRegister.UserPrintTemplates.Form.TemplateEditing", OpenParameters, ThisObject);
	
EndProcedure

&AtServerNoContext
Procedure SaveSettingsOfTemplateOpeningMode(AskTemplateOpeningMode, TemplateOpeningModeView)
	
	CommonUse.CommonSettingsStorageSave("SettingOpeningTemplates",
		"AskTemplateOpeningMode", AskTemplateOpeningMode);
	
	CommonUse.CommonSettingsStorageSave("SettingOpeningTemplates",
		"TemplateOpeningModeView", TemplateOpeningModeView);
	
EndProcedure

// Actions with templates

&AtClient
Procedure SwitchSelectedTemplatesUse(UseModified)
	SwitchedTemplates = New Array;
	For Each SelectedRow IN Items.PrintFormsTemplates.SelectedRows Do
		CurrentData = Items.PrintFormsTemplates.RowData(SelectedRow);
		If CurrentData.Changed Then
			CurrentData.UseModified = UseModified;
			SetUsagePicture(CurrentData);
			SwitchedTemplates.Add(CurrentData.MetadataObjectTemplateName);
		EndIf;
	EndDo;
	SetModifiedTemplatesUsing(SwitchedTemplates, UseModified);
	SetCommandBarButtonsAvailability();
EndProcedure

&AtServerNoContext
Procedure SetModifiedTemplatesUsing(Templates, UseModified)
	
	For Each MetadataObjectTemplateName IN Templates Do
		NameParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(MetadataObjectTemplateName, ".");
		TemplateName = NameParts[NameParts.UBound()];
		
		OwnerName = "";
		For PartNumber = 0 To NameParts.UBound()-1 Do
			If Not IsBlankString(OwnerName) Then
				OwnerName = OwnerName + ".";
			EndIf;
			OwnerName = OwnerName + NameParts[PartNumber];
		EndDo;
		
		Record = InformationRegisters.UserPrintTemplates.CreateRecordManager();
		Record.Object = OwnerName;
		Record.TemplateName = TemplateName;
		Record.Read();
		If Record.Selected() Then
			Record.Use = UseModified;
			Record.Write();
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure DeleteSelectedModifiedTemplates(Command)
	DeletedTemplates = New Array;
	For Each SelectedRow IN Items.PrintFormsTemplates.SelectedRows Do
		CurrentData = Items.PrintFormsTemplates.RowData(SelectedRow);
		CurrentData.UseModified = False;
		CurrentData.Changed = False;
		SetUsagePicture(CurrentData);
		DeletedTemplates.Add(CurrentData.MetadataObjectTemplateName);
	EndDo;
	DeleteModifiedTemplates(DeletedTemplates);
	SetCommandBarButtonsAvailability();
EndProcedure

&AtServerNoContext
Procedure DeleteModifiedTemplates(DeletedTemplates)
	
	For Each MetadataObjectTemplateName IN DeletedTemplates Do
		NameParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(MetadataObjectTemplateName, ".");
		TemplateName = NameParts[NameParts.UBound()];
		
		OwnerName = "";
		For PartNumber = 0 To NameParts.UBound()-1 Do
			If Not IsBlankString(OwnerName) Then
				OwnerName = OwnerName + ".";
			EndIf;
			OwnerName = OwnerName + NameParts[PartNumber];
		EndDo;
		
		RecordManager = InformationRegisters.UserPrintTemplates.CreateRecordManager();
		RecordManager.Object = OwnerName;
		RecordManager.TemplateName = TemplateName;
		RecordManager.Delete();
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure WriteTemplate(MetadataObjectTemplateName, AddressTemplateInTemporaryStorage)
	PrintManagement.WriteTemplate(MetadataObjectTemplateName, AddressTemplateInTemporaryStorage);
EndProcedure

&AtClient
Procedure UpdateTemplateReflection(MetadataObjectTemplateName);
	
	FoundTemplates = PrintFormsTemplates.FindRows(New Structure("MetadataObjectTemplateName", MetadataObjectTemplateName));
	For Each Template IN FoundTemplates Do
		Template.Changed = True;
		Template.UseModified = True;
		SetUsagePicture(Template);
	EndDo;
	
	SetCommandBarButtonsAvailability();
	
EndProcedure

// Common

&AtClient
Procedure SetUsagePicture(TemplateDescription)
	TemplateDescription.UsagePicture = Number(TemplateDescription.Changed) + Number(TemplateDescription.UseModified);
EndProcedure

&AtClient
Procedure SetCommandBarButtonsAvailability()
	
	CurrentTemplate = Items.PrintFormsTemplates.CurrentData;
	CurrentTemplateSelected = CurrentTemplate <> Undefined;
	FewTemplatesSelected = Items.PrintFormsTemplates.SelectedRows.Count() > 1;
	
	Items.PrintFormsTemplatesOpenTemplate.Enabled = CurrentTemplateSelected AND Not FewTemplatesSelected;
	Items.PrintFormsTemplatesChangeTemplate.Enabled = CurrentTemplateSelected AND Not FewTemplatesSelected;
	
	UseModifiedTemplateEnabled = False;
	UseStandardTemplateEnabled = False;
	DeleteModifiedTemplateEnabled = False;
	
	For Each SelectedRow IN Items.PrintFormsTemplates.SelectedRows Do
		CurrentTemplate = Items.PrintFormsTemplates.RowData(SelectedRow);
		UseModifiedTemplateEnabled = CurrentTemplateSelected AND CurrentTemplate.Changed AND Not CurrentTemplate.UseModified Or FewTemplatesSelected AND UseModifiedTemplateEnabled;
		UseStandardTemplateEnabled = CurrentTemplateSelected AND CurrentTemplate.Changed AND CurrentTemplate.UseModified Or FewTemplatesSelected AND UseStandardTemplateEnabled;
		DeleteModifiedTemplateEnabled = CurrentTemplateSelected AND CurrentTemplate.Changed Or FewTemplatesSelected AND DeleteModifiedTemplateEnabled;
	EndDo;
	
	Items.PrintFormsTemplatesUseModifiedTemplate.Enabled = UseModifiedTemplateEnabled;
	Items.PrintFormsTemplatesUseStandardTemplate.Enabled = UseStandardTemplateEnabled;
	Items.PrintDeleteTemplateChangedFormTemplates.Enabled = DeleteModifiedTemplateEnabled;
	
EndProcedure

#EndRegion














