#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PredeterminedProceduresEventsHandlers

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		
		If DeletionMark AND Acts Then
			Acts = False;
		EndIf;
		
		IsClarificationByProductsAndServices = ?(RestrictionByProductsAndServicesVariant = Enums.DiscountRestrictionVariantsByProductsAndServices.ByProductsAndServices, ProductsAndServicesGroupsPriceGroups.Count() > 0, False);
		IsClarificationByProductsAndServicesCategories = ?(RestrictionByProductsAndServicesVariant = Enums.DiscountRestrictionVariantsByProductsAndServices.ByProductsAndServicesCategories, ProductsAndServicesGroupsPriceGroups.Count() > 0, False);
		IsClarificationByPriceGroups = ?(RestrictionByProductsAndServicesVariant = Enums.DiscountRestrictionVariantsByProductsAndServices.ByPriceGroups, ProductsAndServicesGroupsPriceGroups.Count() > 0, False);
		
		ThereIsSchedule = False;
		For Each CurrentTimetableString IN TimeByDaysOfWeek Do
			If CurrentTimetableString.Selected Then
				ThereIsSchedule = True;
				Break;
			EndIf;
		EndDo;
		
		IsRestrictionOnRecipientsCounterparties = DiscountRecipientsCounterparties.Count() > 0;
		IsRestrictionByRecipientsWarehouses = DiscountRecipientsWarehouses.Count() > 0;
		
		If RestrictionByProductsAndServicesVariant = Enums.DiscountRestrictionVariantsByProductsAndServices.ByProductsAndServices Then
			Query = New Query;
			Query.Text = 
				"SELECT
				|	AutomaticDiscountsProductsAndServicesGroupsPriceGroups.ValueClarification
				|INTO TU_AutomaticDiscountsProductsAndServicesGroupsPriceGroups
				|FROM
				|	&ProductsAndServicesGroupsPriceGroups AS AutomaticDiscountsProductsAndServicesGroupsPriceGroups
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT TOP 1
				|	TU_AutomaticDiscountsProductsAndServicesGroupsPriceGroups.ValueClarification
				|FROM
				|	TU_AutomaticDiscountsProductsAndServicesGroupsPriceGroups AS TU_AutomaticDiscountsProductsAndServicesGroupsPriceGroups
				|WHERE
				|	TU_AutomaticDiscountsProductsAndServicesGroupsPriceGroups.ValueClarification.IsFolder";
			
			Query.SetParameter("ByProductsAndServices", RestrictionByProductsAndServicesVariant);
			Query.SetParameter("ProductsAndServicesGroupsPriceGroups", ProductsAndServicesGroupsPriceGroups.Unload());
			
			Result = Query.Execute();
			
			ThereAreFoldersToBeClarifiedByProductsAndServices = Not Result.IsEmpty();
		Else
			ThereAreFoldersToBeClarifiedByProductsAndServices = False;
		EndIf;
		
		// To remove rows without conditions.
		MRowsToDelete = New Array;
		For Each CurrentCondition IN ConditionsOfAssignment Do
			If CurrentCondition.AssignmentCondition.IsEmpty() Then
				MRowsToDelete.Add(CurrentCondition);
			EndIf;
		EndDo;
		
		For Each RemovedRow IN MRowsToDelete Do
			ConditionsOfAssignment.Delete(RemovedRow);
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure - FillCheckProcessing event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If IsFolder Then
		Return;
	EndIf;
	
	NoncheckableAttributeArray = New Array;
	
	If AssignmentMethod <> Enums.DiscountsMarkupsProvidingWays.Amount Then
		NoncheckableAttributeArray.Add("AssignmentCurrency");
	EndIf;
	
	CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, NoncheckableAttributeArray);
	
EndProcedure

// Procedure - FillingProcessor event handler.
//
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If Not IsFolder Then
		AssignmentCurrency = Constants.AccountingCurrency.Get();
	Else
		SharedUsageVariant = Constants.DiscountsMarkupsSharedUsageOptions.Get();
	EndIf;
	
EndProcedure

