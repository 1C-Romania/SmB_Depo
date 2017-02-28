#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

//  It returns technical report as tabular document.
//  It is based on the InfobaseNode attribute values, "AdditionalRegistration".
//
//  Parameters:
//      ListOfMetadataNames - Array - it contains strings with the full metadata names for query restriction.
//                                      It can be item collection with the FullMetadataName field.
//  Returns:
//      SpreadsheetDocument - report.
//
Function FormTableDocument(ListOfMetadataNames = Undefined) Export
	
	SetPrivilegedMode(True);
	
	CompositionData = InitializeComposer(ListOfMetadataNames);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionData.CompositionSchema, 
		CompositionData.SettingsComposer.GetSettings(), , , Type("DataCompositionTemplateGenerator"));
	ExternalDataSets = New Structure("NodeContentMetadataTable", CompositionData.NodeContentMetadataTable);
	
	Processor = New DataCompositionProcessor;
	Processor.Initialize(Template, ExternalDataSets,, True);
	
	Output = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	Output.SetDocument(New SpreadsheetDocument);
	
	Return Output.Output(Processor);
	
EndFunction

//  It returns a user report as tabular document.
//  It is based on the InfobaseNode attribute values, "AdditionalRegistration".
//
//  Parameters:
//       FullMetadataName - String - restriction.
//       Presentation       - String - result parameter.
//       SimplifiedMode     - Boolean - layout choice.
//
//  Returns:
//      SpreadsheetDocument - report.
//
Function FormTableDocumentUser(FullMetadataName = "", Presentation = "", SimplifiedMode = False) Export
	SetPrivilegedMode(True);
	
	CompositionData = InitializeComposer();
	
	If IsBlankString(FullMetadataName) Then
		DetailsData = New DataCompositionDetailsData;
		VariantName = "UserDefinedData"; 
	Else
		DetailsData = Undefined;
		VariantName = "DetailsOnObjectType"; 
	EndIf;
	
	// We save filters
	SettingsOfFilters = CompositionData.SettingsComposer.GetSettings();
	
	// Necessary variant
	CompositionData.SettingsComposer.LoadSettings(
		CompositionData.CompositionSchema.SettingVariants[VariantName].Settings);
	
	// We restore filters
	AddCompositionFilterValues(CompositionData.SettingsComposer.Settings.Filter.Items, 
		SettingsOfFilters.Filter.Items);
	
	Parameters = CompositionData.CompositionSchema.Parameters;
	Parameters.Find("GeneratingDate").Value = CurrentSessionDate();
	Parameters.Find("SimplifiedMode").Value  = SimplifiedMode;
	
	Parameters.Find("CommonTextParametersSynchronization").Value = DataExchangeServer.DataSynchronizationRulesDescription(InfobaseNode);
	Parameters.Find("TextAddOptions").Value     = TextAddOptions();
	
	If Not IsBlankString(FullMetadataName) Then
		Parameters.Find("ListPresentation").Value = Presentation;
		
		FilterItems = CompositionData.SettingsComposer.Settings.Filter.Items;
		
		Item = FilterItems.Add(Type("DataCompositionFilterItem"));
		Item.LeftValue  = New DataCompositionField("FullMetadataName");
		Item.Presentation  = Presentation;
		Item.ComparisonType   = DataCompositionComparisonType.Equal;
		Item.RightValue = FullMetadataName;
		Item.Use  = True;
	EndIf;
	
	ComposerSettings = CompositionData.SettingsComposer.GetSettings();
	If SimplifiedMode Then
		// We disable unnecessary fields
		HiddenFields = New Structure("CountByCommonRules, AdvancedRegistration, CountTotal, WillNotBeExported, ExportObjectCanBe");
		For Each Group IN ComposerSettings.Structure Do
			HiddenSelectionFields(Group.Selection.Items, HiddenFields)
		EndDo;
		// And switch a footer with legends.
		GroupCount = ComposerSettings.Structure.Count();
		If GroupCount > 0 Then
			ComposerSettings.Structure[GroupCount - 1].Name = "EmptyFooter";
		EndIf;
	EndIf;

	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionData.CompositionSchema, ComposerSettings, DetailsData, , Type("DataCompositionTemplateGenerator"));
	ExternalDataSets = New Structure("NodeContentMetadataTable", CompositionData.NodeContentMetadataTable);
	
	Processor = New DataCompositionProcessor;
	Processor.Initialize(Template, ExternalDataSets, DetailsData, True);
	
	Output = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	Output.SetDocument(New SpreadsheetDocument);
	
	Return New Structure("SpreadsheetDocument, Decryption, CompositionSchema",
		Output.Output(Processor), DetailsData, CompositionData.CompositionSchema);
EndFunction

//  It returns data as two-level tree, the first level is metadata kind, the second level includes objects.
//  It is based on the InfobaseNode attribute values, "AdditionalRegistration".
//
//  Parameters:
//      ListOfMetadataNames - Array - full Metadata name for query restriction.
//                                      It can be item collection with the FullMetadataName field.
//
Function GenerateValueTree(ListOfMetadataNames = Undefined) Export
	SetPrivilegedMode(True);
	
	CompositionData = InitializeComposer(ListOfMetadataNames);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionData.CompositionSchema, CompositionData.SettingsComposer.GetSettings(), , , 
		Type("DataCompositionValueCollectionTemplateGenerator"));
	ExternalDataSets = New Structure("NodeContentMetadataTable", CompositionData.NodeContentMetadataTable);
	
	Processor = New DataCompositionProcessor;
	Processor.Initialize(Template, ExternalDataSets, , True);
	
	Output = New DataCompositionResultValueCollectionOutputProcessor;
	Output.SetObject(New ValueTree);
	ResultTree = Output.Output(Processor);
	
	Return ResultTree;
EndFunction

