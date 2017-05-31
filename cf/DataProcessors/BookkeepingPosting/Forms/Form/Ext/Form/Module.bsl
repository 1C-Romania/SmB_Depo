&AtClient
Var JobStructure;

&AtClient
Var TimeoutInc;

///////////////////////////////////////////////////////////
/// FORM EVENTS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Object.DateFrom = SettingsSaving.GetUserValue("DataProcessor.BookkeepingPosting", "DateFrom");
	Object.DateTo = SettingsSaving.GetUserValue("DataProcessor.BookkeepingPosting", "DateTo");
	Object.PartialJournal = SettingsSaving.GetUserValue("DataProcessor.BookkeepingPosting", "PartialJournal");
	Object.SortingMethod = SettingsSaving.GetUserValue("DataProcessor.BookkeepingPosting", "SortingMethod");
	Object.DynamicFilter = SettingsSaving.GetUserValue("DataProcessor.BookkeepingPosting", "DynamicFilter");
	Object.SelectTopX = SettingsSaving.GetUserValue("DataProcessor.BookkeepingPosting", "SelectTopX");
	Object.DocumentTypes = SettingsSaving.GetUserValue("DataProcessor.BookkeepingPosting", "DocumentTypes");
	Object.TopSelectionNumber = SettingsSaving.GetUserValue("DataProcessor.BookkeepingPosting", "TopSelectionNumber");
	Object.ChooseFromList = SettingsSaving.GetUserValue("DataProcessor.BookkeepingPosting", "ChooseFromList");
	ChoosenDocumentsFromListArray = SettingsSaving.GetUserValue("DataProcessor.BookkeepingPosting", "ChoosenDocumentsFromListArray");
	If ChoosenDocumentsFromListArray <> Undefined Then
		For Each ArrayItem In ChoosenDocumentsFromListArray Do
			NewRow = Object.ChoosenDocumentsFromList.Add();
			NewRow.Document = ArrayItem;
		EndDo;	
	EndIf;
	
	If Object.TopSelectionNumber = 0 Then
		Object.TopSelectionNumber = 100;
	EndIf;
	
	Object.Company = CommonAtServer.GetUserSettingsValue(ChartsOfCharacteristicTypes.UserSettings.Company);
	Object.DisplayedDocumentsStatus = Enums.DocumentBookkeepingStatus.NotBookkeepingPosted;
	Object.ManualBookkeepingOperation = 0;
	
	ObjectAttributesArray = GetCurrentObjectAttributesArray();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	UpdateDialog();
	SetInProgress(False);
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	BeforeCloseAtServer(Cancel, StandardProcessing);
	
EndProcedure

&AtServer
Procedure BeforeCloseAtServer(Cancel, StandardProcessing)
	
	SettingsSaving.SaveUserValue("DataProcessor.BookkeepingPosting", "DateFrom", Object.DateFrom);
	SettingsSaving.SaveUserValue("DataProcessor.BookkeepingPosting", "DateTo", Object.DateTo);
	SettingsSaving.SaveUserValue("DataProcessor.BookkeepingPosting", "PartialJournal", Object.PartialJournal);
	SettingsSaving.SaveUserValue("DataProcessor.BookkeepingPosting", "SortingMethod", Object.SortingMethod);
	SettingsSaving.SaveUserValue("DataProcessor.BookkeepingPosting", "DynamicFilter", Object.DynamicFilter);
	SettingsSaving.SaveUserValue("DataProcessor.BookkeepingPosting", "SelectTopX", Object.SelectTopX);
	SettingsSaving.SaveUserValue("DataProcessor.BookkeepingPosting", "TopSelectionNumber", Object.TopSelectionNumber);
	SettingsSaving.SaveUserValue("DataProcessor.BookkeepingPosting", "DocumentTypes", Object.DocumentTypes);
	SettingsSaving.SaveUserValue("DataProcessor.BookkeepingPosting", "ChooseFromList", Object.ChooseFromList);
	SettingsSaving.SaveUserValue("DataProcessor.BookkeepingPosting", "ChoosenDocumentsFromListArray", Object.ChoosenDocumentsFromList.Unload().UnloadColumn("Document"));
	
