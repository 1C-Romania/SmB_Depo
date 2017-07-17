#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Constants.FunctionalOptionAccountingByMultipleDepartments.Get() Then
		
		For Each RowTaxes IN Taxes Do
			
			If RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.UnfinishedProduction
			 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
			 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Incomings
			 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				RowTaxes.Department = Catalogs.StructuralUnits.MainDepartment;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Not Constants.FunctionalOptionAccountingByMultipleBusinessActivities.Get() Then
		
		For Each RowTaxes IN Taxes Do
			If RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Incomings
			 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				RowTaxes.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
			EndIf;
		EndDo;
			
	EndIf;
	
	DocumentAmount = Taxes.Total("Amount");
	
EndProcedure // BeforeWrite()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each RowTaxes IN Taxes Do
		
		If Constants.FunctionalOptionAccountingByMultipleDepartments.Get()
		   AND (RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.UnfinishedProduction
		 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
		 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Incomings
		 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Expenses)
		 AND Not ValueIsFilled(RowTaxes.Department) Then
			MessageText = NStr("en='The ""Department"" attribute should be filled in for the ""%Mail%"" costs account specified in the %LineNumber% line of the ""Taxes"" list.';ru='Для счета затрат ""%Корреспонденция%"" указанного в строке %НомерСтроки% списка ""Налоги"", должен быть заполнен реквизит ""Подразделение"".'"
			);
			MessageText = StrReplace(MessageText, "%Correspondence%", TrimAll(String(RowTaxes.Correspondence))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowTaxes.LineNumber));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Taxes",
				RowTaxes.LineNumber,
				"Department",
				Cancel
			);
		EndIf;
		
	EndDo;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting(). Creates
// a document movement by accumulation registers and accounting register.
//
// 1. Delete the existing document transactions.
// 2. Generation document header structure with
// fields used in document post algorithms.
// 3. header value filling check and tabular document sections.
// 4. Creation temporary table by document which
// is necessary for transaction generating.
// 5. Creating the document records in accumulation register.
// 6. Creating the document records in accounting register.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.TaxAccrual.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
EndProcedure // UndoPosting()

#EndRegion

#EndIf