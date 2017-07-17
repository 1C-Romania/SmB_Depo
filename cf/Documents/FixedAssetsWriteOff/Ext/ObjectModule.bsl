#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Executes preliminary control.
//
Procedure RunPreliminaryControl(Cancel)
	
	// Row duplicates.
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
	
	Query = New Query;
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("FixedAssetsList", FixedAssets.UnloadColumn("FixedAsset"));
	
	// Check property states.
	Query.Text =
	"SELECT
	|	FixedAssetStateSliceLast.FixedAsset AS FixedAsset
	|FROM
	|	InformationRegister.FixedAssetsStates.SliceLast(, Company = &Company) AS FixedAssetStateSliceLast
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.FixedAsset AS FixedAsset
	|FROM
	|	(SELECT
	|		FixedAssetState.FixedAsset AS FixedAsset,
	|		SUM(CASE
	|				WHEN FixedAssetState.State = VALUE(Enum.FixedAssetsStates.AcceptedForAccounting)
	|					THEN 1
	|				ELSE -1
	|			END) AS CurrentState
	|	FROM
	|		InformationRegister.FixedAssetsStates AS FixedAssetState
	|	WHERE
	|		FixedAssetState.Recorder <> &Ref
	|		AND FixedAssetState.Company = &Company
	|		AND FixedAssetState.FixedAsset IN(&FixedAssetsList)
	|	
	|	GROUP BY
	|		FixedAssetState.FixedAsset) AS NestedSelect
	|WHERE
	|	NestedSelect.CurrentState > 0";
	
	ResultsArray = Query.ExecuteBatch();
	
	ArrayVAStatus = ResultsArray[0].Unload().UnloadColumn("FixedAsset");
	ArrayVAAcceptedForAccounting = ResultsArray[1].Unload().UnloadColumn("FixedAsset");
	
	For Each RowOfFixedAssets IN FixedAssets Do
		
		If ArrayVAStatus.Find(RowOfFixedAssets.FixedAsset) = Undefined Then
			MessageText = NStr("en='States are not registered for the %FixedAsset% property in the %LineNumber% line of the """"Property"""" list.';ru='Для имущества ""%ВнеоборотныйАктив%"" указанного в строке %НомерСтроки% списка """"Имущество"""", не зарегистрированы состояния.'"
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
		ElsIf ArrayVAAcceptedForAccounting.Find(RowOfFixedAssets.FixedAsset) = Undefined Then
			MessageText = NStr("en='The current state for the %FixedAsset% property in line No. %LineNumber% of the ""Property"" list is ""Taken off the books"".';ru='Для имущества ""%ВнеоборотныйАктив%"" указанного в строке %НомерСтроки% списка ""Имущество"", текущее состояние ""Снят с учета"".'"
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

// Calculates the assets depreciation.
//
Procedure CalculateDepreciation(FixedAsset)
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text = 
	"SELECT TOP 1
	|	FixedAssetsParametersSliceLast.Recorder.Company AS Company
	|FROM
	|	InformationRegister.FixedAssetsParameters.SliceLast AS FixedAssetsParametersSliceLast
	|WHERE
	|	FixedAssetsParametersSliceLast.FixedAsset = &FixedAsset";
	
	Query.SetParameter("FixedAsset", FixedAsset);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Company = Selection.Company;
	EndIf;
	
	Query.Text =
	"SELECT
	|	ListOfAmortizableFA.FixedAsset AS FixedAsset,
	|	PRESENTATION(ListOfAmortizableFA.FixedAsset) AS FixedAssetPresentation,
	|	ListOfAmortizableFA.FixedAsset.Code AS Code,
	|	ListOfAmortizableFA.BeginAccrueDepriciation AS BeginAccrueDepriciation,
	|	ListOfAmortizableFA.EndAccrueDepriciation AS EndAccrueDepriciation,
	|	ListOfAmortizableFA.EndAccrueDepreciationInCurrentMonth AS EndAccrueDepreciationInCurrentMonth,
	|	ISNULL(FACost.DepreciationClosingBalance, 0) AS DepreciationClosingBalance,
	|	ISNULL(FACost.DepreciationTurnover, 0) AS DepreciationTurnover,
	|	ISNULL(FACost.CostClosingBalance, 0) AS BalanceCost,
	|	ISNULL(FACost.CostOpeningBalance, 0) AS CostOpeningBalance,
	|	ISNULL(DepreciationBalancesAndTurnovers.CostOpeningBalance, 0) - ISNULL(DepreciationBalancesAndTurnovers.DepreciationOpeningBalance, 0) AS CostAtBegOfYear,
	|	ISNULL(ListOfAmortizableFA.FixedAsset.DepreciationMethod, 0) AS DepreciationAccrualMethod,
	|	ISNULL(ListOfAmortizableFA.FixedAsset.InitialCost, 0) AS OriginalCost,
	|	ISNULL(DepreciationParametersSliceLast.ApplyInCurrentMonth, 0) AS ApplyInCurrentMonth,
	|	DepreciationParametersSliceLast.Period AS Period,
	|	CASE
	|		WHEN DepreciationParametersSliceLast.ApplyInCurrentMonth
	|			THEN ISNULL(DepreciationParametersSliceLast.UsagePeriodForDepreciationCalculation, 0)
	|		ELSE ISNULL(DepreciationParametersSliceLastBegOfMonth.UsagePeriodForDepreciationCalculation, 0)
	|	END AS UsagePeriodForDepreciationCalculation,
	|	CASE
	|		WHEN DepreciationParametersSliceLast.ApplyInCurrentMonth
	|			THEN ISNULL(DepreciationParametersSliceLast.CostForDepreciationCalculation, 0)
	|		ELSE ISNULL(DepreciationParametersSliceLastBegOfMonth.CostForDepreciationCalculation, 0)
	|	END AS CostForDepreciationCalculation,
	|	ISNULL(DepreciationSignChange.UpdateAmortAccrued, FALSE) AS UpdateAmortAccrued,
	|	ISNULL(DepreciationSignChange.AccrueInCurMonth, FALSE) AS AccrueInCurMonth,
	|	ISNULL(FixedAssetOutputTurnovers.QuantityTurnover, 0) AS OutputVolume,
	|	CASE
	|		WHEN DepreciationParametersSliceLast.ApplyInCurrentMonth
	|			THEN ISNULL(DepreciationParametersSliceLast.AmountOfProductsServicesForDepreciationCalculation, 0)
	|		ELSE ISNULL(DepreciationParametersSliceLastBegOfMonth.AmountOfProductsServicesForDepreciationCalculation, 0)
	|	END AS AmountOfProductsServicesForDepreciationCalculation
	|INTO TemporaryTableForDepreciationCalculation
	|FROM
	|	(SELECT
	|		SliceFirst.AccrueDepreciation AS BeginAccrueDepriciation,
	|		SliceLast.AccrueDepreciation AS EndAccrueDepriciation,
	|		SliceLast.AccrueDepreciationInCurrentMonth AS EndAccrueDepreciationInCurrentMonth,
	|		SliceLast.FixedAsset AS FixedAsset
	|	FROM
	|		(SELECT
	|			FixedAssetStateSliceFirst.FixedAsset AS FixedAsset,
	|			FixedAssetStateSliceFirst.AccrueDepreciation AS AccrueDepreciation,
	|			FixedAssetStateSliceFirst.AccrueDepreciationInCurrentMonth AS AccrueDepreciationInCurrentMonth,
	|			FixedAssetStateSliceFirst.Period AS Period
	|		FROM
	|			InformationRegister.FixedAssetsStates.SliceLast(
	|					&BeginOfPeriod,
	|					Company = &Company
	|						AND FixedAsset IN (&FixedAssetsList)) AS FixedAssetStateSliceFirst) AS SliceFirst
	|			Full JOIN (SELECT
	|				FixedAssetStateSliceLast.FixedAsset AS FixedAsset,
	|				FixedAssetStateSliceLast.AccrueDepreciation AS AccrueDepreciation,
	|				FixedAssetStateSliceLast.AccrueDepreciationInCurrentMonth AS AccrueDepreciationInCurrentMonth,
	|				FixedAssetStateSliceLast.Period AS Period
	|			FROM
	|				InformationRegister.FixedAssetsStates.SliceLast(
	|						&EndOfPeriod,
	|						Company = &Company
	|							AND FixedAsset IN (&FixedAssetsList)) AS FixedAssetStateSliceLast) AS SliceLast
	|			ON SliceFirst.FixedAsset = SliceLast.FixedAsset) AS ListOfAmortizableFA
	|		LEFT JOIN AccumulationRegister.FixedAssets.BalanceAndTurnovers(
	|				&BegOfYear,
	|				,
	|				,
	|				,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS DepreciationBalancesAndTurnovers
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationBalancesAndTurnovers.FixedAsset
	|		LEFT JOIN AccumulationRegister.FixedAssets.BalanceAndTurnovers(
	|				&BeginOfPeriod,
	|				&EndOfPeriod,
	|				,
	|				,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS FACost
	|		ON ListOfAmortizableFA.FixedAsset = FACost.FixedAsset
	|		LEFT JOIN InformationRegister.FixedAssetsParameters.SliceLast(
	|				&EndOfPeriod,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS DepreciationParametersSliceLast
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationParametersSliceLast.FixedAsset
	|		LEFT JOIN InformationRegister.FixedAssetsParameters.SliceLast(
	|				&BeginOfPeriod,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS DepreciationParametersSliceLastBegOfMonth
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationParametersSliceLastBegOfMonth.FixedAsset
	|		LEFT JOIN (SELECT
	|			COUNT(DISTINCT TRUE) AS UpdateAmortAccrued,
	|			FixedAssetState.FixedAsset AS FixedAsset,
	|			FixedAssetStateSliceLast.AccrueDepreciationInCurrentMonth AS AccrueInCurMonth
	|		FROM
	|			InformationRegister.FixedAssetsStates AS FixedAssetState
	|				INNER JOIN InformationRegister.FixedAssetsStates.SliceLast(
	|						&EndOfPeriod,
	|						Company = &Company
	|							AND FixedAsset IN (&FixedAssetsList)) AS FixedAssetStateSliceLast
	|				ON FixedAssetState.FixedAsset = FixedAssetStateSliceLast.FixedAsset
	|		WHERE
	|			FixedAssetState.Period between &BeginOfPeriod AND &EndOfPeriod
	|			AND FixedAssetState.Company = &Company
	|			AND FixedAssetState.FixedAsset IN(&FixedAssetsList)
	|		
	|		GROUP BY
	|			FixedAssetState.FixedAsset,
	|			FixedAssetStateSliceLast.AccrueDepreciationInCurrentMonth) AS DepreciationSignChange
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationSignChange.FixedAsset
	|		LEFT JOIN AccumulationRegister.FixedAssetsOutput.Turnovers(
	|				&BeginOfPeriod,
	|				&EndOfPeriod,
	|				,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS FixedAssetOutputTurnovers
	|		ON ListOfAmortizableFA.FixedAsset = FixedAssetOutputTurnovers.FixedAsset
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	&Period AS Period,
	|	Table.FixedAsset AS FixedAsset,
	|	Table.FixedAssetPresentation AS FixedAssetPresentation,
	|	Table.Code AS Code,
	|	Table.DepreciationClosingBalance AS DepreciationClosingBalance,
	|	Table.BalanceCost AS BalanceCost,
	|	0 AS Cost,
	|	CASE
	|		WHEN CASE
	|				WHEN Table.DepreciationAmount < Table.TotalLeftToWriteOff
	|					THEN Table.DepreciationAmount
	|				ELSE Table.TotalLeftToWriteOff
	|			END > 0
	|			THEN CASE
	|					WHEN Table.DepreciationAmount < Table.TotalLeftToWriteOff
	|						THEN Table.DepreciationAmount
	|					ELSE Table.TotalLeftToWriteOff
	|				END
	|		ELSE 0
	|	END AS Depreciation
	|INTO TableDepreciationCalculation
	|FROM
	|	(SELECT
	|		CASE
	|			WHEN Table.DepreciationAccrualMethod = VALUE(Enum.FixedAssetsDepreciationMethods.Linear)
	|				THEN Table.CostForDepreciationCalculation / CASE
	|						WHEN Table.UsagePeriodForDepreciationCalculation = 0
	|							THEN 1
	|						ELSE Table.UsagePeriodForDepreciationCalculation
	|					END
	|			WHEN Table.DepreciationAccrualMethod = VALUE(Enum.FixedAssetsDepreciationMethods.ProportionallyToProductsVolume)
	|				THEN Table.CostForDepreciationCalculation * Table.OutputVolume / CASE
	|						WHEN Table.AmountOfProductsServicesForDepreciationCalculation = 0
	|							THEN 1
	|						ELSE Table.AmountOfProductsServicesForDepreciationCalculation
	|					END
	|			ELSE 0
	|		END AS DepreciationAmount,
	|		Table.FixedAsset AS FixedAsset,
	|		Table.FixedAssetPresentation AS FixedAssetPresentation,
	|		Table.Code AS Code,
	|		Table.DepreciationClosingBalance AS DepreciationClosingBalance,
	|		Table.BalanceCost AS BalanceCost,
	|		Table.BalanceCost - Table.DepreciationClosingBalance AS TotalLeftToWriteOff
	|	FROM
	|		TemporaryTableForDepreciationCalculation AS Table) AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableForDepreciationCalculation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableFixedAssets.LineNumber AS LineNumber,
	|	TableFixedAssets.FixedAsset AS FixedAsset
	|INTO TableFixedAssets
	|FROM
	|	&TableFixedAssets AS TableFixedAssets
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableFixedAssets.LineNumber AS LineNumber,
	|	TableFixedAssets.FixedAsset AS FixedAsset,
	|	TableDepreciationCalculation.BalanceCost AS Cost,
	|	TableDepreciationCalculation.Depreciation AS MonthlyDepreciation,
	|	TableDepreciationCalculation.DepreciationClosingBalance AS Depreciation,
	|	TableDepreciationCalculation.BalanceCost - TableDepreciationCalculation.DepreciationClosingBalance AS DepreciatedCost
	|FROM
	|	TableFixedAssets AS TableFixedAssets
	|		LEFT JOIN TableDepreciationCalculation AS TableDepreciationCalculation
	|		ON TableFixedAssets.FixedAsset = TableDepreciationCalculation.FixedAsset
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TableFixedAssets
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TableDepreciationCalculation";
	
	CurDate = CurrentDate();
	
	Query.SetParameter("Period", CurDate);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("BegOfYear", BegOfYear(CurDate));
	Query.SetParameter("BeginOfPeriod", BegOfMonth(CurDate));
	Query.SetParameter("EndOfPeriod", EndOfMonth(CurDate));
	Query.SetParameter("FixedAssetsList", FixedAssets.UnloadColumn("FixedAsset"));
	Query.SetParameter("TableFixedAssets", FixedAssets);
	
	QueryResult = Query.ExecuteBatch();
	
	DepreciationTable = QueryResult[4].Unload();
	
	FixedAssets.Load(DepreciationTable);
	
EndProcedure // CalculateDepreciation()

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssets(FillingData)
	
	
	NewRow = FixedAssets.Add();
	
	NewRow.FixedAsset = FillingData;
	
	CalculateDepreciation(FillingData);
	
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

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Preliminary control execution.
	RunPreliminaryControl(Cancel);
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.FixedAssetsWriteOff.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectFixedAssetStatuses(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectManagerial(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Creating control of negative balances.
	Documents.FixedAssetsWriteOff.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	
	// Creating control of negative balances.
	Documents.FixedAssetsWriteOff.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure // UndoPosting()

#EndRegion

#EndIf