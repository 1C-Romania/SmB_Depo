////////////////////////////////////////////////////////////////////////////////
// The Search and delete duplicates subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// Search for duplicates for specified value.
//
// Parameters:
//     SearchArea - String - Name of the data table (metadata full name) of the search field.
//                              For example, Catalog.ProductsAndServices. Search in the
// catalogs, characteristics kinds plans, calculations kinds, accounts plans is supported.
//
//     Item - Arbitrary - object with item data, for which duplicates are searched
//
//     AdditionalParameters - Arbitrary - Parameter for transfer into the manager events handlers.
//
// Returns:
//     ValueTable - contains rows with duplicate descriptions.
// 
Function FindItemDuplicates(Val SearchArea, Val ReferenceObject, Val AdditionalParameters) Export
	
	DuplicatesSearchParameters = New Structure;
	DuplicatesSearchParameters.Insert("ComposerPreFilter");
	DuplicatesSearchParameters.Insert("DuplicateSearchArea", SearchArea);
	DuplicatesSearchParameters.Insert("ConsiderAppliedRules", True);
	
	// From parameters
	DuplicatesSearchParameters.Insert("SearchRules", New ValueTable);
	DuplicatesSearchParameters.SearchRules.Columns.Add("Attribute", New TypeDescription("String"));
	DuplicatesSearchParameters.SearchRules.Columns.Add("Rule",  New TypeDescription("String"));
	
	// See Processing.SearchAndDeleteDuplicates
	DuplicatesSearchParameters.ComposerPreFilter = New DataCompositionSettingsComposer;
	MetaArea = Metadata.FindByFullName(SearchArea);
	AvailableSelectionAttributes = AvailableMetaNamesSelectionAttributes(MetaArea.StandardAttributes);
	AvailableSelectionAttributes = ?(IsBlankString(AvailableSelectionAttributes), ",", AvailableSelectionAttributes)
		+ AvailableMetaNamesSelectionAttributes(MetaArea.Attributes);
	
	CompositionSchema = New DataCompositionSchema;
	DataSource = CompositionSchema.DataSources.Add();
	DataSource.DataSourceType = "Local";
	
	DataSet = CompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Query = "SELECT " + Mid(AvailableSelectionAttributes, 2) + " IN " + SearchArea;
	DataSet.AutoFillAvailableFields = True;
	
	DuplicatesSearchParameters.ComposerPreFilter.Initialize( New DataCompositionAvailableSettingsSource(CompositionSchema) );
	
	// Call application code
	SearchProcessing = DataProcessors.SearchAndDeleteDuplicates.Create();
	
	UseAppliedRules = SearchProcessing.HasAppliedRulesDuplicateSearchAreas(SearchArea);
	If UseAppliedRules Then
		AppliedParameters = New Structure;
		AppliedParameters.Insert("SearchRules",        DuplicatesSearchParameters.SearchRules);
		AppliedParameters.Insert("FilterLinker",    DuplicatesSearchParameters.ComposerPreFilter);
		AppliedParameters.Insert("ComparisonRestriction", New Array);
		AppliedParameters.Insert("ItemsQuantityForComparison", 1500);
		
		SearchAreaManager = SearchProcessing.DuplicateSearchAreaManager(SearchArea);
		SearchAreaManager.DuplicatesSearchParameters(AppliedParameters, AdditionalParameters);
		
		DuplicatesSearchParameters.Insert("AdditionalParameters", AdditionalParameters);
	EndIf;
	
	DuplicatesGroups = SearchProcessing.DuplicatesGroups(DuplicatesSearchParameters, ReferenceObject);
	Result = DuplicatesGroups.DuplicatesTable;
	
	// There is exactly one group, return the required items.
	For Each String IN Result.FindRows(New Structure("Parent", Undefined)) Do
		Result.Delete(String);
	EndDo;
	EmptyRef = SearchAreaManager.EmptyRef();
	For Each String IN Result.FindRows(New Structure("Ref", EmptyRef)) Do
		Result.Delete(String);
	EndDo;
	
	Return Result; 
EndFunction

#EndRegion

#Region ServiceApplicationInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ServerHandlers["StandardSubsystems.ReportsVariants\OnConfiguringOptionsReports"].Add(
			"SearchAndDeleteDuplicates");
	EndIf;
	
EndProcedure

Function CheckItemsReplacePossibilityRow(SubstitutionsPairs, ReplacementParameters) Export
	
	Result = "";
	Errors = CheckReplacementElementsPossibility(SubstitutionsPairs, ReplacementParameters);
	For Each KeyValue IN Errors Do
		Result = Result + Chars.LF + KeyValue.Value;
	EndDo;
	Return TrimAll(Result);
	
EndFunction

Function CheckReplacementElementsPossibility(SubstitutionsPairs, ReplacementParameters) Export
	
	If SubstitutionsPairs.Count() = 0 Then
		Return New Map;
	EndIf;
	
	For Each Item IN SubstitutionsPairs Do
		FirstItem = Item.Key;
		Break;
	EndDo;
	
	ManagerModule = CommonUse.ObjectManagerByRef(FirstItem);
	
	ObjectList = New Map;
	SearchAndDeleteDuplicatesOverridable.OnDefineObjectsWithDuplicatesSearch(ObjectList);
	ObjectInformation = ObjectList[FirstItem.Metadata().FullName()];
	
	If ObjectInformation <> Undefined AND (ObjectInformation = "" Or Find(ObjectInformation, "ItemsReplacePossibility") > 0) Then
		Return ManagerModule.ItemsReplacePossibility(SubstitutionsPairs, ReplacementParameters);
	EndIf;
	
	Return New Map;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Contains the settings of reports variants placement in reports panel.