//  It initializes the whole object.
//
//  Parameters:
//      Source - String, UUID - address of the source object in the temporary storage or data.
//
//  Returns:
//      DataProcessorObject - InteractiveExportChange
//
Function InitializeThisObject(Val Source = "") Export
	
	If TypeOf(Source)=Type("String") Then
		If IsBlankString(Source) Then
			Return ThisObject;
		EndIf;
		Source = GetFromTempStorage(Source);
	EndIf;
		
	FillPropertyValues(ThisObject, Source, , "AllDocumentFilterComposer, AdditionalRegistration, AdditionalNodeScriptRegistration");
	
	DataExchangeServer.FillValueTable(AdditionalRegistration, Source.AdditionalRegistration);
	DataExchangeServer.FillValueTable(AdditionalRegistrationScriptSite, Source.AdditionalRegistrationScriptSite);
	
	// Initialize the composer again.
	If IsBlankString(Source.AddressLinkerAllDocuments) Then
		Data = SettingsComposerGeneralSelect();
	Else
		Data = GetFromTempStorage(Source.AddressLinkerAllDocuments);
	EndIf;
		
	ThisObject.ComposerAllDocumentsFilter = New DataCompositionSettingsComposer;
	ThisObject.ComposerAllDocumentsFilter.Initialize(
		New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
	ThisObject.ComposerAllDocumentsFilter.LoadSettings(Data.Settings);
	
	If IsBlankString(Source.AddressLinkerAllDocuments) Then
		ThisObject.AddressLinkerAllDocuments = PutToTempStorage(Data, Source.AddressOfFormStore);
	Else 
		ThisObject.AddressLinkerAllDocuments = Source.AddressLinkerAllDocuments;
	EndIf;
		
	Return ThisObject;
EndFunction

//  It saves data of this object in temporary storage.
//
//  Parameters:
//      StorageAddress - String, UUID - storage form ID or address for posting.
//
//  Returns:
//      String - address of saved item.
//
Function SaveThisObject(Val StorageAddress) Export
	Data = New Structure;
	For Each Meta IN ThisObject.Metadata().Attributes Do
		Name = Meta.Name;
		Data.Insert(Name, ThisObject[Name]);
	EndDo;
	
	ComposerData = SettingsComposerGeneralSelect();
	Data.Insert("AddressLinkerAllDocuments", PutToTempStorage(ComposerData, StorageAddress));
	
	Return PutToTempStorage(Data, StorageAddress);
EndFunction

//  It returns composer data for common filters of the InfobaseNode node.
//  It is based on the InfobaseNode attribute values, "AdditionalRegistration".
//
//  Parameters:
//      AddressConservationScheme - String, UUID - temporary storage address 
//                              for composition schema saving.
//
// Returns:
//      Structure  - fields:
//          * Settings       - DataCompositionSettings - Composer settings.
//          * CompositionSchema - DataCompositionSchema     - Composition schema.
//
Function SettingsComposerGeneralSelect(AddressConservationScheme = Undefined) Export
	
	SavedVariant = ExportVariant;
	ExportVariant = 1;
	SavingAddres = ?(AddressConservationScheme = Undefined, New UUID, AddressConservationScheme);
	Data = InitializeComposer(Undefined, True, SavingAddres);
	ExportVariant = SavedVariant;
	
	Result = New Structure;
	Result.Insert("Settings",  Data.SettingsComposer.Settings);
	Result.Insert("CompositionSchema", Data.CompositionSchema);
	
	Return Result;
EndFunction

//  It returns the composer for filtering one metadata type of the InfobaseNode node.
//
//  Parameters:
//      FullMetadataName  - String - table name for composer building. Perhaps there
//                                      will identifiers for "all documents" or "all
//                                      catalogs" or ref to group.
//      Presentation        - String - the object presentation in the filter.
//      Filter                - DataCompositionFilter - composition filter for filling.
//      AddressConservationScheme - String, UUID - temporary storage address 
//                              for composition schema saving.
//
// Returns:
//      DataCompositionSettingsComposer - initialized composer.
//
Function SettingsComposerByTableName(FullMetadataName, Presentation = Undefined, Filter = Undefined, AddressConservationScheme = Undefined) Export
	
	CompositionSchema = New DataCompositionSchema;
	
	Source = CompositionSchema.DataSources.Add();
	Source.Name = "Source";
	Source.DataSourceType = "local";
	
	AddingTables = ExpandedFoldersContentMetadata(FullMetadataName);
	
	For Each TableName IN AddingTables Do
		AddSetIntoDataCompositionSchema(CompositionSchema, TableName, Presentation);
	EndDo;
	
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(
		PutToTempStorage(CompositionSchema, AddressConservationScheme)));
	
	If Filter <> Undefined Then
		AddCompositionFilterValues(Composer.Settings.Filter.Items, Filter.Items);
		Composer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	EndIf;
	
	Return Composer;
EndFunction

// Returns:
//     String - Prefix for form name getting of current object.
//
Function BaseNameForForm() Export
	Return Metadata().FullName() + "."
EndFunction

// Returns:
//     String - title for filter presentation generating by all documents.
//
Function AllDocumentsFilterTitleGroup() Export
	Return NStr("en='All documents';ru='Все документы'");
EndFunction

// Returns:
//     String - title for filter presentation generating by all catalogs.
//
Function AllCatalogsFilterGroupsTitle() Export
	Return NStr("en='All catalogs';ru='Все справочники'");
EndFunction

//  Returns description of the period and filter as a string.
//
//  Parameters:
//      Period - StandardPeriod     - Period for filter description.
//      Filter  - DataCompositionFilter - data composition filter for description.
//      DetailsOfEmptySelection - String - value return in case of an empty filter.
//
Function FilterPresentation(Period, Filter, Val DetailsOfEmptySelection = Undefined) Export
	Return DataExchangeServer.FilterPresentationExportAddition(Period, Filter, DetailsOfEmptySelection);
EndFunction

//  It returns the description of period and filter by the "AllDocumentsFilterPeriod" and "ComposerSelectAllDicuments" attributes.
//
//  Parameters:
//      DetailsOfEmptySelection - String - value return in case of an empty filter.
//
Function AllDocumentsFilterPresentation(Val DetailsOfEmptySelection = Undefined) Export
	
	If DetailsOfEmptySelection = Undefined Then
		DetailsOfEmptySelection = AllDocumentsFilterTitleGroup();
	EndIf;
	
	Return FilterPresentation("", ComposerAllDocumentsFilter, DetailsOfEmptySelection);
EndFunction

