
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Parameters.Property("OpenByScenario") Then
		Raise NStr("en='Data processor is not aimed for being used directly'");
	EndIf;
	
	ThisDataProcessor = ThisObject();
	If IsBlankString(Parameters.AddressOfObject) Then
		ThisObject( ThisDataProcessor.InitializeThisObject(Parameters.SettingsObject) );
	Else
		ThisObject( ThisDataProcessor.InitializeThisObject(Parameters.AddressOfObject) );
	EndIf;
	
	If Not ValueIsFilled(Object.InfobaseNode) Then
		Text = NStr("en='Data exchange setup is not found.'");
		DataExchangeServer.ShowMessageAboutError(Text, Cancel);
		Return;
	EndIf;
	
	Title = Title + " (" + Object.InfobaseNode + ")";
	BaseNameForForm = ThisDataProcessor.BaseNameForForm();
	
	ViewCurrentSettings = "";
	Items.SettingsOfFilters.Visible = AccessRight("SaveUserData", Metadata);
	
	ResetTableCountsLabel();
	RefreshTotalQuantityLabel();
EndProcedure

&AtClient
Procedure OnClose()
	StopCalculationAmount();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure AdditionalRegistrationSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field <> Items.AdditionalRegistrationSelectionString Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	CurrentData = Items.AdditionalRegistration.CurrentData;
	
	OpenableFormName = BaseNameForForm + "Form.PeriodAndFilterEditing";
	FormParameters = New Structure;
	FormParameters.Insert("Title",           CurrentData.Presentation);
	FormParameters.Insert("ActionSelect",      - Items.AdditionalRegistration.CurrentRow);
	FormParameters.Insert("PeriodSelection",        CurrentData.PeriodSelection);
	FormParameters.Insert("SettingsComposer", SettingsComposerByTableName(CurrentData.FullMetadataName, CurrentData.Presentation, CurrentData.Filter));
	FormParameters.Insert("PeriodOfData",        CurrentData.Period);
	
	FormParameters.Insert("AddressOfFormStore", UUID);
	
	OpenForm(OpenableFormName, FormParameters, Items.AdditionalRegistration);
EndProcedure