//
// Parameters:
//   Settings - Collection - Used for the description of reports
//       settings and options, see description to ReportsVariants.ConfigurationReportVariantsSetupTree().
//
// Description:
//  See ReportsVariantsOverride.SetupReportsVariants().
//
Procedure OnConfiguringOptionsReports(Settings) Export
	ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
	ModuleReportsVariants.SetReportInManagerModule(Settings, Metadata.Reports.RefsUsagePlaces);
EndProcedure

// See Processing.SearchAndDeleteDuplicates
Function AvailableMetaNamesSelectionAttributes(Val MetaCollection)
	Result = "";
	StorageType = Type("ValueStorage");
	
	For Each MetaAttribute IN MetaCollection Do
		IsStorage = MetaAttribute.Type.ContainsType(StorageType);
		If Not IsStorage Then
			Result = Result + "," + MetaAttribute.Name;
		EndIf
	EndDo;
	
	Return Result;
EndFunction

Procedure DefineUsagePlacess(Val RefsSet, Val ResultAddress) Export
	
	SearchTable = CommonUse.UsagePlaces(RefsSet);
	
	Filter = New Structure("AuxiliaryData", False);
	ActualRows = SearchTable.FindRows(Filter);
	
	Result = SearchTable.Copy(ActualRows, "Ref");
	Result.Columns.Add("Occurrences", New TypeDescription("Number"));
	Result.FillValues(1, "Occurrences");
	
	Result.GroupBy("Ref", "Occurrences");
	For Each Refs IN RefsSet Do
		If Result.Find(Refs, "Ref") = Undefined Then
			Result.Add().Ref = Refs;
		EndIf;
	EndDo;
	
	PutToTempStorage(Result, ResultAddress);
EndProcedure

// Replaces references in all data. 
//
// Parameters:
//
//     ReplacementParameters - Structure - with the ReplacePairs and Parameters
// properties that correspond to the same CommonUse.ReplaceReferences parameters.
//     ResultAddress - String - address of a temporary storage where exchange result will be stored - ValueTable:
//       * Ref - AnyRef - Reference that was replaced.
//       * ErrorObject - Arbitrary - Object - reason for error.
//       * ObjectErrorPresentation - String - String presentation of error object.
//       * ErrorType - String - Error type marker. Possible variants:
//                              LockError  - during reference processing some objects
//                              were locked DataChanged    - during processing the data was changed
//                              by another user WriteError      - unable to
//                              write the UnknownData object - during the processing the data
//                                                    was found that was not planned to
//                              be analysed, replacement was not implemented ReplacementDenied   - the ItemsReplacePossibility method returned a denial.
//       * ErrorText - String - Detail error description.
//
Procedure ReplaceRefs(ReplacementParameters, Val ResultAddress) Export
	
	Result = CommonUse.ReplaceRefs(ReplacementParameters.SubstitutionsPairs, ReplacementParameters.Parameters);
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Conditional design.

// Description of the instruction to add items of conditional design.
Function ConditionalDesignInstruction() Export
	Return New Structure("Filters, Design, Fields", New Map, New Map, "");
EndFunction

// Adds an item of conditional design according to description in the instruction.
Function AddConditionalAppearanceItem(Form, ConditionalDesignInstruction) Export
	DCConditionalAppearanceItem = Form.ConditionalAppearance.Items.Add();
	DCConditionalAppearanceItem.Use = True;
	
	For Each KeyAndValue IN ConditionalDesignInstruction.Filters Do
		DCFilterItem = DCConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		DCFilterItem.LeftValue = New DataCompositionField(KeyAndValue.Key);
		Settings = KeyAndValue.Value;
		Type = TypeOf(Settings);
		If Type = Type("Structure") Then
			DCFilterItem.ComparisonType = DataCompositionComparisonType[Settings.Kind];
			DCFilterItem.RightValue = Settings.Value;
		ElsIf Type = Type("Array") Then
			DCFilterItem.ComparisonType = DataCompositionComparisonType.InList;
			DCFilterItem.RightValue = Settings;
		ElsIf Type = Type("DataCompositionComparisonType") Then
			DCFilterItem.ComparisonType = Settings;
		Else
			DCFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			DCFilterItem.RightValue = Settings;
		EndIf;
		DCFilterItem.Application = DataCompositionFilterApplicationType.Items;
	EndDo;
	
	For Each KeyAndValue IN ConditionalDesignInstruction.Design Do
		DCConditionalAppearanceItem.Appearance.SetParameterValue(
			New DataCompositionParameter(KeyAndValue.Key),
			KeyAndValue.Value);
	EndDo;
	
	Fields = ConditionalDesignInstruction.Fields;
	If TypeOf(Fields) = Type("String") Then
		Fields = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Fields, ",", True, True);
	EndIf;
	For Each Field IN Fields Do
		DCField = DCConditionalAppearanceItem.Fields.Items.Add();
		DCField.Use = True;
		DCField.Field = New DataCompositionField(Field);
	EndDo;
	
	Return DCConditionalAppearanceItem;
EndFunction

#EndRegion