//  Returns description of a detailed filter by the AdditionalRegistration attribute.
//
//  Parameters:
//      DetailsOfEmptySelection - String - value return in case of an empty filter.
//
Function DetailedFilterPresentation(Val DetailsOfEmptySelection=Undefined) Export
	Return DataExchangeServer.PresentationDetailedAdditionOfExport(AdditionalRegistration, DetailsOfEmptySelection);
EndFunction

// Identifier of metadata objects service group "All documents".
//
Function AllDocumentsID() Export
	// It can not overlap with the full name of metadata.
	Return DataExchangeServer.ExportAdditionAllDocumentsID();
EndFunction

// Returns:
//     String - Identifier of the service group of the All catalogs metadata objects.
//
Function AllCatalogsID() Export
	// It can not overlap with the full name of metadata.
	Return DataExchangeServer.ExportAdditionIDAllCatalogs();
EndFunction

//  It adds filter in the end of filter with possible field correction.
//
//  Parameters:
//      ItemsOfReceiver - ItemCollectionOfDataCompositionFilter - receiver.
//      SourceItems - ItemCollectionOfDataCompositionFilter - source.
//      FieldMap - The KeyAndValue object collection where.
//      Key - source path to the field data, 
//      Value - path for result. 
//  For Example for replacements fields of type.
//  ""Ref.Name" -> "RegistrationObject.name″ the New structure must be passed("Ref", "RegistrationObject").
//
Procedure AddCompositionFilterValues(ItemsOfReceiver, SourceItems, FieldMap = Undefined) Export
	
	For Each Item IN SourceItems Do
		
		Type=TypeOf(Item);
		FilterItem = ItemsOfReceiver.Add(Type);
		FillPropertyValues(FilterItem, Item);
		If Type=Type("DataCompositionFilterItemGroup") Then
			AddCompositionFilterValues(FilterItem.Items, Item.Items, FieldMap);
			
		ElsIf FieldMap<>Undefined Then
			InitialFieldByString = Item.LeftValue;
			For Each KeyValue IN FieldMap Do
				ControlNew     = Lower(KeyValue.Key);
				ControlLength     = 1 + StrLen(ControlNew);
				InitialControl = Lower(Left(InitialFieldByString, ControlLength));
				If InitialControl=ControlNew Then
					FilterItem.LeftValue = New DataCompositionField(KeyValue.Value);
					Break;
				ElsIf InitialControl=ControlNew + "." Then
					FilterItem.LeftValue = New DataCompositionField(KeyValue.Value + Mid(InitialFieldByString, ControlLength));
					Break;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

//  It returns the value list item by presentation.
//
//  Parameters:
//      ValueList - ValueList - search list.
//      Presentation  - String         - Parameter  for search.
//
// Returns:
//      ItemOfList - found item.
//      Undefined  - If item is not found.
//
Function FindByPresentationListItem(ValueList, Presentation) Export
	For Each ItemOfList IN ValueList Do
		If ItemOfList.Presentation=Presentation Then
			Return ItemOfList;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

//  It produces additional registration by current object data.
//
Procedure RegisterAdditionalModifications() Export
	
	If ExportVariant <= 0 Then
		// Without changes
		Return;
	EndIf;
	
	ChangesTree = GenerateValueTree();
	
	SetPrivilegedMode(True);
	For Each GroupRow IN ChangesTree.Rows Do
		For Each String IN GroupRow.Rows Do
			If String.CountForExport > 0 Then
				DataExchangeEvents.RecordChangesData(InfobaseNode, String.RegistrationObject, False);
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

//  It returns value list from the presentations of possible settings.
//
//  Parameters:
//      ExchangeNode - ExchangePlanRef - exchange node for return settings. If it is not pointed,
//  then the current value of the InfobaseNode attribute is used.
//      Variants - Array             - if it is pointed, then we filter
//                                      restorable settings by variants 0 - without filter, 1 - filter all documents, 2 - detailed, 3 - node script.
//
//  Returns:
//      ValueList - Possible settings.
//
Function ReadSettingsListPresentations(ExchangeNode = Undefined, Variants = Undefined) Export
	
	ParametersOfSettings = ParametersSettingsStructure(ExchangeNode);
	
	SetPrivilegedMode(True);    
	VariantList = CommonSettingsStorage.Load(
	ParametersOfSettings.ObjectKey, ParametersOfSettings.SettingsKey,
	ParametersOfSettings, ParametersOfSettings.User);
	
	PresentationsList = New ValueList;
	If VariantList<>Undefined Then
		For Each Item IN VariantList Do
			If Variants=Undefined Or Variants.Find(Item.Value.ExportVariant)<>Undefined Then
				PresentationsList.Add(Item.Presentation, Item.Presentation);
			EndIf;
		EndDo;
	EndIf;
	
	Return PresentationsList;
EndFunction