EndProcedure	

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.ChooseFromList = 0 Then
		If Object.DisplayedDocumentsStatus = PredefinedValue("Enum.DocumentBookkeepingStatus.BookkeepingPosted") Then
			CheckedAttributes.Add("DateFrom");
			CheckedAttributes.Add("DateTo");
		EndIf;	
		
		If Object.SelectTopX Then
			CheckedAttributes.Add("TopSelectionNumber");
		EndIf;
	Else
		CheckedAttributes.Add("ChoosenDocumentsFromList");
	EndIf;
	
EndProcedure

&AtServer
Function LoadTabularPartFromQueryResultAtServer(Parameter)
	
	Object.DocumentList.Clear();
	
	JobParameters = New Array;
	JobParameters.Add(Object.DocumentList.Unload());
	JobParameters.Add(GetFromTempStorage(Parameter.ResultAddress).Unload());
	Return LongActionsServer.ExecuteInBackground(UUID, "DataProcessors.BookkeepingPosting.LoadTabularPartFromQueryResult", JobParameters);	
	
EndFunction	

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "BackgroundJobEnded" Then
		
		SetInProgress(False);
		
		If Parameter.Name = "CommonAtServer.ExecuteSimpleQuery"  Then
			
			JobStructure = LoadTabularPartFromQueryResultAtServer(Parameter);
			
			JobAfterStart();
			
		ElsIf Parameter.Name = "DataProcessors.BookkeepingPosting.ProcessTabularPartRows" Then
			
			Object.DocumentList.Clear();
			FillDocumentListFinalizeAtServer(Parameter.ResultAddress);			
			
		ElsIf Parameter.Name = "DataProcessors.BookkeepingPosting.LoadTabularPartFromQueryResult" Then
			
			FillDocumentListFinalizeAtServer(Parameter.ResultAddress);
			
		EndIf;	
		
	EndIf;	
	
EndProcedure

///////////////////////////////////////////////////////////
/// COMMANDS

&AtClient
Procedure LabelSettingsClick(Item, StandardProcessing)
	StandardProcessing = False;
	OpenSettingsForm();
EndProcedure

&AtClient
Procedure NotificationProcessingDocumentListSelection(Answer, Parameters) Export
	If Answer = True Then
		
		RowSelected = Object.DocumentList.FindByID(Parameters.SelectedRow[0]);
		
		ParametersStructure = GetFromTempStorage(Parameters.TempStorageAddress);	
		
		NewStatus		= ParametersStructure.Status;
		StatusComment	= ParametersStructure.Comment;
		
		If NewStatus = PredefinedValue("Enum.DocumentBookkeepingStatus.BookkeepingPostingIsNotAllowed") 
			And Not RowSelected.BookkeepingOperation.IsEmpty() Then
			RowSelected.Remarks = Nstr("en='Document could not be marked as such that should not be bookkeeping posted, because it already has bookkeeping operation!';pl='Nie można oznaczyć dokument jak taki, któy się nie księguje bo dokument już posiada DK!';ru='Проведенный документ нельзя выбрать в качестве документа, который не проводится!'");
			Return;
		EndIf;
		
		SetDocumentsStatusAtServer(RowSelected.GetID(), NewStatus, StatusComment);
		
	EndIf;
EndProcedure

