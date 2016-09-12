#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Fills in the list of all possible areas for duplicates search.
// 
// Parameters:
//     List - ValueList - A filled in list where you set:
//               Value      - String   - Metadata of object-table full name
//               Presentation - String   - Presentation for a user.
//               Picture      - Picture - Corresponding picture from the platform library.
//               Mark       - Boolean   - Check box of applied rules of duplicates search. 
//                                          Set only if the second parameter equals to True.
//
//     AnalyzeAppliedRules - Boolean - Check box of need to search applied rules of duplicates search.
//
Procedure DuplicateSearchAreas(List, Val AnalyzeAppliedRules = False) Export
	
	List.Clear();
	
	If AnalyzeAppliedRules Then
		ObjectsWithDuplicatesSearch = New Map;
		SearchAndDeleteDuplicatesOverridable.OnDefineObjectsWithDuplicatesSearch(ObjectsWithDuplicatesSearch);
	Else
		ObjectsWithDuplicatesSearch = Undefined;
	EndIf;
	DuplicatesSearchAreasGroup(List, ObjectsWithDuplicatesSearch, AnalyzeAppliedRules, Catalogs,             "Catalog");
	DuplicatesSearchAreasGroup(List, ObjectsWithDuplicatesSearch, AnalyzeAppliedRules, ChartsOfCharacteristicTypes, "ChartOfCharacteristicTypes");
	DuplicatesSearchAreasGroup(List, ObjectsWithDuplicatesSearch, AnalyzeAppliedRules, ChartsOfAccounts,             "ChartOfAccounts");
	DuplicatesSearchAreasGroup(List, ObjectsWithDuplicatesSearch, AnalyzeAppliedRules, ChartsOfCalculationTypes,       "ChartOfCalculationTypes");

EndProcedure

// Define object manager for applied rules call.
// 
// Parameters:
//     DataSearchAreaName - String - Field name (full name of metadata).
//
// Returns:
//     CatalogsManager, ChartsOfCharacteristicTypes.Manager, ChartsOfChartOfAccountssOfCalculationTypes.Manager
//
Function DuplicateSearchAreaManager(Val DataSearchAreaName) Export
	Meta = Metadata.FindByFullName(DataSearchAreaName);
	
	If Metadata.Catalogs.Contains(Meta) Then
		Return Catalogs[Meta.Name];
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(Meta) Then
		Return ChartsOfCharacteristicTypes[Meta.Name];
		
	ElsIf Metadata.ChartsOfAccounts.Contains(Meta) Then
		Return ChartsOfAccounts[Meta.Name];
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(Meta) Then
		Return ChartsOfCalculationTypes[Meta.Name];
		
	EndIf;
		
	Raise StrReplace(
		NStr("en='Unknown type of metadata object ""%1""';ru='Неизвестный тип объекта метаданных ""%1""'"), 
		"%1", DataSearchAreaName
	);
	
EndFunction

// Default parameters for passing to an applied code.
// 
// Parameters:
//     SearchRules - ValueTable - Offered search rules, contains columns.
//         Attribute - String - Attribute name of the search area.
//         Rule  - String - Identifier of comparison rule, Equals or Similar.
//
// Returns:
//     Structure
//
Function AppliedDefaultParameters(Val SearchRules, Val FilterLinker) Export

	DefaultParameters = New Structure;
	DefaultParameters.Insert("SearchRules",        SearchRules);
	DefaultParameters.Insert("ComparisonRestriction", New Array);
	DefaultParameters.Insert("FilterLinker",    FilterLinker);
	DefaultParameters.Insert("ItemsQuantityForComparison", 1000);
	
	Return DefaultParameters;
	
EndFunction

// Handler of the background duplicates search.
//
// Parameters:
//     Parameters       - Structure - Data for analysis.
//     ResultAddress - String    - Address in the temporary storage for saving results.
//
Procedure BackgroundDuplicatesSearch(Val Parameters, Val ResultAddress) Export
	
	// Build linker again using schema and settings.
	ComposerPreFilter = New DataCompositionSettingsComposer;
	
	ComposerPreFilter.Initialize( New DataCompositionAvailableSettingsSource(Parameters.CompositionSchema) );
	ComposerPreFilter.LoadSettings(Parameters.PreSelectionLinkerSettings);
	
	Parameters.Insert("ComposerPreFilter", ComposerPreFilter);
	
	// Convert search rules to values table with index.
	SearchRules = New ValueTable;
	SearchRules.Columns.Add("Attribute", New TypeDescription("String") );
	SearchRules.Columns.Add("Rule",  New TypeDescription("String") );
	SearchRules.Indexes.Add("Attribute");
	
	For Each Rule IN Parameters.SearchRules Do
		FillPropertyValues(SearchRules.Add(), Rule);
	EndDo;
	Parameters.Insert("SearchRules", SearchRules);
	
	Parameters.Insert("CalculateUsagePlaces", True);
	
	// Launch search
	PutToTempStorage(DuplicatesGroups(Parameters), ResultAddress);
