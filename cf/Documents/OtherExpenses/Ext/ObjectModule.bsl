#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = Expenses.Total("Amount");
	
	If Not Constants.FunctionalOptionAccountingByMultipleBusinessActivities.Get() Then
		
		For Each RowsExpenses in Expenses Do
			
			If RowsExpenses.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				
				RowsExpenses.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
				
			EndIf;	
			
		EndDo;	
		
	EndIf;
	
EndProcedure // BeforeWrite()

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ObjectFillingSB.FillDocument(ThisObject, FillingData); 
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.OtherExpenses.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	// Other settlements
	SmallBusinessServer.ReflectSettlementsWithOtherCounterparties(AdditionalProperties, RegisterRecords, Cancel);
	// End Other settlements

	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);

	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);

EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OtherSettlementsAccounting Then
		If Correspondence.TypeOfAccount <> Enums.GLAccountsTypes.Debitors
			And Correspondence.TypeOfAccount <> Enums.GLAccountsTypes.Creditors Then
			
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
			SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
			
		EndIf;
		
		For Each CurrentRowExpenses In Expenses Do
			If CurrentRowExpenses.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Debitors 
				Or CurrentRowExpenses.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Creditors Then
				
				If CurrentRowExpenses.Counterparty.IsEmpty() Then
					MessageText = NStr("ru = 'Укажите контрагента в строке %LineNumber% списка ""Расходы"".'; en = 'Specify the counterparty in the line %LineNumber% of the list ""Expenses""'");
					MessageText = StrReplace(MessageText, "%LineNumber%", CurrentRowExpenses.LineNumber);
					SmallBusinessServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Expenses",
						CurrentRowExpenses.LineNumber,
						"Counterparty",
						Cancel
					);
				ElsIf CurrentRowExpenses.Counterparty.DoOperationsByContracts And CurrentRowExpenses.Contract.IsEmpty() Then
					MessageText = NStr("ru = 'Укажите договор в строке %LineNumber% списка ""Расходы"".'; en = 'Specify the contract in the line %LineNumber% of the list ""Expenses""'");
					MessageText = StrReplace(MessageText, "%LineNumber%", CurrentRowExpenses.LineNumber);
					SmallBusinessServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Expenses",
						CurrentRowExpenses.LineNumber,
						"Contract",
						Cancel
					);
					
				EndIf;
			EndIf;
		EndDo;
	Else
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
EndProcedure

#EndRegion

#EndIf