&AtClient
Procedure DocumentListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	RowSelected = Object.DocumentList.FindByID(SelectedRow[0]);
	
	If Field = Items.DocumentListDocument AND ValueIsFilled(RowSelected.Document) Then
		
		RowSelected.Document.GetForm(, Item, Item).Open();
		
	ElsIf Field = Items.DocumentListStatus Then
		
		TempStorageAddress = PutToTempStorage(Undefined,UUID);	
		
		NotifyParams= New Structure("TempStorageAddress, CurrentStatus, SelectedRow", TempStorageAddress, RowSelected.Status, SelectedRow);
		Notify		= New NotifyDescription("NotificationProcessingDocumentListSelection", ThisForm, NotifyParams);
		OpenForm("DataProcessor.BookkeepingPosting.Form.ChangeStatusForm", NotifyParams, ThisForm, , , , Notify);
		
	ElsIf Field = Items.DocumentListBookkeepingOperation Then
		
		If ValueIsFilled(RowSelected.BookkeepingOperation) Then
			
			BookkeepingOperationForm = RowSelected.BookkeepingOperation.GetForm(, Item, Item);
			BookkeepingOperationForm.InitialDocumentBase = RowSelected.Document;
			BookkeepingOperationForm.Open();
			
		Else
			
			DialogsAtClient.ShowBookkeepingOperation(RowSelected.Document);
				
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetDocumentsStatusAtServer(Val DocumentRowId, Val NewStatus, Val StatusComment)
	
	DataProcessors.BookkeepingPosting.SetDocumentsStatus(Object.DocumentList.FindByID(DocumentRowId), NewStatus, StatusComment);
	
EndProcedure	


&AtClient
Procedure DocumentListBookkeepingOperationTemplateStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.DocumentList.CurrentData;
	If ValueIsFilled(CurrentRow.Document) Then
		
		StandardProcessing=False;
		ParametersForm = New Structure();
		ParametersForm.Insert("ChoiceMode",True);	
		If ValueIsFilled(CurrentRow.Document) Then
			ParametersForm.Insert("Filter_DocumentBaseType",TypeOf(CurrentRow.Document));		
		EndIf;                                                       	
		
		OpenForm("Catalog.BookkeepingOperationsTemplates.ChoiceForm",ParametersForm,Item);	
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateDraftBookkeepingOperationsForCheckedResponse(Answer, Parameters) Export 
	
	JobStructure = ProcessTabularPartRowsInJob(New Structure("Name, IsDraft","Posting",True));
	
	JobAfterStart();
	
EndProcedure

&AtClient
Procedure CreateDraftBookkeepingOperationsForChecked(Command)
	
	Notify	= New NotifyDescription("CreateDraftBookkeepingOperationsForCheckedResponse", ThisForm);
	
	AskUserToProceed(Notify);
	
EndProcedure

&AtClient
Procedure UndoBookkeepingPostingForCheckedResponse(Answer, Parameters) Export 
	
	JobStructure = ProcessTabularPartRowsInJob(New Structure("Name","UndoPosting"));
	
	JobAfterStart();
	
EndProcedure

&AtClient
Procedure UndoBookkeepingPostingForChecked(Command)
	
	Notify	= New NotifyDescription("UndoBookkeepingPostingForCheckedResponse", ThisForm);
	
	AskUserToProceed(Notify);
	
EndProcedure

&AtClient
Procedure NotificationProcessingChangeStatusForChecked(Answer, Parameters) Export 
	If Answer = True Then
		
		ParametersStructure = GetFromTempStorage(Parameters.TempStorageAddress);
		
		JobStructure = ProcessTabularPartRowsInJob(New Structure("Name, NewStatus, NewComment","SetStatus",ParametersStructure.Status,ParametersStructure.Comment));
		
		JobAfterStart();
		
	EndIf;	
EndProcedure

&AtClient
Procedure ChangeStatusForCheckedResponse(Answer, Parameters) Export 
	
	TempStorageAddress = PutToTempStorage(Undefined,UUID);
	
	NotifyParams= New Structure("TempStorageAddress",TempStorageAddress);
	Notify		= New NotifyDescription("NotificationProcessingChangeStatusForChecked", ThisForm, NotifyParams);
	OpenForm("DataProcessor.BookkeepingPosting.Form.ChangeStatusForm", NotifyParams, ThisForm, , , , Notify);
	
