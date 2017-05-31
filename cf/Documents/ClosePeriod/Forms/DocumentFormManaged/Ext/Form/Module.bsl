
#Region BaseFormsProcedures

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	DocumentsFormAtServer.OnCreateAtServer(ThisForm, Cancel, StandardProcessing);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If Object.Ref.IsEmpty() Then
		//SetBaseNumberPresentationAtServer();
	Endif;		
	
	DocumentsFormAtClient.OnOpen(ThisForm, Cancel);
	
	TotalAmountDifference = Object.ClosePeriodRecords.Total("AmountDr") - Object.ClosePeriodRecords.Total("AmountCr");
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	NotificationProcessingAtServer(EventName, Parameter);
EndProcedure

&AtServer
Procedure NotificationProcessingAtServer(EventName, Parameter)
	DocumentsFormAtServer.NotificationProcessingAtServer(ThisForm, EventName, Parameter);
EndProcedure

#EndRegion

#Region StandardCommonCommands

&AtServer
Function PostAtServer()	 
	Return DocumentsFormAtServer.Post(ThisForm);	  
EndFunction

&AtClient
Procedure PostPrintClose(Command)
	If PostAtServer() Then
		DocumentsFormAtClient.PostPrintClose(ThisForm);
	EndIf;
EndProcedure

&AtServer
Procedure ChangeDocumentsHeaderAtServer(Recalculate = True) Export
	DocumentsFormAtServer.SetFormDocumentTitle(ThisForm);
EndProcedure

&AtClient
Procedure ChangeDocumentsHeader(MainParameters, AdditionalParameters) Export
	DocumentsFormAtClient.ChangeDocumentsHeader(ThisForm, MainParameters, AdditionalParameters);
EndProcedure

&AtClient
Procedure UpdateDialog() Export
	DocumentsFormAtClient.UpdateDialog(ThisForm);
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	DocumentsFormAtClient.AfterWrite(ThisForm);
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	DocumentsFormAtServer.AfterWriteAtServer(ThisForm, CurrentObject, WriteParameters);
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters) Export	
	DocumentsFormAtServer.BeforeWriteAtServer(ThisForm, Cancel, CurrentObject, WriteParameters);
EndProcedure

#EndRegion

#Region ItemsEvents

&AtClient
Procedure NumberPreviewOnChange(Item)
	If Object.ManualChangeNumber Then
		DocumentsFormAtClient.ChangeDocumentsHeaderData(ThisForm, Item);
	Else
		EndTextNumberOnChange = New NotifyDescription("EndTextNumberOnChange", ThisForm, New Structure("ItemName", Item.Name));
		ShowQueryBox(EndTextNumberOnChange, NStr("en='ATTENTION! After changing the number automatic numbering for this document will be disabled! Enable number editing?';pl='UWAGA! Po zmianie numeru numeracja automatyczna tego dokumentu zostanie wyłączona! Włączyć moźliwość zmiany numeru?';ru='ВНИМАНИЕ! После изменения номера автоматическая нумерация документов будет отключена! Разрешить редактирование номера документа?'"), QuestionDialogMode.YesNo);
	EndIf;
EndProcedure

&AtClient
Procedure NumberPreviewStartChoice(Item, ChoiceData, StandardProcessing)
	ShowChooseFromList(New NotifyDescription("PrefixOnChange", ThisForm), ThisForm["PrefixList"], Item);
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	DocumentsFormAtClient.ChangeDocumentsHeaderData(ThisForm, Item);
EndProcedure

&AtClient
Procedure PrefixOnChange(SelectedElement, AdditionalParameters) Export
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	If SelectedElement.Value = "NumberSettings" Then
		OpenForm("InformationRegister.DocumentsNumberingSettings.Form.RecordFormSetting", New Structure("DocumentType", Object.Ref), ThisForm);
		Return;
	EndIf;
	Object["ManualChangeNumber"] = False;
	Object["Prefix"] = SelectedElement.Value;
	DocumentsFormAtClient.ChangeDocumentsHeaderData(ThisForm);
EndProcedure

&AtClient
Procedure EndTextNumberOnChange(QuestionAnswer, AdditionalParameters) Export
	If QuestionAnswer = DialogReturnCode.Yes Then
		Object.ManualChangeNumber = True;
	EndIf;
	DocumentsFormAtClient.ChangeDocumentsHeaderData(ThisForm, Items[AdditionalParameters.ItemName]);
EndProcedure

#EndRegion

#Region ClosePeriodRecords

&AtClient
Procedure FinancialYearOnChange(Item)
	FinancialYearOnChangeServer();
EndProcedure

&AtServer
Procedure FinancialYearOnChangeServer()
	If ValueIsFilled(Object.FinancialYear) Then
		Object.PostingDate = Object.FinancialYear.DateTo;	
	EndIf;
EndProcedure

&AtClient
Procedure ClosePeriodRecordsSelection(Item, SelectedRow, Field, StandardProcessing)   // ??? TODO
	//If Field = Item.Fields.Account Then
	//		If ValueIsFilled(SelectedRow[Field.Data]) Then
	//			SelectedRow[Field.Data].GetForm(,Item,Item).Open();
	//		EndIf;	
	//	EndIf;	
EndProcedure

&AtClient
Procedure PeriodEndClosingAccountOnChange(Item)
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("PeriodEndClosingAccount", "PeriodEndClosingExtDimension",Object,Items);
	PeriodEndClosingExtDimensionAtServer("PeriodEndClosingAccount", "PeriodEndClosingExtDimension");
