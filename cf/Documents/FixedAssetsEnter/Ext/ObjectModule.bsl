#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Executes preliminary control.
//
Procedure RunPreliminaryControl(Cancel)
	
	// Check Row duplicates.
	Query = New Query();
	
	Query.Text = 
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.FixedAsset
	|INTO DocumentTable
	|FROM
	|	&DocumentTable AS DocumentTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(TableOfDocument1.LineNumber) AS LineNumber,
	|	TableOfDocument1.FixedAsset
	|FROM
	|	DocumentTable AS TableOfDocument1
	|		INNER JOIN DocumentTable AS TableOfDocument2
	|		ON TableOfDocument1.LineNumber <> TableOfDocument2.LineNumber
	|			AND TableOfDocument1.FixedAsset = TableOfDocument2.FixedAsset
	|
	|GROUP BY
	|	TableOfDocument1.FixedAsset
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("DocumentTable", FixedAssets);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		QueryResultSelection = QueryResult.Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en='The ""%FixedAsset%"" property in the %LineNumber% line of the ""Property"" list is specified again.';ru='Имущество ""%ВнеоборотныйАктив%"" указанное в строке %НомерСтроки% списка ""Имущество"", указано повторно.'"
			);
			MessageText = StrReplace(MessageText, "%LineNumber%", QueryResultSelection.LineNumber);
			MessageText = StrReplace(MessageText, "%FixedAsset%", QueryResultSelection.FixedAsset);
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				QueryResultSelection.LineNumber,
				"FixedAsset",
				Cancel
			);

		EndDo;
	EndIf;
	
	// Check cost.
	TotalOriginalCost = 0;
	
	Query = New Query;
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("FixedAssetsList", FixedAssets.UnloadColumn("FixedAsset"));
	
	Query.Text =
	"SELECT
	|	SUM(FixedAssets.InitialCost) AS InitialCost
	|FROM
	|	Catalog.FixedAssets AS FixedAssets
	|WHERE
	|	FixedAssets.Ref IN (&FixedAssetsList)";
	
	QuerySelection = Query.Execute().Select();
	
	If QuerySelection.Next() Then
		TotalOriginalCost = QuerySelection.InitialCost;
	EndIf;
		
	If TotalOriginalCost <> Amount Then
		MessageText = NStr("en='Products and services amount: %Amount% does not correspond to the amount of initial property costs: %TotalInitialCost%';ru='Стоимость номенклатуры: %Сумма% , не соответствует сумме первоначальных стоимостей имущества: %ИтогПервоначальнаяСтоимость%'"
		);
		MessageText = StrReplace(MessageText, "%Amount%", TrimAll(String(Amount))); 
		MessageText = StrReplace(MessageText, "%TotalOriginalCost%", TrimAll(String(TotalOriginalCost)));
		SmallBusinessServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			Undefined,
			Undefined,
			"",
			Cancel
		);
	EndIf;
	
	Query.Text =
	"SELECT
	|	NestedSelect.FixedAsset AS FixedAsset
	|FROM
	|	(SELECT
	|		FixedAssetsStates.FixedAsset AS FixedAsset,
	|		SUM(CASE
	|				WHEN FixedAssetsStates.State = VALUE(Enum.FixedAssetsStates.AcceptedForAccounting)
	|					THEN 1
	|				ELSE -1
	|			END) AS CurrentState
	|	FROM
	|		InformationRegister.FixedAssetsStates AS FixedAssetsStates
	|	WHERE
	|		FixedAssetsStates.Recorder <> &Ref
	|		AND FixedAssetsStates.Company = &Company
	|		AND FixedAssetsStates.FixedAsset IN(&FixedAssetsList)
	|	
	|	GROUP BY
	|		FixedAssetsStates.FixedAsset) AS NestedSelect
	|WHERE
	|	NestedSelect.CurrentState > 0";
	
	Query.SetParameter("Ref", Ref);
	
	QueryResult = Query.Execute();
	ArrayVAStatus = QueryResult.Unload().UnloadColumn("FixedAsset");
	
	For Each RowOfFixedAssets IN FixedAssets Do
			
		If ArrayVAStatus.Find(RowOfFixedAssets.FixedAsset) <> Undefined Then
			MessageText = NStr("en='The current state of the ""%FixedAsset%"" property specified in the %LineNumber% line of the ""Property"" list is ""Entered in the books"".';ru='Для имущества ""%ВнеоборотныйАктив%"" указанного в строке %НомерСтроки% списка ""Имущество"", текущее состояние ""Принят к учету"".'"
			);
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowOfFixedAssets.LineNumber));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"FixedAsset",
				Cancel
			);
		EndIf;
		
	EndDo;
	
EndProcedure // RunPreliminaryControl()

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssets(FillingData)
	
	NewRow = FixedAssets.Add();
	NewRow.FixedAsset = FillingData;
	NewRow.AccrueDepreciation = True;
	NewRow.AccrueDepreciationInCurrentMonth = True;
	
	User = Users.CurrentUser();
	SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDepartment);

	NewRow.StructuralUnit = MainDepartment;
	
	
EndProcedure // FillByFixedAssets()

#EndRegion

#Region EventsHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.FixedAssets") Then
		FillByFixedAssets(FillingData);
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Constants.FunctionalOptionAccountingByMultipleBusinessActivities.Get() Then
		
		For Each RowFixedAssets in FixedAssets Do
			
			If RowFixedAssets.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				
				RowFixedAssets.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure // BeforeWrite()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Preliminary control execution.
	RunPreliminaryControl(Cancel);
	
	// Correctness of filling.
	For Each RowOfFixedAssets IN FixedAssets Do
			
		If RowOfFixedAssets.FixedAsset.DepreciationMethod = Enums.FixedAssetsDepreciationMethods.Linear
		   AND RowOfFixedAssets.UsagePeriodForDepreciationCalculation = 0 Then
			MessageText = NStr("en='For property ""%FixedAsset%"" indicated in string %LineNumber% of list ""Property"" should be filled with ""Usage period for depreciation calculation"".';ru='Для имущества ""%ВнеоборотныйАктив%"" указанного в строке %НомерСтроки% списка ""Имущество"", должен быть заполнен ""Срок использования для вычисления амортизации"".'"
			);
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowOfFixedAssets.LineNumber));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"UsagePeriodForDepreciationCalculation",
				Cancel
			);
		EndIf;
			
		If RowOfFixedAssets.FixedAsset.DepreciationMethod = Enums.FixedAssetsDepreciationMethods.ProportionallyToProductsVolume
		   AND RowOfFixedAssets.AmountOfProductsServicesForDepreciationCalculation = 0 Then
			MessageText = NStr("en='For property ""%FixedAsset%"" indicated in string %LineNumber% of list ""Property"" should be filled with ""Product (work) volume for depreciation calculation in physical terms."".';ru='Для имущества ""%ВнеоборотныйАктив%"" указанного в строке %НомерСтроки% списка ""Имущество"", должен быть заполнен ""Объем продукции (работ) для исчисления амортизации в натуральных ед."".'"
			);
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowOfFixedAssets.LineNumber));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"AmountOfProductsServicesForDepreciationCalculation",
				Cancel
			);
		EndIf;
		
	EndDo;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.FixedAssetsEnter.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectFixedAssetStatuses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectFixedAssetsParameters(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryForExpenseFromWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Creating control of negative balances.
	Documents.FixedAssetsEnter.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	
	// Creating control of negative balances.
	Documents.FixedAssetsEnter.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure // UndoPosting()

#EndRegion

#EndIf