&AtClient
Procedure AdditionalRegistrationBeforeBeginAdding(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
	If Copy Then
		Return;
	EndIf;
	
	OpenForm(BaseNameForForm + "Form.CaseTypeObjectCompositionNode",
		New Structure("InfobaseNode", Object.InfobaseNode),
		Items.AdditionalRegistration);
EndProcedure

&AtClient
Procedure AdditionalRegistrationBeforeDeleting(Item, Cancel)
	Selected = Items.AdditionalRegistration.SelectedRows;
	Quantity = Selected.Count();
	If Quantity>1 Then
		PresentationText = NStr("en='Selected rows'");
	ElsIf Quantity=1 Then
		PresentationText = Items.AdditionalRegistration.CurrentData.Presentation;
	Else
		Return;
	EndIf;
	
	// Action will be executed from the confirmation.
	Cancel = True;
	
	QuestionText = NStr("en='Delete from additional data %1?'");    
	QuestionText = StrReplace(QuestionText, "%1", PresentationText);
	
	QuestionTitle = NStr("en='Confirmation'");
	
	Notification = New NotifyDescription("AdditionalRegistrationBeforeDeletingEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("SelectedRows", Selected);
	
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

&AtClient
Procedure AdditionalRegistrationSelectionProcessing(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	
	TypeOfSelected = TypeOf(ValueSelected);
	If TypeOfSelected=Type("Array") Then
		// Insert new line
		Items.AdditionalRegistration.CurrentRow = AddingRowToAdditionalListServer(ValueSelected);
		
	ElsIf TypeOfSelected= Type("Structure") Then
		If ValueSelected.ActionSelect=3 Then
			// Restoration settings
			SettingRepresentation = ValueSelected.SettingRepresentation;
			If Not IsBlankString(ViewCurrentSettings) AND SettingRepresentation<>ViewCurrentSettings Then
				QuestionText  = NStr("en='Restore settings ""%1""?'");
				QuestionText  = StrReplace(QuestionText, "%1", SettingRepresentation);
				HeaderText = NStr("en='Confirmation'");
				
				Notification = New NotifyDescription("AdditionalRegistrationSelectionProcessingEnd", ThisObject, New Structure);
				Notification.AdditionalParameters.Insert("SettingRepresentation", SettingRepresentation);
				
				ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , , HeaderText);
			Else
				ViewCurrentSettings = SettingRepresentation;
			EndIf;
		Else
			// Editing the filter condition, negative string number.
			Items.AdditionalRegistration.CurrentRow = EditingRowFilterAdditionalListServer(ValueSelected);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalRegistrationAfterDeleting(Item)
	RefreshTotalQuantityLabel();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ConfirmSelection(Command)
	NotifyChoice( ChoiceResultServer() );
EndProcedure

&AtClient
Procedure ShowCommonParametersText(Command)
	OpenForm(BaseNameForForm +  "Form.SynchronizationCommonParameters",
		New Structure("InfobaseNode", Object.InfobaseNode));
EndProcedure

&AtClient
Procedure ExportContent(Command)
	OpenForm(BaseNameForForm + "Form.ExportContent",
		New Structure("AddressOfObject", AddressOfObjectAdditionalExportings() ));
EndProcedure

&AtClient
Procedure RefreshQuantity(Command)
	
	If Not QuantityUpdated() Then
		AttachIdleHandler("Attachable_WaitForCountCalculation", 3, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingsOfFilters(Command)
	
	// Choice from the menu - list
	VariantList = ReadListOfSettingsOptionsServer();
	
	Text = NStr("en='Save the current setting...'");
	VariantList.Add(1, Text, , PictureLib.SaveReportSettings);
	
	Notification = New NotifyDescription("SelectionsSettingsVariantChoiceEnd", ThisObject);
	
	ShowChooseFromMenu(Notification, VariantList, Items.SettingsOfFilters);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SelectionsSettingsVariantChoiceEnd(Val SelectedItem, Val AdditionalParameters) Export
	If SelectedItem = Undefined Then
		Return;
	EndIf;
		
	SettingRepresentation = SelectedItem.Value;
	If TypeOf(SettingRepresentation)=Type("String") Then
		HeaderText = NStr("en='Confirmation'");
		QuestionText   = NStr("en='Restore settings ""%1""?'");
		QuestionText   = StrReplace(QuestionText, "%1", SettingRepresentation);
		
		Notification = New NotifyDescription("FiltersSettingsEnd", ThisObject, New Structure);
		Notification.AdditionalParameters.Insert("SettingRepresentation", SettingRepresentation);
		
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , , HeaderText);
		
	ElsIf SettingRepresentation=1 Then
		// Form of all settings
		OpenForm(BaseNameForForm + "Form.SettingsContentEditing",
			New Structure("CloseOnChoice, ActionSelect, Object, ViewCurrentSettings", 
				True, 3, 
				Object, ViewCurrentSettings
			), Items.AdditionalRegistration);
	EndIf;
	
EndProcedure

&AtClient
Procedure FiltersSettingsEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SetSettingsServer(AdditionalParameters.SettingRepresentation);
EndProcedure

&AtClient
Procedure AdditionalRegistrationSelectionProcessingEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SetSettingsServer(AdditionalParameters.SettingRepresentation);
EndProcedure

&AtClient
Procedure AdditionalRegistrationBeforeDeletingEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DeletionTable = Object.AdditionalRegistration;
	For Each RowID IN AdditionalParameters.SelectedRows Do
		RemovedRow = DeletionTable.FindByID(RowID);
		If RemovedRow<>Undefined Then
			DeletionTable.Delete(RemovedRow);
		EndIf;
	EndDo;
	
	RefreshTotalQuantityLabel();
EndProcedure

&AtServer
Function ChoiceResultServer()
	ObjectResult = New Structure("InfobaseNode, ExportVariant, ComposerAllDocumentsFilter, AllDocumentsFilterPeriod");
	FillPropertyValues(ObjectResult, Object);
	
	ObjectResult.Insert("AdditionalRegistration", 
		TableToStructureArray( FormAttributeToValue("Object.AdditionalRegistration")) );
	
	Return New Structure("ActionSelect, AddressOfObject", 
		Parameters.ActionSelect, PutToTempStorage(ObjectResult, UUID)
	);
EndFunction

&AtServer
Function TableToStructureArray(Val ValueTable)
	Result = New Array;
	
	ColumnNames = "";
	For Each Column IN ValueTable.Columns Do
		ColumnNames = ColumnNames + "," + Column.Name;
	EndDo;
	ColumnNames = Mid(ColumnNames, 2);
	
	For Each String IN ValueTable Do
		StringStructure = New Structure(ColumnNames);
		FillPropertyValues(StringStructure, String);
		Result.Add(StringStructure);
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Procedure Attachable_WaitCalculationAmount()
	
	If BackGroundJobFinished(BackgroundJobID) Then
		ImportCountsValues();
		Items.CalculationAmountPicture.Visible = False;
	Else
		AttachIdleHandler("Attachable_WaitForCountCalculation", 3, True);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function BackGroundJobFinished(BackgroundJobID)
	
	Return LongActions.JobCompleted(BackgroundJobID);
	
EndFunction

&AtServer
Function ThisObject(NewObject = Undefined)
	If NewObject=Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(NewObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function AddingRowToAdditionalListServer(SelectionArray)
	
	If SelectionArray.Count()=1 Then
		String = AddInExportAdditionalContent(SelectionArray[0]);
	Else
		String = Undefined;
		For Each ChoiceItem IN SelectionArray Do
			TestRow = AddInExportAdditionalContent(ChoiceItem);
			If String=Undefined Then
				String = TestRow;
			EndIf;
		EndDo;
	EndIf;
	
	Return String;
EndFunction

&AtServer 
Function EditingRowFilterAdditionalListServer(ChoiceStructure)
	
	CurrentData = Object.AdditionalRegistration.FindByID(-ChoiceStructure.ActionSelect);
	If CurrentData=Undefined Then
		Return Undefined
	EndIf;
	
	CurrentData.Period       = ChoiceStructure.PeriodOfData;
	CurrentData.Filter        = ChoiceStructure.SettingsComposer.Settings.Filter;
	CurrentData.SelectionString = FilterPresentation(CurrentData.Period, CurrentData.Filter);
	CurrentData.Quantity   = NStr("en='Not calculated'");
	
	RefreshTotalQuantityLabel();
	
	Return ChoiceStructure.ActionSelect;
EndFunction

&AtServer
Function AddInExportAdditionalContent(Item)
	
	ExistingRows = Object.AdditionalRegistration.FindRows( 
		New Structure("FullMetadataName", Item.FullMetadataName));
	If ExistingRows.Count()>0 Then
		String = ExistingRows[0];
	Else
		String = Object.AdditionalRegistration.Add();
		FillPropertyValues(String, Item,,"Presentation");
		
		String.Presentation = Item.ListPresentation;
		String.SelectionString  = FilterPresentation(String.Period, String.Filter);
		Object.AdditionalRegistration.Sort("Presentation");
		
		String.Quantity = NStr("en='Not calculated'");
		RefreshTotalQuantityLabel();
	EndIf;
	
	Return String.GetID();
EndFunction

&AtServer
Function FilterPresentation(Period, Filter)
	Return ThisObject().FilterPresentation(Period, Filter);
EndFunction

&AtServer
Function SettingsComposerByTableName(TableName, Presentation, Filter)
	Return ThisObject().SettingsComposerByTableName(TableName, Presentation, Filter, UUID);
EndFunction

&AtServer
Procedure StopCalculationAmount()
	
	LongActions.CancelJobExecution(BackgroundJobID);
	If Not IsBlankString(BackgroundJobResultAddress) Then
		DeleteFromTempStorage(BackgroundJobResultAddress);
	EndIf;
	
	BackgroundJobResultAddress = "";
	BackgroundJobID   = Undefined;
	
EndProcedure

&AtServer
Function QuantityUpdated()
	
	StopCalculationAmount();
	
	JobParameters = New Structure;
	JobParameters.Insert("DataProcessorStructure", ThisObject().ThisObjectInStructureForBackground());
	
	BackgroundJobResult = LongActions.ExecuteInBackground(UUID,
		"DataExchangeServer.InteractiveExportChange_GenerateValueTree",
		JobParameters, NStr("en='Objects quantity calculation for sending at synchronization'"));
		
	BackgroundJobID = BackgroundJobResult.JobID;
	BackgroundJobResultAddress = BackgroundJobResult.StorageAddress;
	
	If BackgroundJobResult.JobCompleted Then
		ImportCountsValues();
		Return True;
	Else
		Items.CalculationAmountPicture.Visible = True;
		Return False;
	EndIf;
	
EndFunction

&AtServer
Procedure ImportCountsValues()
	
	CountsTree = Undefined;
	If Not IsBlankString(BackgroundJobResultAddress) Then
		CountsTree = GetFromTempStorage(BackgroundJobResultAddress);
		DeleteFromTempStorage(BackgroundJobResultAddress);
	EndIf;
	If TypeOf(CountsTree) <> Type("ValueTree") Then
		CountsTree = New ValueTree;
	EndIf;
	
	If CountsTree.Rows.Count() = 0 Then
		RefreshTotalQuantityLabel(Undefined);
		Return;
	EndIf;
	
	ThisDataProcessor = ThisObject();
	
	CountsRows = CountsTree.Rows;
	For Each String IN Object.AdditionalRegistration Do
		
		CountTotal = 0;
		QuantityExport = 0;
		RowContent = ThisDataProcessor.ExpandedFoldersContentMetadata(String.FullMetadataName);
		For Each TableName IN RowContent Do
			DataRow = CountsRows.Find(TableName, "FullMetadataName", False);
			If DataRow <> Undefined Then
				QuantityExport = QuantityExport + DataRow.CountForExport;
				CountTotal     = CountTotal     + DataRow.CountTotal;
			EndIf;
		EndDo;
		
		String.Quantity = Format(QuantityExport, "NZ=") + " / " + Format(CountTotal, "NZ=");
	EndDo;
	
	// Common totals
	DataRow = CountsRows.Find(Undefined, "FullMetadataName", False);
	RefreshTotalQuantityLabel(?(DataRow = Undefined, Undefined, DataRow.CountForExport));
	
EndProcedure

&AtServer
Procedure RefreshTotalQuantityLabel(Quantity = Undefined) 
	
	StopCalculationAmount();
	
	If Quantity = Undefined Then
		CountText = NStr("en='<not calculated>'");
	Else
		CountText = NStr("en = 'Objects: %1'");
		CountText = StrReplace(CountText, "%1", Format(Quantity, "NZ="));
	EndIf;
	
	Items.RefreshQuantity.Title  = CountText;
EndProcedure

&AtServer
Procedure ResetTableCountsLabel()
	CountsText = NStr("en='Not calculated'");
	For Each String IN Object.AdditionalRegistration Do
		String.Quantity = CountsText;
	EndDo;
	Items.CalculationAmountPicture.Visible = False;
EndProcedure

&AtServer
Function ReadListOfSettingsOptionsServer()
	VariantsFilter = New Array;
	VariantsFilter.Add(Object.ExportVariant);
	
	Return ThisObject().ReadSettingsListPresentations(Object.InfobaseNode, VariantsFilter);
EndFunction

&AtServer
Procedure SetSettingsServer(SettingRepresentation)
	
	ConstantData = New Structure("InfobaseNode, ExportVariant, ComposerAllDocumentsFilter, AllDocumentsFilterPeriod");
	FillPropertyValues(ConstantData, Object);
	
	ThisDataProcessor = ThisObject();
	ThisDataProcessor.RestoreCurrentFromSettings(SettingRepresentation);
	ThisObject(ThisDataProcessor);
	
	FillPropertyValues(Object, ConstantData);
	ExportAdditionPresentationSettings = SettingRepresentation;
	
	ResetTableCountsLabel();
	RefreshTotalQuantityLabel();
EndProcedure

&AtServer
Function AddressOfObjectAdditionalExportings()
	Return ThisObject().SaveThisObject(UUID);
EndFunction

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