EndProcedure

&AtClient
Procedure ChangeStatusForChecked(Command)
	
	Notify	= New NotifyDescription("ChangeStatusForCheckedResponse", ThisForm);
	
	AskUserToProceed(Notify);
	
EndProcedure

&AtClient
Procedure CreateBookkeepingOperationsForCheckedResponse(Answer, Parameters) Export 
	
	JobStructure = ProcessTabularPartRowsInJob(New Structure("Name, IsDraft","Posting",False));
	
	JobAfterStart();
	
EndProcedure

&AtClient
Procedure CreateBookkeepingOperationsForChecked(Command)
	
	Notify	= New NotifyDescription("CreateBookkeepingOperationsForCheckedResponse", ThisForm);
	
	AskUserToProceed(Notify);
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	SetCheckForAll(True);
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	SetCheckForAll(False);
EndProcedure

&AtClient
Procedure Refresh(Command)
	FillDocumentList();
EndProcedure

&AtClient
Procedure Settings(Command)
	OpenSettingsForm();
EndProcedure

&AtClient
Procedure CancelJob(Command)
	
	LongActionsServer.CancelJobExecution(JobStructure.JobID);
	
	SetInProgress(False);
	
EndProcedure

///////////////////////////////////////////////////////////
/// Other

&AtServerNoContext
Function GetCurrentObjectAttributesArray()
	
	ObjectAttributesArray = New Array;
	For Each Attribute In Metadata.DataProcessors.BookkeepingPosting.Attributes Do
		ObjectAttributesArray.Add(Attribute.Name);
	EndDo;	
	ObjectAttributesArray.Add("ChoosenDocumentsFromList");
	
	Return New FixedArray(ObjectAttributesArray);
	
EndFunction	

&AtServer
Function PutParametersStructure()
	
	ParametersStructure = New Structure;
	For Each ObjectAttribute In ObjectAttributesArray Do
		ParametersStructure.Insert(ObjectAttribute,Object[ObjectAttribute]);
	EndDo;	
	// Exception for  ChoosenDocumentsFromList
	VL = New ValueList;
	VL.LoadValues(Object.ChoosenDocumentsFromList.Unload().UnloadColumn("Document"));
	ParametersStructure.Insert("ChoosenDocumentsFromList",VL);
	
	Return PutToTempStorage(ParametersStructure,ThisForm.UUID);
	
EndFunction	

&AtClient
Procedure NotificationProcessingOpenSettingsForm(Answer, Parameters) Export 
	If Answer = True Then
		
		ParametersStructure = GetFromTempStorage(Parameters.TempStorageAddress);
		For Each KeyAndValue In ParametersStructure Do
			If TypeOf(KeyAndValue.Value) <> Type("ValueList") Then
				Object[KeyAndValue.Key] = KeyAndValue.Value;
			Else
				// exception for ChoosenDocumentsFromList
				Object[KeyAndValue.Key].Clear();
				For Each ValueListItem In KeyAndValue.Value Do
					NewRow = Object[KeyAndValue.Key].Add();
					NewRow.Document = ValueListItem.Value;
				EndDo;	
			EndIf;	
		EndDo;	
		
		UpdateDialog();
		
		FillDocumentList();
		
	EndIf;	
EndProcedure

&AtClient
Procedure OpenSettingsForm()
	
	TempStorageAddress = PutParametersStructure();
	
	NotifyParams= New Structure("TempStorageAddress", TempStorageAddress);
	Notify		= New NotifyDescription("NotificationProcessingOpenSettingsForm", ThisForm, NotifyParams);
	OpenForm("DataProcessor.BookkeepingPosting.Form.SettingsForm", NotifyParams, ThisForm, , , , Notify);
	