//  It restores attribute values of the current object from the specified list item.
//
//  Parameters:
//      Presentation       - String - restored setting presentation.
//      Variants            - Array - if it is pointed, then we filter
//                                     restorable settings by variants 0 - without filter, 1 - filter all documents, 2 - detailed, 3 - node script.
//      AddressOfFormStore - String, UUID - unnecessary address for saving.
//
// Returns:
//      Boolean - True - restored successfully, False - setting is not found.
//
Function RestoreCurrentFromSettings(Presentation, Variants = Undefined, AddressOfFormStore = Undefined) Export
	
	VariantList = ReadSettingList(Variants);
	ItemOfList = FindByPresentationListItem(VariantList, Presentation);
	
	Result = ItemOfList<>Undefined;
	If Result Then
		FillPropertyValues(ThisObject, ItemOfList.Value);
		
		// Compile linker by pieces.
		Data = SettingsComposerGeneralSelect();
		ComposerAllDocumentsFilter = New DataCompositionSettingsComposer;
		ComposerAllDocumentsFilter.Initialize(New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
		ComposerAllDocumentsFilter.LoadSettings(ItemOfList.Value._ComposerSettingsForAllSelectedDocuments);
		
		// Initialization of the assistant item.
		If AddressOfFormStore<>Undefined Then
			AddressLinkerAllDocuments = PutToTempStorage(Data, AddressOfFormStore);
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

//  It saves attribute values of the current object in settings with the specified presentation.
//
//  Parameters:
//      AddressCustomizationVariant - String, UUID is address in temporary storage of setting value list.
//      Presentation:         - String - setting presentation.
//
Procedure SaveCurrentToSettings(Presentation) Export
	VariantList = ReadSettingList();
	
	ItemOfList = FindByPresentationListItem(VariantList, Presentation);
	If ItemOfList=Undefined Then
		ItemOfList = VariantList.Add(, Presentation);
		VariantList.SortByPresentation();
	EndIf;
	
	SavingAttributes = "InfobaseNode, ExportVariant, AllDocumentsFilterPeriod,
		|AdditionalRegistration, NodeScriptFilterPeriod, AdditionalRegistrationScriptSite, NodeScriptFilterPresentation";
	
	ItemOfList.Value = New Structure(SavingAttributes);
	FillPropertyValues(ItemOfList.Value, ThisObject);
	
	ItemOfList.Value.Insert("_LinkerSettingsForAllSelectedDocuments", ComposerAllDocumentsFilter.Settings);
	
	ParametersOfSettings = ParametersSettingsStructure();
	
	SetPrivilegedMode(True);
	CommonSettingsStorage.Save(
		ParametersOfSettings.ObjectKey, ParametersOfSettings.SettingsKey, 
		VariantList, 
		ParametersOfSettings, ParametersOfSettings.User);
EndProcedure

//  It deletes the setting variant from list.
//
//  Parameters:
//      AddressCustomizationVariant - String, UUID is address in temporary storage of setting value list.
//      Presentation:         - String - setting presentation.
//
Procedure RemoveSettingsOption(Presentation) Export
	VariantList = ReadSettingList();
	ItemOfList = FindByPresentationListItem(VariantList, Presentation);
	
	If ItemOfList<>Undefined Then
		VariantList.Delete(ItemOfList);
		VariantList.SortByPresentation();
		SettingsListSave(VariantList);
	EndIf;
	
EndProcedure

// It returns an array of the metadata table names by compound type of the FullMetadataName parameter.
// It is based on current value of the InfobaseNode attribute.
//
// Parameters:
//      FullMetadataName - String, ValueTree is table name (for example "Catalog.Currency")
//                            or name
//                            of a predefined group (for example "AllDocuments") or value tree describing the group.
//
// Returns:
//      Array - Metadata name.
//
Function ExpandedFoldersContentMetadata(FullMetadataName) Export
	
	If TypeOf(FullMetadataName) <> Type("String") Then
		// Value tree with filter group. Root - description, in rows - Metadata name.
		StructureTable = New Array;
		For Each GroupRow IN FullMetadataName.Rows Do
			For Each GroupStructureString IN GroupRow.Rows Do
				StructureTable.Add(GroupStructureString.FullMetadataName);
			EndDo;
		EndDo;
		
	ElsIf FullMetadataName = AllDocumentsID() Then
		// All node documents
		AllData = DataExchangeReUse.ExchangePlanContent(InfobaseNode.Metadata().Name, True, False);
		StructureTable = AllData.UnloadColumn("FullMetadataName");
		
	ElsIf FullMetadataName = AllCatalogsID() Then
		// All node catalogs
		AllData = DataExchangeReUse.ExchangePlanContent(InfobaseNode.Metadata().Name, False, True);
		StructureTable = AllData.UnloadColumn("FullMetadataName");
		
	Else
		// Single metadata table.
		StructureTable = New Array;
		StructureTable.Add(FullMetadataName);
		
	EndIf;
	
	// Hide objects, for which it is specified "DoNotExport".
	DoNotExportMode = Enums.ExchangeObjectsExportModes.DoNotExport;
	ImportMode   = DataExchangeReUse.UserExchangePlanContent(InfobaseNode);
	
	Position = StructureTable.UBound();
	While Position >= 0 Do
		If ImportMode[StructureTable[Position]] = DoNotExportMode Then
			StructureTable.Delete(Position);
		EndIf;
		Position = Position - 1;
	EndDo;
	
	Return StructureTable;
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

//  Value table constructor. It generates a table with columns of arbitrary type.
//
//  Parameters:
//      ListColumns  - String - list of table column names separated by commas.
//      ListOfIndexes - String - list of table indexes separated by commas.
//
// Returns:
//      ValueTable - built table.
//
Function ValueTable(ListColumns, ListOfIndexes = "")
	ResultTable = New ValueTable;
	
	For Each KeyValue IN (New Structure(ListColumns)) Do
		ResultTable.Columns.Add(KeyValue.Key);
	EndDo;
	For Each KeyValue IN (New Structure(ListOfIndexes)) Do
		ResultTable.Indexes.Add(KeyValue.Key);
	EndDo;
	
	Return ResultTable;
EndFunction

//  It adds a single filter item in list.
//
//  Parameters:
//      FilterItems  - DataCompositionFilterItem - ref to the checked object.
//      PathFieldsToData - String - path to the data for added item.
//      ComparisonType    - DataCompositionComparisonType - comparsion type for added item.
//      Value        - Arbitrary - comparison value for added item.
//      Presentation    -String - unnecessary field presentation.
//      
Procedure AddFilterItem(FilterItems, PathFieldsToData, ComparisonType, Value, Presentation = Undefined)
	
	Item = FilterItems.Add(Type("DataCompositionFilterItem"));
	Item.Use  = True;
	Item.LeftValue  = New DataCompositionField(PathFieldsToData);
	Item.ComparisonType   = ComparisonType;
	Item.RightValue = Value;
	
	If Presentation<>Undefined Then
		Item.Presentation = Presentation;
	EndIf;
EndProcedure

//  It adds a data set with the reference field to the composition schema by a table name.
//
//  Parameters:
//      DataCompositionSchema - DataCompositionSchema - schema in which data set is being added.
//      TableName:           - String - data table name.
//      Presentation:        - String - presentation for the reference field.
//
Procedure AddSetIntoDataCompositionSchema(DataCompositionSchema, TableName, Presentation = Undefined)
	
	Set = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	Set.Query = "
		|SELECT 
		|   Ref
		|FROM 
		|   " + TableName + "
		|";
	Set.AutoFillAvailableFields = True;
	Set.DataSource = DataCompositionSchema.DataSources[0].Name;
	Set.Name = "Set" + Format(DataCompositionSchema.DataSets.Count()-1, "NZ=; NG=");
	
	Field = Set.Fields.Add(Type("DataCompositionSchemaDataSetField"));
	Field.Field = "Ref";
	Field.Title = ?(Presentation=Undefined, DataExchangeServer.ObjectPresentation(TableName), Presentation);
	
EndProcedure

//  It adds a collection structure from the composing structure.
//
//  Parameters:
//      ItemsOfReceiver - DataCompositionSettingStructureItemCollection - receiver.
//      SourceItems - DataCompositionSettingStructureItemCollection - source.
//
Procedure AddCompositionStructureValues(ItemsOfReceiver, SourceItems)
	For Each Item IN SourceItems Do
		Type=TypeOf(Item);
		FilterItem = ItemsOfReceiver.Add(Type);
		FillPropertyValues(FilterItem, Item);
		If Type=Type("DataCompositionGroup") Then
			AddCompositionStructureValues(FilterItem.Items, Item.Items);
		EndIf;
	EndDo
EndProcedure

//  It sets the data sets in the schema and initializes a composer.
//  It is based on the attribute values:
//    "InfobaseNode", "AdditionalRegistration", 
//    "ExportVariant", "AllDocumentsFilterPeriod", "ComposerAllDocumentsFilter"
//
//  Parameters:
//      ListOfMetadataNames - Array - Metadata names (value trees of restriction
//                                      groups,
//                                      the "all documents" or "all INE" service identifiers) which will be built a schema for. 
//                                      If it is not specified, then for all the node content.
//
//      LimitUseOfSelection - Boolean - the flag means that composition will
//                                                  be initialized for export item selection only.
//
//      AddressConservationScheme - String, UUID - temporary storage address 
//                              for composition schema saving.
//
//  Returns:
//      Structure - fields:
//         * NodeContentMetadataTable - ValueTable - node content description.
//         * CompositionSchema - DataCompositionSchema - initiated value.
//         * SettingsComposer - DataCompositionSettingsComposer - initiated value.
//
Function InitializeComposer(ListOfMetadataNames = Undefined, LimitUseOfSelection = False, AddressConservationScheme = Undefined)
	
	NodeContentMetadataTable = DataExchangeReUse.ExchangePlanContent(InfobaseNode.Metadata().Name);
	CompositionSchema = GetTemplate("DataCompositionSchema");
	
	// Total sets.
	QuantityElementsSets = CompositionSchema.DataSets.GeneralItemQuantity.Items;
	
	// Sets for every necessary metadata type.
	ChangeSetItems = CompositionSchema.DataSets.ChangeRecords.Items;
	While ChangeSetItems.Count() > 1 Do
		// [0] - Field description
		ChangeSetItems.Delete(ChangeSetItems[1]);
	EndDo;
	DataSource = CompositionSchema.DataSources[0].Name;
	
	// Filter for what we are wanted for.
	MetaDataNameFilter = New Map;
	If ListOfMetadataNames <> Undefined Then
		If TypeOf(ListOfMetadataNames) = Type("Array") Then
			For Each MetaName IN ListOfMetadataNames Do
				MetaDataNameFilter.Insert(MetaName, True);
			EndDo;
		Else
			For Each Item IN ListOfMetadataNames Do
				MetaDataNameFilter.Insert(Item.FullMetadataName, True);
			EndDo;
		EndIf;
	EndIf;
	
	// Always automatic changes and numbers.
	For Each String IN NodeContentMetadataTable Do
		FullMetadataName = String.FullMetadataName;
		If ListOfMetadataNames <> Undefined AND MetaDataNameFilter[FullMetadataName] <> True Then
			Continue;
		EndIf;
		
		SetNameByMetadata = StrReplace(FullMetadataName, ".", "_");
		SetName = "automatically_" + SetNameByMetadata;
		If ChangeSetItems.Find(SetName) = Undefined Then
			Set = ChangeSetItems.Add(Type("DataCompositionSchemaDataSetQuery"));
			Set.AutoFillAvailableFields = False;
			Set.DataSource = DataSource;
			Set.Name = SetName;
			Set.Query = "
				|SELECT DISTINCT ALLOWED
				|	" + SetName + "_Changes.Ref         AS
				|	RegistrationObject TYPE(" + FullMetadataName + ") AS ObjectRegistrationType,
				|	&ReasonForRegistrationAutomatically AS ReasonForRegistration
				|FROM
				|	" + FullMetadataName + ".Changes AS " + SetName + "_Changes
				|";
		EndIf;
		
		SetName = "Quantity_" + SetNameByMetadata;
		If QuantityElementsSets.Find(SetName) = Undefined Then
			Set = QuantityElementsSets.Add(Type("DataCompositionSchemaDataSetQuery"));
			Set.AutoFillAvailableFields = True;
			Set.DataSource = DataSource;
			Set.Name = SetName;
			Set.Query = "
				|SELECT ALLOWED
				|	Type(" + FullMetadataName + ")     AS Type,
				|	COUNT(" + SetName + ".Ref)
				|AS GeneralItemQuantity FROM
				|	" + FullMetadataName + " AS " + SetName + "
				|";
		EndIf;
		
	EndDo;
	
	// Variants of additional changes.
	If ExportVariant = 1 Then
		// Common filter by header
		TableOfAdditionalChanges = ValueTable("FullMetadataName, Filter, Period, PeriodSelection");
		String = TableOfAdditionalChanges.Add();
		String.FullMetadataName = AllDocumentsID();
		String.PeriodSelection        = True;
		String.Period              = AllDocumentsFilterPeriod;
		String.Filter               = ComposerAllDocumentsFilter.Settings.Filter;
		
	ElsIf ExportVariant = 2 Then
		// Detailed filter
		TableOfAdditionalChanges = AdditionalRegistration;
		
	Else
		// Without additional changes at all.
		TableOfAdditionalChanges = New ValueTable;
		
	EndIf;
	
	// Additional changes
	For Each String IN TableOfAdditionalChanges Do
		FullMetadataName = String.FullMetadataName;
		If ListOfMetadataNames <> Undefined AND MetaDataNameFilter[FullMetadataName] <> True Then
			Continue;
		EndIf;
		
		AddingTables = ExpandedFoldersContentMetadata(FullMetadataName);
		For Each NameOfAddedTables IN AddingTables Do
			If ListOfMetadataNames <> Undefined AND MetaDataNameFilter[NameOfAddedTables] <> True Then
				Continue;
			EndIf;
			
			SetName = "Additionally_" + StrReplace(NameOfAddedTables, ".", "_");
			If ChangeSetItems.Find(SetName) = Undefined Then 
				Set = ChangeSetItems.Add(Type("DataCompositionSchemaDataSetQuery"));
				Set.DataSource = DataSource;
				Set.AutoFillAvailableFields = True;
				Set.Name = SetName;
				
				Set.Query = "
					|SELECT ALLOWED
					|	" + SetName + ".Ref           AS RegisrationObject
					|	TYPE(" + NameOfAddedTables + ") AS ObjectRegistrationType,
					|	&ReasonForRegistrationAdvanced   AS ReasonForRegistration
					|FROM
					|	" + NameOfAddedTables + " AS " + SetName + "
					|";
					
				// We add additional sets for getting data of their filter tabular sections.
				AddingParameters = New Structure;
				AddingParameters.Insert("NameOfAddedTables", NameOfAddedTables);
				AddingParameters.Insert("CompositionSchema",       CompositionSchema);
				AddAdditionalSetsOfTabularLayoutParts(String.Filter.Items, AddingParameters)
			EndIf;
			
		EndDo;
	EndDo;
	
	// General parameters
	Parameters = CompositionSchema.Parameters;
	Parameters.Find("InfobaseNode").Value = InfobaseNode;
	
	AutoParameter = Parameters.Find("ReasonForRegistrationAutomatically");
	AutoParameter.Value = NStr("en='By common rules';ru='По общим правилам'");
	
	AdditionalParameter = Parameters.Find("ReasonForRegistrationAdvanced");
	AdditionalParameter.Value = NStr("en='Additionally';ru='Дополнительно'");
	
	ReferenceParameter = Parameters.Find("ReasonForRegistrationLink");
	ReferenceParameter.Value = NStr("en='By ref';ru='По ссылке'");
	
	If LimitUseOfSelection Then
		Fields = CompositionSchema.DataSets.ChangeRecords.Fields;
		Restriction = Fields.Find("ObjectRegistrationType").UseRestriction;
		Restriction.Condition = True;
		Restriction = Fields.Find("ReasonForRegistration").UseRestriction;
		Restriction.Condition = True;
		
		Fields = CompositionSchema.DataSets.NodeContentMetadataTable.Fields;
		Restriction = Fields.Find("ListPresentation").UseRestriction;
		Restriction.Condition = True;
		Restriction = Fields.Find("Presentation").UseRestriction;
		Restriction.Condition = True;
		Restriction = Fields.Find("FullMetadataName").UseRestriction;
		Restriction.Condition = True;
		Restriction = Fields.Find("Periodical").UseRestriction;
		Restriction.Condition = True;
	EndIf;
	
	SettingsComposer = New DataCompositionSettingsComposer;
	
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(
		PutToTempStorage(CompositionSchema, AddressConservationScheme)));
	SettingsComposer.LoadSettings(CompositionSchema.DefaultSettings);
	
	If TableOfAdditionalChanges.Count() > 0 Then 
		
		If LimitUseOfSelection Then
			PreferencesRoot = SettingsComposer.FixedSettings;
		Else
			PreferencesRoot = SettingsComposer.Settings;
		EndIf;
		
		// We add settings for additional data filter.
		FilterGroup = PreferencesRoot.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		FilterGroup.Use = True;
		FilterGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		
		FilterItems = FilterGroup.Items;
		
		// Always apply autoregistration.
		AddFilterItem(FilterGroup.Items, "ReasonForRegistration", DataCompositionComparisonType.Equal, AutoParameter.Value);
		AddFilterItem(FilterGroup.Items, "ReasonForRegistration", DataCompositionComparisonType.Equal, ReferenceParameter.Value);
		
		For Each String IN TableOfAdditionalChanges Do
			FullMetadataName = String.FullMetadataName;
			If ListOfMetadataNames <> Undefined AND MetaDataNameFilter[FullMetadataName] <> True Then
				Continue;
			EndIf;
			
			AddingTables = ExpandedFoldersContentMetadata(FullMetadataName);
			For Each NameOfAddedTables IN AddingTables Do
				If ListOfMetadataNames <> Undefined AND MetaDataNameFilter[NameOfAddedTables] <> True Then
					Continue;
				EndIf;
				
				FilterGroup = FilterItems.Add(Type("DataCompositionFilterItemGroup"));
				FilterGroup.Use = True;
				
				AddFilterItem(FilterGroup.Items, "FullMetadataName", DataCompositionComparisonType.Equal, NameOfAddedTables);
				AddFilterItem(FilterGroup.Items, "ReasonForRegistration",  DataCompositionComparisonType.Equal, AdditionalParameter.Value);
				
				If String.PeriodSelection Then
					StartDate    = String.Period.StartDate;
					EndDate = String.Period.EndDate;
					If StartDate <> '00010101' Then
						AddFilterItem(FilterGroup.Items, "RegistrationObject.Date", DataCompositionComparisonType.GreaterOrEqual, StartDate);
					EndIf;
					If EndDate <> '00010101' Then
						AddFilterItem(FilterGroup.Items, "RegistrationObject.Date", DataCompositionComparisonType.LessOrEqual, EndDate);
					EndIf;
				EndIf;
				
				// We add filter items with correction of the Reference fields -> "RegistrationObject".
				AddingParameters = New Structure;
				AddingParameters.Insert("NameOfAddedTables", NameOfAddedTables);
				AddAdditionalFiltersOfTabularSectionComposition(
					FilterGroup.Items, String.Filter.Items, ChangeSetItems, 
					AddingParameters);
			EndDo;
		EndDo;
		
	EndIf;
	
	Return New Structure("NodeContentMetadataTable,CompositionSchema,SettingsComposer", 
		NodeContentMetadataTable, CompositionSchema, SettingsComposer);
