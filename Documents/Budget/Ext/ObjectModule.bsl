#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If Not Constants.FunctionalOptionAccountingByMultipleBusinessActivities.Get() Then
		
		For Each LineIncome in Incomings Do
			
			If LineIncome.Account.TypeOfAccount = Enums.GLAccountsTypes.OtherIncome Then
				LineIncome.BusinessActivity = Catalogs.BusinessActivities.Other;
			Else
				LineIncome.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
			EndIf;
			
		EndDo;
		
		For Each RowsExpenses in Expenses Do
			
			If RowsExpenses.Account.TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses
				OR RowsExpenses.Account.TypeOfAccount = Enums.GLAccountsTypes.CreditInterestRates Then
				RowsExpenses.BusinessActivity = Catalogs.BusinessActivities.Other;
			Else
				RowsExpenses.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure // BeforeWrite()

// Adds additional attributes necessary for document
// posting to passed structure.
//
// Parameters:
//  StructureAdditionalProperties - Structure of additional document properties.
//
Procedure AddAttributesToAdditionalPropertiesForPosting(StructureAdditionalProperties)
	
	StructureAdditionalProperties.ForPosting.Insert("PlanningPeriod", PlanningPeriod);
	StructureAdditionalProperties.ForPosting.Insert("Periodicity", PlanningPeriod.Periodicity);
	StructureAdditionalProperties.ForPosting.Insert("StartDate", PlanningPeriod.StartDate);
	StructureAdditionalProperties.ForPosting.Insert("EndDate", PlanningPeriod.EndDate);
	
EndProcedure // AddAttributesToAdditionalPropertiesForPosting()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each LineIncome IN Incomings Do
	
		If LineIncome.Account.TypeOfAccount = Enums.GLAccountsTypes.Incomings Then
			
			If Not ValueIsFilled(LineIncome.StructuralUnit) Then
				
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject, 
					"Division is not indicated on string. Fillings is required for basic activity incomings.",
					"Incomings",
					LineIncome.LineNumber,
					"StructuralUnit",
					Cancel
				);
				
			EndIf;
			
		EndIf;
		
		If LineIncome.Account.TypeOfAccount = Enums.GLAccountsTypes.OtherIncome Then
			
			If ValueIsFilled(LineIncome.BusinessActivity) AND (LineIncome.BusinessActivity <> Catalogs.BusinessActivities.Other) Then
				
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject, 
					"The type of activity specified in the row differs from 'Other'. For other income, it is necessary to specify the other type of activity.",
					"Incomings",
					LineIncome.LineNumber,
					"BusinessActivity",
					Cancel
				);
				
			EndIf;
			
			If ValueIsFilled(LineIncome.StructuralUnit) Then
				
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject, 
					"Division is indicated on string. For the income from other types of business activity, filling is not required.",
					"Incomings",
					LineIncome.LineNumber,
					"StructuralUnit",
					Cancel
				);
				
			EndIf;
			
		EndIf;
	
	EndDo;
	
	For Each RowsExpenses IN Expenses Do
		
		If RowsExpenses.Account.TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses
		 OR RowsExpenses.Account.TypeOfAccount = Enums.GLAccountsTypes.CreditInterestRates Then
			
			If Not ValueIsFilled(RowsExpenses.BusinessActivity) Then
				
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					"Activity direction is indicated on string.",
					"Expenses",
					RowsExpenses.LineNumber,
					"BusinessActivity",
					Cancel
				);
				
			EndIf;
			
			If ValueIsFilled(RowsExpenses.BusinessActivity) AND (RowsExpenses.BusinessActivity <> Catalogs.BusinessActivities.Other) Then
				
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					"The type of activity specified in the row differs from 'Other'. For other expenses, it is necessary to specify the other type of activity.",
					"Expenses",
					RowsExpenses.LineNumber,
					"BusinessActivity",
					Cancel
				);
				
			EndIf;
			
			If ValueIsFilled(RowsExpenses.StructuralUnit) Then
				
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject, 
					"Division is indicated on string. For expenses on other type of activities, filling is not required.",
					"Expenses",
					RowsExpenses.LineNumber,
					"StructuralUnit",
					Cancel
				);
				
			EndIf;
			
		Else
			
		EndIf;
		
		If RowsExpenses.Account.TypeOfAccount = Enums.GLAccountsTypes.CostOfGoodsSold Then
			
			If Constants.FunctionalOptionAccountingByMultipleBusinessActivities.Get() AND
				(NOT ValueIsFilled(RowsExpenses.BusinessActivity) OR (RowsExpenses.BusinessActivity = Catalogs.BusinessActivities.Other)) Then
				
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					"The main business activity is not indicated on string. The basic activity indication is required for cost of sales.",
					"Expenses",
					RowsExpenses.LineNumber,
					"BusinessActivity",
					Cancel
				);
				
			EndIf;
			
			If Not ValueIsFilled(RowsExpenses.StructuralUnit) Then
				
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject, 
					"Division is not indicated on string. Filling is required for cost of sales at basic activities.",
					"Expenses",
					RowsExpenses.LineNumber,
					"StructuralUnit",
					Cancel
				);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	AddAttributesToAdditionalPropertiesForPosting(AdditionalProperties);
	
	// Initialization of document data
	Documents.Budget.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectCashAssetsForecast(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpensesForecast(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectFinancialResultForecast(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
EndProcedure // UndoPosting()

#EndRegion

#EndIf