EndProcedure

&AtServer
Procedure PeriodEndClosingExtDimensionAtServer(Val AccountName, Val ExtDimensionName)
	DialogsAtServer.CheckAccountsExtDimensions(Object[AccountName],"PeriodEndClosingExtDimension",Object);
EndProcedure

&AtServer
Procedure RetainedEarningsExtDimensionAtServer(Val AccountName, Val ExtDimensionName)
	DialogsAtServer.CheckAccountsExtDimensions(Object[AccountName],"RetainedEarningsExtDimension",Object);
EndProcedure

&AtClient
Procedure RetainedEarningsAccountOnChange(Item)
	AccountingAtClient.AllowAccountsExtDimensionsInManagedForm("RetainedEarningsAccount","RetainedEarningsExtDimension",Object,Items);
	RetainedEarningsExtDimensionAtServer("RetainedEarningsAccount","RetainedEarningsExtDimension");
EndProcedure

&AtClient 
Procedure TabularPartFillingResponse(AdditionalParameters = Undefined) Export 
	FillItems(); // AtServer
	
	If Object.ClosePeriodRecords.Count()=0 Then
		Message(NStr("en = 'Resultant account''s balance is missing'; pl = 'Brak sald na kontach wynikowych na datę księgowania.'"), MessageStatus.VeryImportant);	
		If AdditionalParameters.Cancel Then
			Return;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure ContinueProcessingFill(ReplacePreviousLines, VarClosePeriodRecords, Cancel)
	If NOT ReplacePreviousLines Then 
		Return;
	EndIf;
	
	NotifyDescr	= New NotifyDescription("TabularPartFillingResponse", ThisObject);
	DocumentsFormAtClient.TabularPartFillingRequest(NotifyDescr, Object.Materials.Count(), Object.Posted);
	
EndProcedure

&AtClient
Procedure AfterQueryBoxFill(Answer, QueryParams) Export 
	If Answer = DialogReturnCode.Yes Then
		ReplacePreviousLines = True;
	Else
		ReplacePreviousLines = False;
	EndIf;
	
	ContinueProcessingFill(ReplacePreviousLines, QueryParams.VarClosePeriodRecords, QueryParams.Cancel);
EndProcedure

&AtClient
Procedure Fill(Command)
	
	Cancel = False;
	
	If ValueIsNotFilled(Object.FinancialYear) OR ValueIsNotFilled(Object.PostingDate) Then
		Message(NStr("en = 'You must fill financial year and posting date.'; pl = 'Aby wypełnić tabelę nalezy wybrać rok finansowy oraz datę księgowania.'"), MessageStatus.VeryImportant);	
	EndIf;
		
	If Cancel Then
		Return;
	EndIf;
	
	VarClosePeriodRecords = object.ClosePeriodRecords; // assignment to variable
	
	If Object.ClosePeriodRecords.Count() Then
		QueryParams	= New Structure("VarClosePeriodRecords, Cancel", VarClosePeriodRecords, Cancel);
		Notify		= New NotifyDescription("AfterQueryBoxFill", ThisObject, QueryParams);
		QueryText	= NStr("en='Do you want to replace existing rows? (''No'' would add new rows under existing ones)';
							|pl='Czy chcesz zastąpić istniejące wiersze? (Po wybraniu ''Nie'' nowe wiersze zostaną dodane pod istniejącymi)';");
							
		ShowQueryBox(Notify, QueryText, QuestionDialogMode.YesNo);
	Else
		ReplacePreviousLines = False;
		
		ContinueProcessingFill(ReplacePreviousLines, VarClosePeriodRecords, Cancel);
	EndIf;

EndProcedure

&AtServer
Procedure FillItems() 
		
	Query = New Query;
	Query.Text = "SELECT
	             |	BookkeepingBalance.Account,
	             |	BookkeepingBalance.ExtDimension1,
	             |	BookkeepingBalance.ExtDimension2,
	             |	BookkeepingBalance.ExtDimension3,
	             |	BookkeepingBalance.AmountBalanceDr AS AmountDr,
	             |	BookkeepingBalance.AmountBalanceCr AS AmountCr,
	             |	BookkeepingBalance.Currency,
	             |	BookkeepingBalance.CurrencyAmountBalance
	             |FROM
	             |	AccountingRegister.Bookkeeping.Balance(&PostingDate, Account.Resultant, , Company = &Company) AS BookkeepingBalance";
	
	Query.SetParameter("Company", Object.Company);
	Query.SetParameter("PostingDate",Date(Year(Object.PostingDate), Month(Object.PostingDate), Day(Object.PostingDate), 23, 59, 50));
	
	Selection = Query.Execute().Select();
	Object.ClosePeriodRecords.Clear();
	
	While Selection.Next() Do
		NewRow = Object.ClosePeriodRecords.Add();
		FillPropertyValues(NewRow,Selection);
		// Warning!!! Inverted..for closing accounts
		NewRow.AmountCr = Selection.AmountDr;
		NewRow.AmountDr = Selection.AmountCr;
		NewRow.CurrencyAmount = abs(Selection.CurrencyAmountBalance);
	EndDo;	
	
	//TotalAmountDifference = Object.ClosePeriodRecords.TotalAmountDr - Object.ClosePeriodRecords.TotalAmountCr;	
	TotalAmountDifference = Object.ClosePeriodRecords.Total("AmountDr") - Object.ClosePeriodRecords.Total("AmountCr");
EndProcedure

#EndRegion