EndFunction

Procedure AddAdditionalSetsOfTabularLayoutParts(SourceItems, AddingParameters)
	
	NameOfAddedTables = AddingParameters.NameOfAddedTables;
	CompositionSchema       = AddingParameters.CompositionSchema;
	
	CommonSet = CompositionSchema.DataSets.ChangeRecords;
	DataSource = CompositionSchema.DataSources[0].Name; 
	
	ObjectMetadata = Metadata.FindByFullName(NameOfAddedTables);
	If ObjectMetadata = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='The %1 incorrect name of metadata for registration at the %2 node';ru='Некорректное имя метаданных ""%1"" для регистрации на узле ""%2""'"),
				NameOfAddedTables, InfobaseNode);
	EndIf;
		
	For Each Item IN SourceItems Do
		
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then 
			AddAdditionalSetsOfTabularLayoutParts(Item.Items, AddingParameters);
			Continue;
		EndIf;
		
		// This is an item, make sure it is in our table.
		FieldName = Item.LeftValue;
		If Left(FieldName, 7) = "Ref." Then
			FieldName = Mid(FieldName, 8);
		ElsIf Left(FieldName, 18) = "RegistrationObject." Then
			FieldName = Mid(FieldName, 19);
		Else
			Continue;
		EndIf;
			
		Position = Find(FieldName, "."); 
		TableName   = Left(FieldName, Position - 1);
		TabularSectionMetadata = ObjectMetadata.TabularSections.Find(TableName);
			
		If Position = 0 Then
			// Header filter, get by reference.
			Continue;
		ElsIf TabularSectionMetadata = Undefined Then
			// There is a tabular section, but it is not ours.
			Continue;
		EndIf;
		
		// Our tabular section
		DataPath = Mid(FieldName, Position + 1);
		If Left(DataPath + ".", 7) = "Ref." Then
			// Readdress it to the head table.
			Continue;
		EndIf;
		
		Alias = StrReplace(NameOfAddedTables, ".", "") + TableName;
		SetName = "Additionally_" + Alias;
		Set = CommonSet.Items.Find(SetName);
		If Set <> Undefined Then
			Continue;
		EndIf;
		
		Set = CommonSet.Items.Add(Type("DataCompositionSchemaDataSetQuery"));
		Set.AutoFillAvailableFields = True;
		Set.DataSource = DataSource;
		Set.Name = SetName;
		
		AllTabularSectionFields = AttributesTabularSectionForQuery(TabularSectionMetadata, Alias);
		Set.Query = "
			|SELECT ALLOWED
			|	Ref                             AS RegistrationObject,
			|	Type(" + NameOfAddedTables + ") AS
			|	ObjectRegistrationType, &ReasonForRegistrationAdvanced AS ReasonForRegistration
			|	" + AllTabularSectionFields.QueryFields +  "
			|IN
			|	" + NameOfAddedTables + "." + TableName + "
			|";
			
		For Each FieldName IN AllTabularSectionFields.NamesOfFields Do
			Field = Set.Fields.Find(FieldName);
			If Field = Undefined Then
				Field = Set.Fields.Add(Type("DataCompositionSchemaDataSetField"));
				Field.DataPath = FieldName;
				Field.Field        = FieldName;
			EndIf;
			Field.AttributeUsingRestriction.Condition = True;
			Field.AttributeUsingRestriction.Field    = True;
			Field.UseRestriction.Condition = True;
			Field.UseRestriction.Field    = True;
		EndDo;
		
	EndDo;
		