EndProcedure

// Processor of the background duplicates deletion.
//
// Parameters:
//     Parameters       - Structure - Data for analysis.
//     ResultAddress - String    - Address in the temporary storage for saving results.
//
Procedure DuplicatesBackgroundDeletetion(Val Parameters, Val ResultAddress) Export
	
	ReplacementParameters = New Structure;
	ReplacementParameters.Insert("RemovalMethod",       Parameters.RemovalMethod);
	ReplacementParameters.Insert("EnableBusinessLogic", True);
	
	ReplaceRefs(Parameters.SubstitutionsPairs, ReplacementParameters, ResultAddress);
	
EndProcedure

// Direct duplicates search.
//
// Parameters:
//     SearchParameters - Structure - Describes search parameters.
//     ReferenceObject - Arbitrary - Object for comparison during the similar items search.
//
// Returns:
//     ValueTable - Implement values tree using Ref
// or Parent, top level - groups, lower - found duplicates.
//
Function DuplicatesGroups(Val SearchParameters, Val ReferenceObject = Undefined) Export
	Var ReturnPortionSize, CalculateUsagePlaces;
	
	// 1. Define parameters taking the applied code into account.
	
	SearchParameters.Property("MaxDuplicatesQuantity", ReturnPortionSize);
	If Not ValueIsFilled(ReturnPortionSize) Then
		// All found
		ReturnPortionSize = 0;
	EndIf;
	
	If Not SearchParameters.Property("CalculateUsagePlaces", CalculateUsagePlaces) Then
		CalculateUsagePlaces = False;
	EndIf;
		
	// For passing to an applied storage.
	AdditionalParameters = Undefined;
	SearchParameters.Property("AdditionalParameters", AdditionalParameters);
	
	// Call an applied code
	UseAppliedRules = SearchParameters.ConsiderAppliedRules AND HasAppliedRulesDuplicateSearchAreas(SearchParameters.DuplicateSearchArea);
	
	ComparisonFieldsOnEquality = "";	// Attributes names used for comparison by quality.
	ComparisonFieldsBySimilarity   = "";	// Attribute names whose comparison will not be clear.
	AdditionalDataFields = "";	// Attributes names, additionally ordered by the applied rules.
	AppliedPortionSize   = 0;	// How many to give to the applied rules for calculation.
	
	If UseAppliedRules Then
		AppliedParameters = AppliedDefaultParameters(SearchParameters.SearchRules, SearchParameters.ComposerPreFilter);
 		
		SearchAreaManager = DuplicateSearchAreaManager(SearchParameters.DuplicateSearchArea);
		SearchAreaManager.DuplicatesSearchParameters(AppliedParameters, AdditionalParameters);
		
		AllAdditionalFields = New Map;
		For Each Restriction IN AppliedParameters.ComparisonRestriction Do
			For Each KeyValue IN New Structure(Restriction.AdditionalFields) Do
				FieldName = KeyValue.Key;
				If AllAdditionalFields[FieldName] = Undefined Then
					AdditionalDataFields = AdditionalDataFields + ", " + FieldName;
					AllAdditionalFields[FieldName] = True;
				EndIf; 
			EndDo;
		EndDo;
		AdditionalDataFields = Mid(AdditionalDataFields, 2);
		
		// How many to give to the applied rules for calculation.
		AppliedPortionSize = AppliedParameters.ItemsQuantityForComparison;
	EndIf;
	
	// Fields lists possibly changed using an applied code.
	For Each String IN SearchParameters.SearchRules Do
		If String.Rule = "Equal" Then
			ComparisonFieldsOnEquality = ComparisonFieldsOnEquality + ", " + String.Attribute;
		ElsIf String.Rule = "Like" Then
			ComparisonFieldsBySimilarity = ComparisonFieldsBySimilarity + ", " + String.Attribute;
		EndIf
	EndDo;
	ComparisonFieldsOnEquality = Mid(ComparisonFieldsOnEquality, 2);
	ComparisonFieldsBySimilarity   = Mid(ComparisonFieldsBySimilarity, 2);
	
	// 2. Design by possibly changed linker of selection conditions.
	Filter = SearchFilterByLinker(SearchParameters.ComposerPreFilter);
	
	TableMetadata = Metadata.FindByFullName(SearchParameters.DuplicateSearchArea);
	Characteristics= New Structure("CodeLength, DescriptionLength, Hierarchical, HierarchyType", 0, 0, False);
	FillPropertyValues(Characteristics, TableMetadata);
	
	HasName = Characteristics.DescriptionLength > 0;
	ThereIsCode          = Characteristics.CodeLength > 0;
	
	If Characteristics.Hierarchical AND Characteristics.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
		// Do not search among droups
		If IsBlankString(Filter.Text) Then
			Filter.Text = "NOT IsFolder";
		Else
			Filter.Text = "NOT IsFolder AND (" + Filter.Text + ")";
		EndIf;
	EndIf;
	
	// Additional fields may intersect other, they need to have aliases.
	TableOfCandidates = New ValueTable;
	CandidatesColumns = TableOfCandidates.Columns;
	CandidatesColumns.Add("Ref1");
	CandidatesColumns.Add("Fields1");
	CandidatesColumns.Add("Ref2");
	CandidatesColumns.Add("Fields2");
	CandidatesColumns.Add("IsDuplicates", New TypeDescription("Boolean"));
	TableOfCandidates.Indexes.Add("IsDuplicates");
	
	AdditionalFieldsDecryption = New Map;
	AdditionalAliases  = "";
	SequenceNumber = 0;
	For Each KeyValue IN New Structure(AdditionalDataFields) Do
		FieldName   = KeyValue.Key;
		Alias = "add" + Format(SequenceNumber, "NZ=; NG=") + "_" + FieldName;
		AdditionalFieldsDecryption.Insert(Alias, FieldName);
		
		AdditionalAliases = AdditionalAliases + "," + FieldName + " AS " + Alias;
		SequenceNumber = SequenceNumber + 1;
	EndDo;
	AdditionalAliases = Mid(AdditionalAliases, 2);
	
	// Same fields will be compared according to the equality.
	IdentityFieldsStructure = New Structure(ComparisonFieldsOnEquality);
	IdentityCondition  = "";
	For Each KeyValue IN IdentityFieldsStructure Do
		FieldName = KeyValue.Key;
		IdentityCondition = IdentityCondition + "AND " + FieldName + " = &" + FieldName + " ";
	EndDo;
	IdentityCondition = Mid(IdentityCondition, 2);
	
	SimilarityFieldsStructure = New Structure(ComparisonFieldsBySimilarity);
	
	QueryCommonPart = "
		|SELECT 
		|	" + ?(IsBlankString(ComparisonFieldsOnEquality), "", ComparisonFieldsOnEquality + "," ) + "
		|	" + ?(IsBlankString(ComparisonFieldsBySimilarity),   "", ComparisonFieldsBySimilarity   + "," ) + "
		|	" + ?(IsBlankString(AdditionalAliases), "", AdditionalAliases + "," ) + "
		|	Refs
		|";
	If Not IdentityFieldsStructure.Property("Code") AND Not SimilarityFieldsStructure.Property("Code") Then
		QueryCommonPart = QueryCommonPart + "," + ?(ThereIsCode, "Code", "UNDEFINED") + " AS Code";
	EndIf;
	If Not IdentityFieldsStructure.Property("Description") AND Not SimilarityFieldsStructure.Property("Description") Then
		QueryCommonPart = QueryCommonPart + "," + ?(HasName, "Description", "UNDEFINED") + " AS Name";
	EndIf;
	QueryCommonPart = QueryCommonPart + "
		|FROM
		|	" + SearchParameters.DuplicateSearchArea + "
		|";
	
	// Main query - search candidates-duplicates for each item.
	If ReferenceObject = Undefined Then
		
		Query = New Query(QueryCommonPart + "
			|" + ?(IsBlankString(Filter.Text), "", "WHERE " + Filter.Text) + "
			|ORDER
			|	BY Ref
			|");
	Else
		
		TextPreselection = "
			|SELECT * INTO ReferenceObject IN &_ReferenceObject AS Prototype
			|;////////////////////////////////////////////////////////////////////
			|SELECT 
			|	" + ?(IsBlankString(ComparisonFieldsOnEquality), "", ComparisonFieldsOnEquality + "," ) + "
			|	" + ?(IsBlankString(ComparisonFieldsBySimilarity),   "", ComparisonFieldsBySimilarity   + "," ) + "
			|	" + ?(IsBlankString(AdditionalAliases), "", AdditionalAliases + "," ) + "
			|	VALUE(" + SearchParameters.DuplicateSearchArea + "EmptyRef) AS Ref
			|";
		If Not IdentityFieldsStructure.Property("Code") AND Not SimilarityFieldsStructure.Property("Code") Then
			TextPreselection = TextPreselection + "," + ?(ThereIsCode, "Code", "UNDEFINED") + " AS Code";
		EndIf;
		If Not IdentityFieldsStructure.Property("Description") AND Not SimilarityFieldsStructure.Property("Description") Then
			TextPreselection = TextPreselection + "," + ?(HasName, "Description", "UNDEFINED") + " AS Name";
		EndIf;
		TextPreselection = TextPreselection + "
			|FROM
			|	ReferenceObject
			|";
		
		Query = New Query(TextPreselection + "
			|" + ?(IsBlankString(Filter.Text), "", "WHERE " + Filter.Text) + "
			|");
			
		Query.SetParameter("_ReferenceObject", ObjectToValuesTable(ReferenceObject));
	EndIf;
		
		
	// Query for the candidates search to the current reference. 
	// Comparison of references and ordering in the previous query help to avoid repeated comparisons.
	CandidatesQuery = New Query(QueryCommonPart + "
		|WHERE
		|	Ref > &_SourceRef
		|	" + ?(IsBlankString(Filter.Text), "", "And (" + Filter.Text + ")") + "
		|	" + ?(IsBlankString(IdentityCondition), "", "And (" + IdentityCondition+ ")") + "
		|");
		
	For Each KeyValue IN Filter.Parameters Do
		ParameterName      = KeyValue.Key;
		ParameterValue = KeyValue.Value;
		Query.SetParameter(ParameterName, ParameterValue);
		CandidatesQuery.SetParameter(ParameterName, ParameterValue);
	EndDo;
	
	// Result and cycle of the search
	DuplicatesTable = New ValueTable;
	ResultColumns = DuplicatesTable.Columns;
	ResultColumns.Add("Ref");
	For Each KeyValue IN IdentityFieldsStructure Do
		ResultColumns.Add(KeyValue.Key);
	EndDo;
	For Each KeyValue IN SimilarityFieldsStructure Do
		ResultColumns.Add(KeyValue.Key);
	EndDo;
	If ResultColumns.Find("Code") = Undefined Then
		ResultColumns.Add("Code");
	EndIf;
	If ResultColumns.Find("Description") = Undefined Then
		ResultColumns.Add("Description");
	EndIf;
	ResultColumns.Add("Parent");
	
	DuplicatesTable.Indexes.Add("Ref");
	DuplicatesTable.Indexes.Add("Parent");
	DuplicatesTable.Indexes.Add("Ref, Parent");
	
	Result = New Structure("DuplicatesTable, ErrorDescription", DuplicatesTable);
	
	FieldsStructure = New Structure;
	FieldsStructure.Insert("AdditionalFieldsDecryption", AdditionalFieldsDecryption);
	FieldsStructure.Insert("IdentityFieldsStructure",     IdentityFieldsStructure);
	FieldsStructure.Insert("SimilarityFieldsStructure",          SimilarityFieldsStructure);
	FieldsStructure.Insert("IdentityFieldsList",        ComparisonFieldsOnEquality);
	FieldsStructure.Insert("FieldsListSimilarities",             ComparisonFieldsBySimilarity);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		// Filter similar
		CandidatesQuery.SetParameter("_SourceRef", Selection.Ref);
		For Each KeyValue IN IdentityFieldsStructure Do
			FieldName = KeyValue.Key;
			CandidatesQuery.SetParameter(FieldName, Selection[FieldName]);
		EndDo;
		
		CandidatesSelection = CandidatesQuery.Execute().Select();
		While CandidatesSelection.Next() Do
			
			// If it was considered duplicate in another group, ignore it.
			If DuplicatesTable.Find(CandidatesSelection.Ref, "Ref") <> Undefined Then
				Continue;
			EndIf;
			
			NotDuplicates = False;
			
			// Play the similarity rules for rows.
			For Each KeyValue IN SimilarityFieldsStructure Do
				FieldName = KeyValue.Key;
				If Not RowsSimilar(Selection[FieldName], CandidatesSelection[FieldName]) Then
					NotDuplicates = True;
					Break;
				EndIf;
			EndDo;
			If NotDuplicates Then
				Continue;
			EndIf;
			
			If UseAppliedRules Then
				// Fill in the table for the applied rules, call them if it is time.
				AddCandidatesRow(TableOfCandidates, Selection, CandidatesSelection, FieldsStructure);
				If TableOfCandidates.Count() = AppliedPortionSize Then
					AddDuplicatesByAppliedRules(DuplicatesTable, SearchAreaManager, Selection, TableOfCandidates, FieldsStructure, AdditionalParameters);
					TableOfCandidates.Clear();
				EndIf;
			Else
				AddDuplicateToResult(DuplicatesTable, Selection, CandidatesSelection, FieldsStructure);
			EndIf;
			
		EndDo;
		
		// Process the rest of the table for applied rules.
		If UseAppliedRules Then
			AddDuplicatesByAppliedRules(DuplicatesTable, SearchAreaManager, Selection, TableOfCandidates, FieldsStructure, AdditionalParameters);
			TableOfCandidates.Clear();
		EndIf;
		
		// Group analysis is complete, see the quality. Do not give a lot to client.
		If ReturnPortionSize > 0 AND (DuplicatesTable.Count() > ReturnPortionSize) Then
			// Rollback the last group.
			For Each String IN DuplicatesTable.FindRows( New Structure("Parent ", Selection.Ref) ) Do
				DuplicatesTable.Delete(String);
			EndDo;
			For Each String IN DuplicatesTable.FindRows( New Structure("Ref", Selection.Ref) ) Do
				DuplicatesTable.Delete(String);
			EndDo;
			// If it was the last group, tell about the error.
			If DuplicatesTable.Count() = 0 Then
				Result.ErrorDescription = NStr("en='Too many items are found, not all duplicates groups are defined.';ru='Найдено слишком много элементов, определены не все группы дублей.'");
			Else
				Result.ErrorDescription = NStr("en='Too many items are found. Specify criteria of duplicates search.';ru='Найдено слишком много элементов. Уточните критерии поиска дублей.'");
			EndIf;
			Break;
		EndIf;
		
	EndDo;
	
	If Result.ErrorDescription <> Undefined Then
		Return Result;
	EndIf;
	
	// Usage places calculation
	If CalculateUsagePlaces Then
		RefsSet = New Array;
		For Each DuplicatesRow IN DuplicatesTable Do
			If ValueIsFilled(DuplicatesRow.Ref) Then
				RefsSet.Add(DuplicatesRow.Ref);
			EndIf;
		EndDo;
		
		UsagePlaces = RefsUsagePlaces(RefsSet);
		UsagePlaces = UsagePlaces.Copy(
			UsagePlaces.FindRows(New Structure("AuxiliaryData", False))
		);
		UsagePlaces.Indexes.Add("Ref");
		
		Result.Insert("UsagePlaces", UsagePlaces);
	EndIf;
	
	Return Result;
EndFunction

// Define the presence of the object applied rules.
//
// Parameters:
//     AreaManager - CatalogManager - Manager of a checked object.
//
// Returns:
//     Boolean - True if applied rules are defined.
//
Function HasAppliedRulesDuplicateSearchAreas(Val ObjectName) Export
	
	ObjectList = New Map;
	SearchAndDeleteDuplicatesOverridable.OnDefineObjectsWithDuplicatesSearch(ObjectList);
	
	ObjectInformation = ObjectList[ObjectName];
	Return ObjectInformation <> Undefined AND (ObjectInformation = "" Or Find(ObjectInformation, "DuplicatesSearchParameters") > 0);
	
EndFunction

// Interface for execution of processor commands.
Procedure RunCommand(ExecuteParameters, ResultAddress) Export
	
	If ExecuteParameters.ProcedureName = "BackgroundDuplicatesSearch" Then
		
		BackgroundDuplicatesSearch(ExecuteParameters, ResultAddress);
		
	ElsIf ExecuteParameters.ProcedureName = "DuplicatesBackgroundDeletetion" Then
		
		DuplicatesBackgroundDeletetion(ExecuteParameters, ResultAddress);
		
	Else
		
		Raise NStr("en='Search and delete duplicates: %1 command is not supported.';ru='Поиск и удаление дублей: Команда ""%1"" не поддерживается.'");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Convert object to table for placing it to query.
Function ObjectToValuesTable(Val ObjectData)
	Result = New ValueTable;
	DataRow = Result.Add();
	
	MetaObject = ObjectData.Metadata();
	
	For Each MetaAttribute IN MetaObject.StandardAttributes  Do
		Name = MetaAttribute.Name;
		Result.Columns.Add(Name, MetaAttribute.Type);
		DataRow[Name] = ObjectData[Name];
	EndDo;
	
	For Each MetaAttribute IN MetaObject.Attributes Do
		Name = MetaAttribute.Name;
		Result.Columns.Add(Name, MetaAttribute.Type);
		DataRow[Name] = ObjectData[Name];
	EndDo;
	
	Return Result;
EndFunction

// Additional candidates analysis in duplicates using an applied method.
//
Procedure AddDuplicatesByAppliedRules(ResultTreeRows, Val SearchAreaManager, Val MainData, Val TableOfCandidates, Val FieldsStructure, Val AdditionalParameters)
	If TableOfCandidates.Count() = 0 Then
		Return;
	EndIf;
	
	SearchAreaManager.OnSearchDuplicates(TableOfCandidates, AdditionalParameters);
	
	Data1 = New Structure;
	Data2 = New Structure;
	
	For Each CandidatesPair IN TableOfCandidates.FindRows(New Structure("IsDuplicates", True)) Do
		Data1.Insert("Ref",       CandidatesPair.Ref1);
		Data1.Insert("Code",          CandidatesPair.Fields1.Code);
		Data1.Insert("Description", CandidatesPair.Fields1.Description);
		
		Data2.Insert("Ref",       CandidatesPair.Ref2);
		Data2.Insert("Code",          CandidatesPair.Fields2.Code);
		Data2.Insert("Description", CandidatesPair.Fields2.Description);
		
		For Each KeyValue IN FieldsStructure.IdentityFieldsStructure Do
			FieldName = KeyValue.Key;
			Data1.Insert(FieldName, CandidatesPair.Fields1[FieldName]);
			Data2.Insert(FieldName, CandidatesPair.Fields2[FieldName]);
		EndDo;
		For Each KeyValue IN FieldsStructure.SimilarityFieldsStructure Do
			FieldName = KeyValue.Key;
			Data1.Insert(FieldName, CandidatesPair.Fields1[FieldName]);
			Data2.Insert(FieldName, CandidatesPair.Fields2[FieldName]);
		EndDo;
		
		AddDuplicateToResult(ResultTreeRows, Data1, Data2, FieldsStructure);
	EndDo;
EndProcedure

// Add a row to candidates table for an applied method.
//
Function AddCandidatesRow(TableOfCandidates, Val MainItemData, Val CandidateData, Val FieldsStructure)
	
	String = TableOfCandidates.Add();
	String.IsDuplicates = False;
	String.Ref1  = MainItemData.Ref;
	String.Ref2  = CandidateData.Ref;
	
	String.Fields1 = New Structure("Code, description", MainItemData.Code, MainItemData.Description);
	String.Fields2 = New Structure("Code, description", CandidateData.Code, CandidateData.Description);
	
	For Each KeyValue IN FieldsStructure.IdentityFieldsStructure Do
		FieldName = KeyValue.Key;
		String.Fields1.Insert(FieldName, MainItemData[FieldName]);
		String.Fields2.Insert(FieldName, CandidateData[FieldName]);
	EndDo;
	
	For Each KeyValue IN FieldsStructure.SimilarityFieldsStructure Do
		FieldName = KeyValue.Key;
		String.Fields1.Insert(FieldName, MainItemData[FieldName]);
		String.Fields2.Insert(FieldName, CandidateData[FieldName]);
	EndDo;
	
	For Each KeyValue IN FieldsStructure.AdditionalFieldsDecryption Do
		ColumnName = KeyValue.Value;
		FieldName    = KeyValue.Key;
		
		String.Fields1.Insert(ColumnName, MainItemData[FieldName]);
		String.Fields2.Insert(ColumnName, CandidateData[FieldName]);
	EndDo;
	
	Return String;
EndFunction

// Add a found result to the results tree.
//
Procedure AddDuplicateToResult(Result, Val MainItemData, Val CandidateData, Val FieldsStructure)
	
	GroupFilter = New Structure("Ref, Parent", MainItemData.Ref);
	DuplicatesGroup = Result.FindRows(GroupFilter);
	
	If DuplicatesGroup.Count() = 0 Then
		DuplicatesGroup = Result.Add();
		FillPropertyValues(DuplicatesGroup, GroupFilter);
		
		DuplicatesRow = Result.Add();
		FillPropertyValues(DuplicatesRow, MainItemData, 
			"Ref, Code, Name," + FieldsStructure.IdentityFieldsList + "," + FieldsStructure.FieldsListSimilarities
		);
		
		DuplicatesRow.Parent = DuplicatesGroup.Ref;
	Else
		DuplicatesGroup = DuplicatesGroup[0];
	EndIf;
	
	DuplicatesRow = Result.Add();
	FillPropertyValues(DuplicatesRow, CandidateData, 
		"Ref, Code, Name," + FieldsStructure.IdentityFieldsList + "," + FieldsStructure.FieldsListSimilarities
	);
	
	DuplicatesRow.Parent = DuplicatesGroup.Ref;
EndProcedure

// Generate query condition text and parameters set.
//
Function SearchFilterByLinker(Val FilterLinker)
	Result = New Structure("Parameters", New Structure);
	
	GroupsStack = New Array;
	GroupsStack.Insert(0, DataCompositionFilterItemsGroupType.AndGroup);
	
	Result.Insert("Text", LinkerGroupFilterText(FilterLinker.Settings.Filter.Items, GroupsStack, Result.Parameters) );
	Result.Insert("Description", String(FilterLinker.Settings.Filter) );
	
	Return Result;
EndFunction

// Generate text for using in query, fill in parameters.
//
Function LinkerGroupFilterText(Val GroupItems, GroupsStack, LinkerParameters)
	ItemCount = GroupItems.Count();
	
	If ItemCount = 0 Then
		// Empty conditions group
		Return "";
	EndIf;
	
	CurrentGroupType = GroupsStack[0];
	
	Text = "";
	ComparisonToken = LayoutFilterGroupComparisonToken(CurrentGroupType);
	
	For Each Item IN GroupItems Do
		
		If TypeOf(Item) = Type("DataCompositionFilterItem") Then
			// Single item
			ParameterName  = "FilterParameter" + Format(LinkerParameters.Count(), "NZ=; NG=");
			
			SearchBySimilarity = False;
			Text = Text + " " + ComparisonToken + " " + LayoutFilterGroupComparisonText(Item.LeftValue, Item.ComparisonType, "&" + ParameterName, SearchBySimilarity);
			
			If SearchBySimilarity Then
				LinkerParameters.Insert(ParameterName, "%" + Item.RightValue + "%");
			Else
				LinkerParameters.Insert(ParameterName, Item.RightValue);
			EndIf;
		Else
			// Inserted group
			GroupsStack.Insert(0, Item.GroupType);
			Text = Text + " " + ComparisonToken + " " + LinkerGroupFilterText(Item.Items, GroupsStack, LinkerParameters);
			GroupsStack.Delete(0);
		EndIf;
		
	EndDo;
	
	Text = Mid(Text, 2 + StrLen(ComparisonToken));
	Return LayoutSelectionGroupOpeningToken(CurrentGroupType) 
		+ "(" + Text + ")";
EndFunction

// Token of items comparison inside the group.
//
Function LayoutFilterGroupComparisonToken(Val GroupType)
	
	If GroupType = DataCompositionFilterItemsGroupType.AndGroup Then 
		Return "AND";
		
	ElsIf GroupType = DataCompositionFilterItemsGroupType.OrGroup Then 
		Return "OR";
		
	ElsIf GroupType = DataCompositionFilterItemsGroupType.NotGroup Then
		Return "AND";
		
	EndIf;
	
	Return "";
EndFunction

// Operation token before group.
//
Function LayoutSelectionGroupOpeningToken(Val GroupType)
	
	If GroupType = DataCompositionFilterItemsGroupType.NotGroup Then
		Return "Not"
	EndIf;
	
	Return "";
EndFunction

// Comparison text of two operands by the comparison kind.
//
Function LayoutFilterGroupComparisonText(Val Field, Val ComparisonType, Val ParameterName, UsedSearchBySimilarity = False)
	
	UsedSearchBySimilarity = False;
	ComparisonFields             = String(Field);
	
	If ComparisonType = DataCompositionComparisonType.Greater Then
		Return ComparisonFields + " > " + ParameterName;
		
	ElsIf ComparisonType = DataCompositionComparisonType.GreaterOrEqual Then
		Return ComparisonFields + " >= " + ParameterName;
		
	ElsIf ComparisonType = DataCompositionComparisonType.InHierarchy Then
		Return ComparisonFields + " IN HIERARCHY (" + ParameterName + ") ";
		
	ElsIf ComparisonType = DataCompositionComparisonType.InList Then
		Return ComparisonFields + " IN (" + ParameterName + ") ";
		
	ElsIf ComparisonType = DataCompositionComparisonType.InListByHierarchy  Then
		Return ComparisonFields + " IN HIERARCHY (" + ParameterName + ") ";
		
	ElsIf ComparisonType = DataCompositionComparisonType.Filled Then
		UsedSearchBySimilarity = True;
		Return ComparisonFields + " Not LIKE """" ";
		
	ElsIf ComparisonType = DataCompositionComparisonType.Less Then
		Return ComparisonFields + " < " + ParameterName;
		
	ElsIf ComparisonType = DataCompositionComparisonType.LessOrEqual Then
		Return ComparisonFields + " <= " + ParameterName;
		
	ElsIf ComparisonType = DataCompositionComparisonType.NotInHierarchy Then
		Return ComparisonFields + " NOT IN HIERARCHY (" + ParameterName + ") ";
		
	ElsIf ComparisonType = DataCompositionComparisonType.NotInList Then
		Return ComparisonFields + " NOT IN (" + ParameterName + ")";
		
	ElsIf ComparisonType = DataCompositionComparisonType.NotInListByHierarchy Then
		Return ComparisonFields + " NOT IN HIERARCHY (" + ParameterName + ") ";
		
	ElsIf ComparisonType = DataCompositionComparisonType.NotFilled Then
		UsedSearchBySimilarity = True;
		Return ComparisonFields + " LIKE """" ";
		
	ElsIf ComparisonType = DataCompositionComparisonType.NotEqual Then
		Return ComparisonFields + " <> " + ParameterName + " ";
		
	ElsIf ComparisonType = DataCompositionComparisonType.NotContains Then
		UsedSearchBySimilarity = True;
		Return ComparisonFields + " NOT LIKE " + ParameterName + " ";
		
	ElsIf ComparisonType = DataCompositionComparisonType.Equal Then
		Return ComparisonFields + " = " + ParameterName;
		
	ElsIf ComparisonType = DataCompositionComparisonType.Contains Then
		UsedSearchBySimilarity = True;
		Return ComparisonFields + " LIKE " + ParameterName + " ";;
		
	EndIf;
	
	Return "";
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Fuzzy comparison of rows

Function RowsSimilar(Val Row1, Val Row2)
	
	If Max(StrLen(Row1), StrLen(Row2)) > 10 Then
		Return RowsSimilarityPercent(Row1, Row2) >= 90;
	Else
		Return RowsSimilarityPercent(Row1, Row2) >= 80;
	EndIf;
	
EndFunction

// Returns the similarity percent: 0 - not like, 100 - complete match for rows.
//
Function RowsSimilarityPercent(Val Row1, Val Row2) Export
	If Row1 = Row2 Then
		Return 100;
	EndIf;
	
	AllWords = New Map;
	WordsListings(AllWords, Row1, 1);
	WordsListings(AllWords, Row2, 2);
	
	// Only words
	Sorter1 = New ValueList;
	Sorter2 = New ValueList;
	For Each KeyValue IN AllWords Do
		If KeyValue.Value = 1 Then
			Sorter1.Add(KeyValue.Key);
		ElsIf KeyValue.Value = 2 Then
			Sorter2.Add(KeyValue.Key);
		EndIf;
	EndDo;
	
	FirstRow = WordsFromList(Sorter1);
	SecondRow = WordsFromList(Sorter2);
	If FirstRow = SecondRow Then 
		Return 100;
	EndIf;
	
	Metric = EditingMetric(FirstRow, SecondRow);
	
	Return 100 - Metric * 100 / Max(StrLen(Row1), StrLen(Row2))
EndFunction

Procedure WordsListings(Result, Val SourceLine, Val Delta)
	
	WorkingRow = TrimAll(SourceLine);
	While True Do
		Position = Find(WorkingRow, " ");
		If Position = 0 Then 
			Break;
		EndIf;
		
		CurrentRow = Left(WorkingRow, Position - 1);
		If Not IsBlankString(CurrentRow) Then
			Value = Result[CurrentRow];
			If Value = Undefined Then
				Value = 0;
			EndIf;
			Result.Insert(CurrentRow, Value + Delta);
		EndIf;
		
		WorkingRow = Mid(WorkingRow, Position + 1);
	EndDo;
	
	If Not IsBlankString(WorkingRow) Then
		Value = Result[WorkingRow];
		If Value = Undefined Then
			Value = 0;
		EndIf;
		Result.Insert(WorkingRow, Value + Delta);
	EndIf;
	
EndProcedure

Function WordsFromList(Val WordsList)
	Result = "";
	
	WordsList.SortByValue();
	For Each Item IN WordsList Do
		Result = Result + " " + Item.Value;
	EndDo;
	
	Return Mid(Result, 2);
EndFunction

Function EditingMetric(Val Row1, Val Row2)
	If Row1 = Row2 Then
		Return 0;
	EndIf;
	
	Length1 = StrLen(Row1);
	Length2 = StrLen(Row2);
	
	If Length1 = 0 Then
		If Length2 = 0 Then
			Return 0;
		EndIf;
		Return Length2;
		
	ElsIf Length2 = "" Then
		Return Length1;
		
	EndIf;
	
	// Initialization
	Ratios = New Array(Length1 + 1, Length2 + 1);
	For Position1 = 0 To Length1 Do
		Ratios[Position1][0] = Position1;
	EndDo;
	For Position2 = 0 To Length2 Do
		Ratios[0][Position2] = Position2
	EndDo;
	
	// Calculation
	For Position1 = 1 To Length1 Do
		PrevPosition1 = Position1 - 1;
		Char1      = Mid(Row1, Position1, 1);
		
		For Position2 = 1 To Length2 Do
			PrevPosition2 = Position2 - 1;
			Char2      = Mid(Row2, Position2, 1);
			
			Cost = ?(Char1 = Char2, 0, 1); // Substitution cost
			
			Ratios[Position1][Position2] = min(
				Ratios[PrevPosition1][Position2]     + 1,	// Deletion cost,
				Ratios[Position1]    [PrevPosition2] + 1,	// Insertion cost,
				Ratios[PrevPosition1][PrevPosition2] + Cost
			);
			
			If Position1 > 1 AND Position2 > 1 AND Char1 = Mid(Row2, PrevPosition2, 1) AND Mid(Row1, PrevPosition1, 1) = Char2 Then
				Ratios[Position1][Position2] = min(
					Ratios[Position1][Position2],
					Ratios[Position1 - 2][Position2 - 2] + Cost	// Replacement cost
				);
			EndIf;
			
		EndDo;
	EndDo;
	
	Return Ratios[Length1][Length2];
EndFunction

Procedure DuplicatesSearchAreasGroup(Result, ObjectsWithDuplicatesSearch, Val AnalyzeAppliedRules, Val GroupManager, Val Icon)
	
	For Each Item IN GroupManager Do
		MetadataObject = Metadata.FindByType(TypeOf(Item));
		If Not AccessRight("Read", MetadataObject) Then
			// No access, do not output to list.
			Continue;
		EndIf;
		
		DescriptionFull = MetadataObject.FullName();
		If AnalyzeAppliedRules Then
			ObjectInformation = ObjectsWithDuplicatesSearch[DescriptionFull];
			HasAppliedRules = ObjectInformation <> Undefined AND 
				(ObjectInformation = "" Or Find(ObjectInformation, "DuplicatesSearchParameters") > 0);
		Else
			HasAppliedRules = False;
		EndIf;
		
		Result.Add(DescriptionFull, String(MetadataObject), HasAppliedRules, PictureLib[Icon]);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For an offline work.

// [CommonUse.UsagePlaces]
Function RefsUsagePlaces(Val RefsSet, Val ResultAddress = "")
	
	Return CommonUse.UsagePlaces(RefsSet, ResultAddress);
	
EndFunction

// [CommonUse.ReplaceRefs]
Function ReplaceRefs(Val SubstitutionsPairs, Val Parameters = Undefined, Val ResultAddress = "")
	
	Result = CommonUse.ReplaceRefs(SubstitutionsPairs, Parameters);
	If ResultAddress <> "" Then
		PutToTempStorage(Result, ResultAddress);
	EndIf;	
EndFunction

#EndRegion

#EndIf