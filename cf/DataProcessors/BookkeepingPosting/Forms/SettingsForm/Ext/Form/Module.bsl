///////////////////////////////////////////////////////////
/// FORM EVENTS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DocumentsFormAtServer.SetVisibleCompanyItem(ThisForm);
	ThisObject.Company	= CommonAtServerCached.DefaultCompany();
	
	ParametersStructure = GetFromTempStorage(Parameters.TempStorageAddress);
	For Each KeyAndValue In ParametersStructure Do
		ThisForm[KeyAndValue.Key] = KeyAndValue.Value;
	EndDo;	
	
	DocumentListBox = BookkeepingCommon.GetAvailableListOfDocumentsToBookkeepingPosting();
	DocumentListBox.SortByPresentation();
	
	If DocumentTypes.Types().Count() > 0 Then
		For Each Type In DocumentTypes.Types() Do
			EmptyRef = New(Type);	
			FoundRow = DocumentListBox.FindByValue(EmptyRef);
			If FoundRow <> Undefined Then
				FoundRow.Check = True;
			EndIf;
		EndDo;
	Else
		For Each ValueListItem In DocumentListBox Do
			ValueListItem.Check = True;
		EndDo;
	EndIf;
	
	Items.ChooseFromList.TypeRestriction = DocumentTypes;
	Items.ChoosenDocumentsFromListValue.TypeRestriction = Items.ChooseFromList.TypeRestriction;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If DisplayedDocumentsStatus = PredefinedValue("Enum.DocumentBookkeepingStatus.BookkeepingPosted") Then
		CheckedAttributes.Add("DateFrom");
		CheckedAttributes.Add("DateTo");
	EndIf;	
	
	If SelectTopX Then
		CheckedAttributes.Add("TopSelectionNumber");
	EndIf;	
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	UpdateDialog();
EndProcedure

///////////////////////////////////////////////////////////
/// ITEM EVENTS

&AtClient
Procedure ChooseFromListOnChange(Item)
	UpdateDialog();
EndProcedure

&AtClient
Procedure DocumentListBoxCheckOnChange(Item)
	Items.ChooseFromList.TypeRestriction = GetDocumentTypes();
	Items.ChoosenDocumentsFromListValue.TypeRestriction = Items.ChooseFromList.TypeRestriction;
EndProcedure

&AtClient
Procedure ApplySettings(Command)
	
	DocumentTypes = GetDocumentTypes();
	
	For Each KeyAndValue In ParametersStructure Do
		ParametersStructure[KeyAndValue.Key] = ThisForm[KeyAndValue.Key];
	EndDo;	
	
	PutToTempStorage(ParametersStructure,Parameters.TempStorageAddress);
	
	NotifyChoice(True);
	
EndProcedure

&AtClient
Procedure DisplayedDocumentsStatusOnChange(Item)
	
	If DisplayedDocumentsStatus = PredefinedValue("Enum.DocumentBookkeepingStatus.BookkeepingPostingIsNotAllowed") Then
		
		ManualBookkeepingOperation = 0;
		
	EndIf;	
	
	UpdateDialog();
	
EndProcedure

&AtClient
Procedure SelectTopXOnChange(Item)
	UpdateDialog();
EndProcedure

&AtClient
Procedure PeriodSetting(Command)
	
	Dialogue = New StandardPeriodEditDialog;
	Dialogue.Period = New StandardPeriod(DateFrom, DateTo);
	
	Dialogue.Show(New NotifyDescription("PeriodSettingEnd", ThisForm));
	
EndProcedure
	
&AtClient
Procedure PeriodSettingEnd(Value, PeriodParameters) Export 
	
	If Not Value = Undefined Then
		
		DateFrom= Value.StartDate;
		DateTo	= Value.EndDate;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure LoadFromSpreadsheet(Command)
	
	// to do
	//ColumnsStructure = New Structure("Document",Nstr("en='Document';pl='Dokument';ru='Документ'"));	
	//ColumnsTypesStructure = New Structure("Document",GetDocumentTypes());	
	//DocumentsTabularPartsProcessing.OpenLoadingFromSpreadsheet(Undefined,"ChoosenDocumentsFromList",ColumnsStructure,,ThisForm,ColumnsTypesStructure);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If SelectedValue.TypeOfChoice = "TABULARPARTLOADING" Then
		ChoosenDocumentsFromList.LoadValues(SelectedValue.TabularPartValueTable.UnloadColumn("Document"));
	EndIf;

EndProcedure

///////////////////////////////////////////////////////////
///Other

&AtClient
Function GetDocumentTypes()
	
	DocumentArray = New Array;
	For Each DocumentListBoxItem In DocumentListBox Do 
		If DocumentListBoxItem.Check Then
			DocumentArray.Add(TypeOf(DocumentListBoxItem.Value));
		EndIf;	
	EndDo;	
		
	Return New TypeDescription(DocumentArray);
	
EndFunction	

&AtClient
Procedure UpdateDialog()
	
	If ChooseFromList = 0 Then
		Items.GroupTabs.CurrentPage = Items.GroupFilter;
	Else
		Items.GroupTabs.CurrentPage = Items.GroupChooseFromList;
	EndIf;	
	
	Items.DateFrom.AutoMarkIncomplete = (DisplayedDocumentsStatus = PredefinedValue("Enum.DocumentBookkeepingStatus.BookkeepingPosted"));
	Items.DateTo.AutoMarkIncomplete   = (DisplayedDocumentsStatus = PredefinedValue("Enum.DocumentBookkeepingStatus.BookkeepingPosted"));
	
	Items.DateFrom.MarkIncomplete = Items.DateFrom.AutoMarkIncomplete AND NOT ValueIsFilled(DateFrom);
	Items.DateTo.MarkIncomplete   = Items.DateTo.AutoMarkIncomplete   AND NOT ValueIsFilled(DateTo);
	
	Items.PartialJournal.Enabled = (DisplayedDocumentsStatus = PredefinedValue("Enum.DocumentBookkeepingStatus.BookkeepingPosted"));
	
	Items.TopSelectionNumber.Enabled = SelectTopX;
	
	Items.ManualBookkeepingOperation.Enabled = (DisplayedDocumentsStatus <> PredefinedValue("Enum.DocumentBookkeepingStatus.BookkeepingPostingIsNotAllowed"));
	
EndProcedure