EndProcedure

Procedure AddAdditionalFiltersOfTabularSectionComposition(ItemsOfReceiver, SourceItems, SetElements, AddingParameters)
	
	NameOfAddedTables = AddingParameters.NameOfAddedTables;
	MetaObject = Metadata.FindByFullName(NameOfAddedTables);
	
	For Each Item IN SourceItems Do
		// Parsing branch is similar to the AddAdditionalSetsOfTabularLayoutParts branch.
		
		Type = TypeOf(Item);
		If Type = Type("DataCompositionFilterItemGroup") Then
			// We copy group
			FilterItem = ItemsOfReceiver.Add(Type);
			FillPropertyValues(FilterItem, Item);
			
			AddAdditionalFiltersOfTabularSectionComposition(
				FilterItem.Items, Item.Items, SetElements, 
				AddingParameters
			);
			Continue;
		EndIf;
		
		// This is an item, make sure it is in our table.
		FieldName = String(Item.LeftValue);
		If FieldName = "Ref" Then
			FilterItem = ItemsOfReceiver.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue = New DataCompositionField("RegistrationObject");
			Continue;
			
		ElsIf Left(FieldName, 7) = "Ref." Then
			FieldName = Mid(FieldName, 8);
			
		ElsIf Left(FieldName, 18) = "RegistrationObject." Then
			FieldName = Mid(FieldName, 19);
			
		Else
			FilterItem = ItemsOfReceiver.Add(Type);
			FillPropertyValues(FilterItem, Item);
			Continue;
			
		EndIf;
			
		Position = Find(FieldName, "."); 
		TableName   = Left(FieldName, Position - 1);
		MetaTabularSection = MetaObject.TabularSections.Find(TableName);
			
		If Position = 0 Then
			// Header filter will be received by reference.
			FilterItem = ItemsOfReceiver.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue = New DataCompositionField("RegistrationObject." + FieldName);
			Continue;
			
		ElsIf MetaTabularSection = Undefined Then
			// Tabular section is specified but it is not ours. We improve filter.
			FilterItem = ItemsOfReceiver.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue  = New DataCompositionField("FullMetadataName");
			FilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
			FilterItem.Use  = True;
			FilterItem.RightValue = "";
			
			Continue;
		EndIf;
		
		// Tabular section filter
		DataPath = Mid(FieldName, Position + 1);
		If Left(DataPath + ".", 7) = "Ref." Then
			// Readdress it to the head table.
			FilterItem = ItemsOfReceiver.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue = New DataCompositionField("RegistrationObject." + Mid(DataPath, 8));
			
		ElsIf DataPath <> "LineNumber" AND DataPath <> "Ref"
			AND MetaTabularSection.Attributes.Find(DataPath) = Undefined 
		Then
			// Tabular section matches but the attribute is not ours. We improve filter.
			FilterItem = ItemsOfReceiver.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue  = New DataCompositionField("FullMetadataName");
			FilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
			FilterItem.Use  = True;
			FilterItem.RightValue = "";
			
		Else
			// We correct name
			FilterItem = ItemsOfReceiver.Add(Type);
			FillPropertyValues(FilterItem, Item);
			DataPath = StrReplace(NameOfAddedTables + TableName, ".", "") + DataPath;
			FilterItem.LeftValue = New DataCompositionField(DataPath);
		EndIf;
		
	EndDo;
	