EndProcedure	

&AtClient
Procedure AskUserToProceedResponse(Answer, Parameters) Export 

	If Answer = DialogReturnCode.Yes Then
		
		ExecuteNotifyProcessing(Parameters.NotifyDescriptionOnProceed);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AskUserToProceed(NotifyDescriptionOnProceed)
	
	CheckedNumber = GetMarkedDocumentsCount();
	
	If CheckedNumber = 0 Then
		Return;
	EndIf;
	
	Question = NStr("en='Are you sure you want to proceed %P1 rows?';pl='Czy jesteś pewny że chcesz obrobić %P1 wierszy?';ru='Хотите обработать %P1 строк?'");
	Question = StrReplace(Question, "%P1", CheckedNumber);
	
	Notify	= New NotifyDescription("AskUserToProceedResponse", ThisForm, New Structure("NotifyDescriptionOnProceed", NotifyDescriptionOnProceed));
	ShowQueryBox(Notify, Question, QuestionDialogMode.YesNo);
	
EndProcedure

&AtServer
Function GetMarkedDocumentsCount()
	
	Return Object.DocumentList.FindRows(New Structure("Check",True)).Count();
	
EndFunction	

&AtClient
Procedure UpdateDialog()
	
	LabelSettings = NStr("en='Company:';pl='Firma:';ru='Организация:'") + " " + Object.Company;
	
	If Object.DisplayedDocumentsStatus = PredefinedValue("Enum.DocumentBookkeepingStatus.BookkeepingPosted") Then
		LabelSettings = LabelSettings + ", " + NStr("en='Posted';pl='Zaksięgowane';ru='Проведенные'");
	ElsIf Object.DisplayedDocumentsStatus = PredefinedValue("Enum.DocumentBookkeepingStatus.BookkeepingPostingIsNotAllowed") Then
		LabelSettings = LabelSettings + ", " + NStr("en='Posting is not allowed';pl='Nie księgują się';ru='Не проводятся'");
	Else
		LabelSettings = LabelSettings + ", " + NStr("en='Not posted';pl='Nie zaksięgowane';ru='Непроведенные'");
	EndIf;
	
	If Object.DateFrom = '00010101' AND Object.DateTo = '00010101' Then
		LabelSettings = LabelSettings + ", " + NStr("en='Without date filter';pl='Bez ograniczenia dat';ru='Без ограничений по датам'");
	Else
		LabelSettings = LabelSettings + ", " + Format(Object.DateFrom, "DLF = D; DE = ...") + " - " + Format(Object.DateTo, "DLF = D; DE = ...");
	EndIf;
	
	If Object.DocumentTypes.Types().Count() > 0 Then
		LabelSettings = LabelSettings + ", " + NStr("en='Selected documents types';pl='Wybrane typy dokumentów';ru='Выбранные типы документов'");
	Else
		LabelSettings = LabelSettings + ", " + NStr("en='All documents types';pl='Wszystkie typy dokumentów';ru='Все типы документов'");
	EndIf;
	
	If Object.SelectTopX Then
		LabelSettings = LabelSettings + ", " + NStr("en='Top %P1 documents';pl='Pierwsze %P1 dokumentów';ru='Первые %P1 документов'");
		LabelSettings = StrReplace(LabelSettings, "%P1", Object.TopSelectionNumber);
	EndIf;
	
EndProcedure	

