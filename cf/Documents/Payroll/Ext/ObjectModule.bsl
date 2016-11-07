#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function calculates the document amount.
//
Function GetDocumentAmount() Export

	TableAccruals = New ValueTable;
    Array = New Array;
	ReturnStructure = New Structure("AmountAccrued, AmountWithheld, DocumentAmount", 0, 0, 0);
	
	Array.Add(Type("CatalogRef.AccrualAndDeductionKinds"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableAccruals.Columns.Add("AccrualDeductionKind", TypeDescription);

	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableAccruals.Columns.Add("Amount", TypeDescription);
	
	For Each TSRow IN AccrualsDeductions Do
		NewRow = TableAccruals.Add();
        NewRow.AccrualDeductionKind = TSRow.AccrualDeductionKind;
        NewRow.Amount = TSRow.Amount;
	EndDo;
	For Each TSRow IN IncomeTaxes Do
		NewRow = TableAccruals.Add();
        NewRow.AccrualDeductionKind = TSRow.AccrualDeductionKind;
        NewRow.Amount = TSRow.Amount;
	EndDo;
	
	Query = New Query("SELECT
	                      |	TableAccrualsDeductions.AccrualDeductionKind,
	                      |	TableAccrualsDeductions.Amount
	                      |INTO TableAccrualsDeductions
	                      |FROM
	                      |	&TableAccrualsDeductions AS TableAccrualsDeductions
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	SUM(CASE
	                      |			WHEN PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	                      |				THEN PayrollAccrualRetention.Amount
	                      |			ELSE 0
	                      |		END) AS AmountAccrued,
	                      |	SUM(CASE
	                      |			WHEN PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	                      |				THEN 0
	                      |			ELSE PayrollAccrualRetention.Amount
	                      |		END) AS AmountWithheld,
	                      |	SUM(CASE
	                      |			WHEN PayrollAccrualRetention.AccrualDeductionKind.Type = VALUE(Enum.AccrualAndDeductionTypes.Accrual)
	                      |				THEN PayrollAccrualRetention.Amount
	                      |			ELSE -1 * PayrollAccrualRetention.Amount
	                      |		END) AS DocumentAmount
	                      |FROM
	                      |	TableAccrualsDeductions AS PayrollAccrualRetention");
						  
	Query.SetParameter("TableAccrualsDeductions", TableAccruals);
	QueryResult = Query.ExecuteBatch();
	
	If QueryResult[1].IsEmpty() Then
		Return ReturnStructure;	
	Else
		FillPropertyValues(ReturnStructure, QueryResult[1].Unload()[0]);
		Return ReturnStructure;	
	EndIf; 

EndFunction // GetDocumentAmount()

#EndRegion

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = GetDocumentAmount().DocumentAmount;
	
	If Not Constants.FunctionalOptionAccountingByMultipleBusinessActivities.Get() Then
		
		For Each AccrualDetentionRow in AccrualsDeductions Do
			
			If AccrualDetentionRow.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				
				AccrualDetentionRow.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
				
			EndIf;	
			
		EndDo;	
		
	EndIf;	
	
EndProcedure // BeforeWrite()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.Payroll.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectAccrualsAndDeductions(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectPayrollPayments(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);

	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);

	// Control
	Documents.Payroll.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.Payroll.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure // UndoPosting()

#EndRegion

#EndIf