EndProcedure

Function AttributesTabularSectionForQuery(Val MetaTabularSection, Val Prefix = "")
	
	QueryFields = ", LineNumber AS " + Prefix + "StringNumber,
	              |Ref AS " + Prefix + "Ref
	              |";
	
	NamesOfFields  = New Array;
	NamesOfFields.Add(Prefix + "LineNumber");
	NamesOfFields.Add(Prefix + "Ref");
	
	For Each MetaAttribute IN MetaTabularSection.Attributes Do
		Name       = MetaAttribute.Name;
		Alias = Prefix + Name;
		QueryFields = QueryFields + ", " + Name + " AS " + Alias + Chars.LF;
		NamesOfFields.Add(Alias);
	EndDo;
	
	Return New Structure("QueryFields, FieldNames", QueryFields, NamesOfFields);
EndFunction

//  It returns the parameters-keys for saving setting in view of exchange plan for all users.
//
//  Parameters:
//      ExchangeNode - ExchangePlanRef - ref to exchange node for return settings. If it is
//                                      not pointed, then the current value of the InfobaseNode attribute is used.
//
//  Returns:
//      SettingsDescription - setting description.
//
Function ParametersSettingsStructure(ExchangeNode = Undefined)
	Node = ?(ExchangeNode=Undefined,  InfobaseNode, ExchangeNode);
	
	Meta = Node.Metadata();
	
	Presentation = Meta.ExtendedObjectPresentation;
	If IsBlankString(Presentation) Then
		Presentation = Meta.ObjectPresentation;
	EndIf;
	If IsBlankString(Presentation) Then
		Presentation = String(Meta);
	EndIf;
	
	ParametersOfSettings = New SettingsDescription();
	ParametersOfSettings.Presentation = Presentation;
	ParametersOfSettings.ObjectKey   = "SettingVariantsOnlineExport";
	ParametersOfSettings.SettingsKey  = Meta.Name;
	ParametersOfSettings.User  = "*";
	
	Return ParametersOfSettings;