&AtClient
Procedure IdleHandlerForJob()
	
	If LongActionsServer.JobCompleted(JobStructure.JobID) Then
		Progress = 100;
		DetachIdleHandler("IdleHandlerForJob");
		Notify("BackgroundJobEnded", New Structure("Name, ResultAddress", JobStructure.ProcedureName, JobStructure.StorageAddress));
		Return;
	EndIf;
	
	ReadProgress = LongActionsServer.ReadProgress(JobStructure.JobID);
	For Each Message  In  ReadProgress.MessagesArray Do
		Message(Message.Text);
	EndDo;	
	
	BaseTimeout = 0.5;
	
	PrevProgress = Progress;
	
	Progress = ReadProgress.ProgressStructure.Progress;
	
	ProgressDiff = abs(Progress - PrevProgress);
	
	If ProgressDiff <1 Then
		TimeoutInc = 2*TimeoutInc+BaseTimeout;
	Else
		TimeoutInc = TimeoutInc/ProgressDiff;
		If TimeoutInc<=BaseTimeout/2 Then
			TimeoutInc = 0;
		EndIf;	
	EndIf;	
	
	If Progress = 100 Then
		BaseTimeout = 0.1;
		TimeoutInc = 0;
	EndIf;	
	
	AttachIdleHandler("IdleHandlerForJob", BaseTimeout + TimeoutInc, True);
	
EndProcedure	

&AtClient
Procedure SetInProgress(Val State)
	
	Items.InProgress.Visible = State;
	ThisForm.ReadOnly = State;
	
EndProcedure	

&AtClient
Procedure FillDocumentList()
	
	If NOT CheckFilling() Then
		Return;
	EndIf;	
	
	JobStructure = RunFillQueryAtServer();
	JobAfterStart();
	
EndProcedure	

&AtClient
Procedure JobAfterStart()
	
	AttachIdleHandler("IdleHandlerForJob", 0.1, True);
	TimeoutInc = 0;
	
	SetInProgress(True);
	
EndProcedure	

&AtServer
Procedure FillDocumentListFinalizeAtServer(Val Address)
	
	Object.DocumentList.Load(GetFromTempStorage(Address));
	
EndProcedure	