Procedure UpdateInformationInServiceInformationRegister(Cancel)
	
	SetPrivilegedMode(True);
	
	// Update information in service information register used to optimize
	// number of cases which require to calculate automatic discounts.
	RecordManager = InformationRegisters.ServiceAutomaticDiscounts.CreateRecordManager();
	
	Block = New DataLock;
	LockItem = Block.Add();
	LockItem.Region = "InformationRegister.ChangeProhibitionDates";
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		RecordManager.Read();
			
		Query = New Query;
		Query.Text = 
			"SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscounts.ConditionsOfAssignment AS AutomaticDiscountsAssignmentCondition
			|WHERE
			|	AutomaticDiscountsAssignmentCondition.AssignmentCondition.AssignmentCondition = &ForOneTimeSalesVolume
			|	AND AutomaticDiscountsAssignmentCondition.AssignmentCondition.UseRestrictionCriterionForSalesVolume = &Amount
			|	AND AutomaticDiscountsAssignmentCondition.Ref.Acts
			|	AND Not AutomaticDiscountsAssignmentCondition.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscounts.ConditionsOfAssignment AS AutomaticDiscountsAssignmentCondition
			|WHERE
			|	AutomaticDiscountsAssignmentCondition.AssignmentCondition.AssignmentCondition = &ForKitPurchase
			|	AND AutomaticDiscountsAssignmentCondition.Ref.Acts
			|	AND Not AutomaticDiscountsAssignmentCondition.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscounts.DiscountRecipientsCounterparties AS AutomaticDiscountsDiscountRecipientsCounterparties
			|WHERE
			|	AutomaticDiscountsDiscountRecipientsCounterparties.Ref.Acts
			|	AND Not AutomaticDiscountsDiscountRecipientsCounterparties.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscounts.DiscountRecipientsWarehouses AS AutomaticDiscountsDiscountRecipientsWarehouses
			|WHERE
			|	AutomaticDiscountsDiscountRecipientsWarehouses.Ref.Acts
			|	AND Not AutomaticDiscountsDiscountRecipientsWarehouses.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscounts.TimeByDaysOfWeek AS AutomaticDiscountsTimeByWeekDays
			|WHERE
			|	AutomaticDiscountsTimeByWeekDays.Ref.Acts
			|	AND Not AutomaticDiscountsTimeByWeekDays.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscounts AS AutomaticDiscounts
			|WHERE
			|	Not AutomaticDiscounts.DeletionMark
			|	AND AutomaticDiscounts.Acts";
		
		Query.SetParameter("ForOneTimeSalesVolume", Enums.DiscountsMarkupsProvidingConditions.ForOneTimeSalesVolume);
		Query.SetParameter("ForKitPurchase", Enums.DiscountsMarkupsProvidingConditions.ForKitPurchase);
		Query.SetParameter("Amount", Enums.DiscountMarkupUseLimitCriteriaForSalesVolume.Amount);
		Query.SetParameter("Ref", Ref);
		
		MResults = Query.ExecuteBatch();
		
		// There is a discount depending on the amount.
		Selection = MResults[0].Select();
		RecordManager.AmountDependingDiscountsAvailable = Selection.Next();
		
		// There is a discount for complete purchase.
		Selection = MResults[1].Select();
		RecordManager.PurchaseSetDependingDiscountsAvailable = Selection.Next();
		
		// There are discounts with restriction by counterparties.
		Selection = MResults[2].Select();
		RecordManager.CounterpartyRecipientDiscountsAvailable = Selection.Next();
		
		// There are discounts with restriction by counterparties.
		Selection = MResults[3].Select();
		RecordManager.WarehouseRecipientDiscountsAvailable = Selection.Next();
		
		// There are discounts with timetable.
		Selection = MResults[4].Select();
		RecordManager.ScheduleDiscountsAvailable = Selection.Next();
		
		RecordManager.Write();
		
		// There are applicable discounts.
		Selection = MResults[5].Select();
		Constants.ThereAreAutomaticDiscounts.Set(Selection.Next());
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		ErrorPresentation = BriefErrorDescription(ErrorInfo());
	EndTry;
	
	SetPrivilegedMode(False);
	
	WriteLogEvent(
			NStr("en = 'Automatic discounts. Service information on automatic discounts'",
			     CommonUseClientServer.MainLanguageCode()),
			?(Cancel, EventLogLevel.Error, EventLogLevel.Information),
			,
			,
			ErrorPresentation,
			EventLogEntryTransactionMode.Independent);
	
	If Cancel Then
		Raise
			NStr("en = 'Failed to record service information on automatic discounts and extra charges.
			           |Details in the event log.'");
	EndIf;
	
EndProcedure

// Procedure - event handler OnWrite.
//
Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		If Not (AdditionalProperties.Property("RegisterServiceAutomaticDiscounts")
			AND AdditionalProperties.RegisterServiceAutomaticDiscounts = False) Then
			UpdateInformationInServiceInformationRegister(Cancel);
		EndIf;
		
		Return;
	EndIf;
	
	UpdateInformationInServiceInformationRegister(Cancel);
	
EndProcedure

#EndRegion

#EndIf