EndFunction

// It returns setting value list for the InfobaseNode current value.
//
// Parameters:
//      Variants - Array - if it is pointed, then we filter
//                          restorable settings by variants 0 - without filter, 1 - filter all documents, 2 - detailed, 3 - node script.
//
//  Returns:
//      ValueList - settings.
//
Function ReadSettingList(Variants = Undefined)
	ParametersOfSettings = ParametersSettingsStructure();
	
	SetPrivilegedMode(True);
	VariantList = CommonSettingsStorage.Load(
		ParametersOfSettings.ObjectKey, ParametersOfSettings.SettingsKey, 
		ParametersOfSettings, ParametersOfSettings.User);
		
	If VariantList=Undefined Then
		Result = New ValueList;
	ElsIf Variants=Undefined Then
		Result = VariantList;
	Else
		Result = VariantList;
		Position = Result.Count() - 1;
		While Position>=0 Do
			If Variants.Find(Result[Position].Value.ExportVariant)=Undefined Then
				Result.Delete(Position);
			EndIf;
			Position = Position - 1
		EndDo;
	EndIf;
		
	Return Result;
EndFunction

// It saves the setting value list for the InfobaseNode current value.
//
//  Parameters:
//      VariantList - ValueList - stored variant list.
//
Procedure SettingsListSave(VariantList)
	ParametersOfSettings = ParametersSettingsStructure();
	
	SetPrivilegedMode(True);
	If VariantList.Count()=0 Then
		CommonSettingsStorage.Delete(
			ParametersOfSettings.ObjectKey, ParametersOfSettings.SettingsKey, ParametersOfSettings.User);
	Else
		CommonSettingsStorage.Save(
			ParametersOfSettings.ObjectKey, ParametersOfSettings.SettingsKey, 
			VariantList, 
			ParametersOfSettings, ParametersOfSettings.User);
	EndIf;        
EndProcedure

// It returns the variant description of all additional parameters.
//
Function TextAddOptions()
	
	If ExportVariant = 0 Then
		// All automatic data
		Return NStr("en='Without additional data.';ru='Без дополнительных данных.'");
		
	ElsIf ExportVariant = 1 Then
		TextAllDocuments = AllDocumentsFilterTitleGroup();
		Result = FilterPresentation(AllDocumentsFilterPeriod, ComposerAllDocumentsFilter, TextAllDocuments);
		Return StrReplace(Result, "RegistrationObject.", TextAllDocuments + ".")
		
	ElsIf ExportVariant = 2 Then
		Return DetailedFilterPresentation();
		
	EndIf;
	
	Return "";
EndFunction

// It returns the structure with object attributes.
//
Function ThisObjectInStructureForBackground() Export
	ResultStructure = New Structure;
	For Each Meta IN Metadata().Attributes Do
		AttributeName = Meta.Name;
		ResultStructure.Insert(AttributeName, ThisObject[AttributeName]);
	EndDo;
	
	// Separately settings ComposerAllDocumentsFilter - there is filter only.
	ResultStructure.Insert("ComposerSettingsForAllSelectedDocuments", ComposerAllDocumentsFilter.Settings);
	
	Return ResultStructure;
EndFunction

Procedure HiddenSelectionFields(ItemsOfGrouping, Val HiddenFields)
	GroupType = Type("DataCompositionSelectedFieldGroup");
	For Each GroupItem IN ItemsOfGrouping Do
		If TypeOf(GroupItem)=GroupType Then
			HiddenSelectionFields(GroupItem.Items, HiddenFields)
		Else
			FieldName = StrReplace(String(GroupItem.Field), ".", "");
			If Not IsBlankString(FieldName) AND HiddenFields.Property(FieldName) Then
				GroupItem.Use = False;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#EndIf