&AtServer
Function RunFillQueryAtServer()
	
	If Object.DisplayedDocumentsStatus.IsEmpty() Then
		Object.DisplayedDocumentsStatus = Enums.DocumentBookkeepingStatus.NotBookkeepingPosted;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	BookkeepingPostedDocuments.Document,
	|	BookkeepingPostedDocuments.Document.Author,
	|	BookkeepingPostedDocuments.Document.Comment,
	|	BookkeepingPostedDocuments.Status,
	|	BookkeepingOperationTable.BookkeepingOperationsTemplate AS BookkeepingOperationTemplate,
	|	BookkeepingOperationTable.Ref AS BookkeepingOperationRef,
	|	BookkeepingOperationTable.DeletionMark AS BookkeepingOperationDeletionMark,
	|	BookkeepingOperationTable.Posted AS BookkeepingOperationPosted,
	|	BookkeepingOperationTable.Number AS BookkeepingOperationNumber,
	|	BookkeepingOperationTable.Author AS BookkeepingOperationAuthor,
	|	BookkeepingOperationTable.Manual AS BookkeepingOperationManual,
	|	BookkeepingOperationTable.Comment AS BookkeepingOperationComment
	|FROM
	|	InformationRegister.BookkeepingPostedDocuments AS BookkeepingPostedDocuments
	|		LEFT JOIN Document.BookkeepingOperation AS BookkeepingOperationTable
	|		ON BookkeepingPostedDocuments.Document = BookkeepingOperationTable.DocumentBase ";
	
	
	If Object.ChooseFromList = 0 Then
		FilterByDocumentType = ?(Object.DocumentTypes.Types().Count() > 0, True, False);
		
		If Object.DisplayedDocumentsStatus = Enums.DocumentBookkeepingStatus.BookkeepingPosted Then
			FilterByDates = True;
		ElsIf Object.DateFrom = '00010101' AND Object.DateTo = '00010101' Then
			FilterByDates = False;
		Else
			FilterByDates = True;
		EndIf;
		
		FilterByPartialJournal = (Object.DisplayedDocumentsStatus = Enums.DocumentBookkeepingStatus.BookkeepingPosted And ValueIsFilled(Object.PartialJournal));
		
		QueryAddition = " WHERE
				|	BookkeepingPostedDocuments.Status = &Status
				|	AND CASE WHEN &ManualBookkeepingOperation = 0 THEN TRUE 
				|		 WHEN &ManualBookkeepingOperation = 1 THEN IsNull(BookkeepingOperationTable.Manual, FALSE) = FALSE
				|		 WHEN &ManualBookkeepingOperation = 2 THEN IsNull(BookkeepingOperationTable.Manual, TRUE) = TRUE
				|	END 
				|	AND BookkeepingPostedDocuments.Company = &Company
				|	" + ?(FilterByDocumentType, "AND BookkeepingPostedDocuments.DocumentType IN(&DocumentTypes)", "") + "
				|	" + ?(FilterByDates, "AND BookkeepingPostedDocuments.Document.Date BETWEEN &DateFrom AND &DateTo", "") + "
				|	" + ?(FilterByPartialJournal, "AND BookkeepingOperationTable.PartialJournal = &PartialJournal", "") + "
				|
				|ORDER BY
				|	" + ?(Object.SortingMethod = 1, "BookkeepingPostedDocuments.DocumentType,", "") + "
				|	BookkeepingPostedDocuments.Document.Date";
				
		FilterDateTo = ?(Object.DateTo = '00010101', '29991231', Object.DateTo);
		
		DocumentTypesArray = New Array();
		For Each DocumentType In Object.DocumentTypes.Types() Do
			DocumentTypesArray.Add(New(DocumentType));
		EndDo;
		
		Query.SetParameter("Company",Object.Company);
		Query.SetParameter("Status", Object.DisplayedDocumentsStatus);
		Query.SetParameter("DocumentTypes", DocumentTypesArray);
		Query.SetParameter("DateFrom", BegOfDay(Object.DateFrom));
		Query.SetParameter("DateTo", EndOfDay(FilterDateTo));
		Query.SetParameter("PartialJournal", Object.PartialJournal);
		Query.SetParameter("ManualBookkeepingOperation", Object.ManualBookkeepingOperation);
		If Object.SelectTopX Then
			Query.Text = StrReplace(Query.Text, "SELECT", "SELECT TOP " + Format(Object.TopSelectionNumber, "NFD=0; NG="));
		EndIf;
	
	Else
		QueryAddition = " WHERE BookkeepingPostedDocuments.Document IN (&DocumentsFromList)";
		Query.SetParameter("DocumentsFromList",Object.ChoosenDocumentsFromList.Unload().UnloadColumn("Document"));
	EndIf;
	
			
	JobParameters = New Array;
	JobParameters.Add(Query.Text+QueryAddition);
	JobParameters.Add(Query.Parameters);
	
	Return LongActionsServer.ExecuteInBackground(UUID, "CommonAtServer.ExecuteSimpleQuery", JobParameters);
	
EndFunction

&AtServer
Procedure SetCheckForAll(Val Check)
	
	If Items.DocumentList.SelectedRows.Count()>1 Then
		
		For Each SelectedRow In Items.DocumentList.SelectedRows Do	
			Object.DocumentList.FindByID(SelectedRow).Check = Check;	
		EndDo;	
		
	Else
		
		For Each DocumentListRow In Object.DocumentList Do
			DocumentListRow.Check = Check;
		EndDo;	
		
	EndIf;	
	
EndProcedure	

&AtServer
Function ProcessTabularPartRowsInJob(Val CommandStructure)
	
	JobParameters = New Array;
	JobParameters.Add(CommandStructure);
	JobParameters.Add(Object.DocumentList.Unload());
	JobParameters.Add(Object.DynamicFilter);
	JobParameters.Add(Object.DisplayedDocumentsStatus);
	Return LongActionsServer.ExecuteInBackground(UUID, "DataProcessors.BookkeepingPosting.ProcessTabularPartRows", JobParameters);	
	
EndFunction	




