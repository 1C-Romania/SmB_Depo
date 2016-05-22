﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Executes preliminary control.
//
Procedure RunPreliminaryControl(Cancel)
	
	Query = New Query;
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Query.SetParameter("Period", Date);
	Query.SetParameter("FixedAssetsList", FixedAssets.UnloadColumn("FixedAsset"));
	
	// Check property states.
	Query.Text =
	"SELECT
	|	FixedAssetStateSliceLast.FixedAsset AS FixedAsset
	|FROM
	|	InformationRegister.FixedAssetsStates.SliceLast(&Period, Company = &Company) AS FixedAssetStateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FixedAssetStateSliceLast.FixedAsset AS FixedAsset
	|FROM
	|	InformationRegister.FixedAssetsStates.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND FixedAsset IN (&FixedAssetsList)
	|				AND State = VALUE(Enum.FixedAssetsStates.AcceptedForAccounting)) AS FixedAssetStateSliceLast";
	
	ResultsArray = Query.ExecuteBatch();
	
	ArrayVAStatus = ResultsArray[0].Unload().UnloadColumn("FixedAsset");
	ArrayVAAcceptedForAccounting = ResultsArray[1].Unload().UnloadColumn("FixedAsset");
	
	For Each RowOfFixedAssets IN FixedAssets Do
			
		If ArrayVAStatus.Find(RowOfFixedAssets.FixedAsset) = Undefined Then
			MessageText = NStr("en = 'For property %FixedAssets% specified in string %LineNumber% of list ""Property"" states are not registered.'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset)));
			MessageText = StrReplace(MessageText, "%LineNumber%", String(RowOfFixedAssets.LineNumber));
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"FixedAsset",
				Cancel
			);
		ElsIf ArrayVAAcceptedForAccounting.Find(RowOfFixedAssets.FixedAsset) = Undefined Then
			MessageText = NStr("en = 'For property %FixedAssets% specified in string %LineNumber% of list ""Property"", current state is ""It is struck off the register"".'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset)));
			MessageText = StrReplace(MessageText, "%LineNumber%", String(RowOfFixedAssets.LineNumber));
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

#EndRegion

#Region EventsHandlers

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssets(FillingData)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DepreciationParametersSliceLast.Recorder.Company AS Company
	|FROM
	|	InformationRegister.FixedAssetsParameters.SliceLast(, FixedAsset = &FixedAsset) AS DepreciationParametersSliceLast";
	
	Query.SetParameter("FixedAsset", FillingData);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Company = Selection.Company;
	EndIf;
	
	NewRow = FixedAssets.Add();
	NewRow.FixedAsset = FillingData;
	
EndProcedure // FillByFixedAssets()

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
	
	For Each RowOfFixedAssets IN FixedAssets Do
			
		If RowOfFixedAssets.FixedAsset.DepreciationMethod <> Enums.FixedAssetsDepreciationMethods.ProportionallyToProductsVolume Then
			MessageText = NStr("en = 'For property %FixedAssets% specified in string %LineNumber% of list ""Property"", depreciation method other than ""In proportion to production volume (works)"" is used.'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset)));
			MessageText = StrReplace(MessageText, "%LineNumber%", String(RowOfFixedAssets.LineNumber));
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
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.FixedAssetsOutput.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectFixedAssetsOutput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
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