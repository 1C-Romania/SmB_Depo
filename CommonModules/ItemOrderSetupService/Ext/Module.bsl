////////////////////////////////////////////////////////////////////////////////
// Subsystem "Items sequence setting".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Moves the item up or down in the list.
//
// Parameters:
//  Refs              - Refs - ref to the item being moved;
//  List              - DynamicList - the list where the item shall be moved;
//  RepresentedAsList - Boolean - True if the "List" display mode is enabled for
//                                the form item linked with the list.;
//  Direction         - String  - item moving direction: Up or Down in the list.
//
// Returns:
//  String - error description.
Function ChangeElementsOrder(Refs, List, RepresentedAsList, Direction) Export
	
	Result = ValidateAbilityToMove(Refs, List, RepresentedAsList);
	
	If IsBlankString(Result) Then
		CheckItemArranging(Refs.Metadata());
		MoveItem(Refs, List, Direction);
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the structure with the info of the object metadata.
// 
// Parameters:
//  Refs - object reference.
//
// Returns:
//  Structure - info from the object metadata.
Function GetInformationForMove(ObjectMetadata) Export
	
	Information = New Structure;
	
	AttributeMetadata = ObjectMetadata.Attributes.AdditionalOrderingAttribute;
	
	Information.Insert("DescriptionFull",    ObjectMetadata.FullName());
	
	ThisIsCatalog = Metadata.Catalogs.Contains(ObjectMetadata);
	IsCCT        = Metadata.ChartsOfCharacteristicTypes.Contains(ObjectMetadata);
	
	If ThisIsCatalog OR IsCCT Then
		
		Information.Insert("HasFolders",
					ObjectMetadata.Hierarchical AND 
							?(IsCCT, True, ObjectMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems));
		
		Information.Insert("ForFolders",     (AttributeMetadata.Use <> Metadata.ObjectProperties.AttributeUse.ForItem));
		Information.Insert("ForItems", (AttributeMetadata.Use <> Metadata.ObjectProperties.AttributeUse.ForFolder));
		Information.Insert("HasParent",  ObjectMetadata.Hierarchical);
		Information.Insert("FoldersOnTop", ?(NOT Information.HasParent, False, ObjectMetadata.FoldersOnTop));
		Information.Insert("HasOwner", ?(IsCCT, False, (ObjectMetadata.Owners.Count() <> 0)));
		
	Else
		
		Information.Insert("HasFolders",   False);
		Information.Insert("ForFolders",     False);
		Information.Insert("ForItems", True);
		Information.Insert("HasParent", False);
		Information.Insert("HasOwner", False);
		Information.Insert("FoldersOnTop", False);
		
	EndIf;
	
	Return Information;
	
EndFunction

// It returns the add. ordering attribute value for a new object.
//
// Parameters:
//  Information - Structure - info of the object metadata;
//  Parent      - Refs      - references to the object parent;
//  Owner       - Refs      - ref to the object owner.
//
// Returns:
//  Number - attribute value for the add. ordering.
Function GetNewValueOfAdditionalOrderingAttribute(Information, Parent, Owner) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query();
	
	QueryConditions = New Array;
	
	If Information.HasParent Then
		QueryConditions.Add("Table.Parent = &Parent");
		Query.SetParameter("Parent", Parent);
	EndIf;
	
	If Information.HasOwner Then
		QueryConditions.Add("Table.Owner = &Owner");
		Query.SetParameter("Owner", Owner);
	EndIf;
	
	AdditionalConditions = "TRUE";
	For Each Condition IN QueryConditions Do
		AdditionalConditions = AdditionalConditions + " AND " + Condition;
	EndDo;
	
	QueryText =
	"SELECT TOP 1
	|	Table.AdditionalOrderingAttribute AS AdditionalOrderingAttribute
	|FROM
	|	&Table AS Table
	|WHERE
	|	&AdditionalConditions
	|
	|ORDER BY
	|	AdditionalOrderingAttribute DESC";
	
	QueryText = StrReplace(QueryText, "&Table", Information.DescriptionFull);
	QueryText = StrReplace(QueryText, "&AdditionalConditions", AdditionalConditions);
	
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return ?(NOT ValueIsFilled(Selection.AdditionalOrderingAttribute), 1, Selection.AdditionalOrderingAttribute + 1);
	
EndFunction

// It interchanges the selected list item with the contiguous displayed item.
Procedure MoveItem(Val MovedItemRef, Val List, Val Direction)
	
	ContiguousItemRefs = NearbyItem(MovedItemRef, List, Direction);
	If ContiguousItemRefs = Undefined Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		LockDataForEdit(MovedItemRef);
		LockDataForEdit(ContiguousItemRefs);
		
		MovedItemObject = MovedItemRef.GetObject();
		ContiguousItemObject = ContiguousItemRefs.GetObject();
		
		MovedItemObject.AdditionalOrderingAttribute = MovedItemObject.AdditionalOrderingAttribute
			+ ContiguousItemObject.AdditionalOrderingAttribute;
		ContiguousItemObject.AdditionalOrderingAttribute = MovedItemObject.AdditionalOrderingAttribute
			- ContiguousItemObject.AdditionalOrderingAttribute;
		MovedItemObject.AdditionalOrderingAttribute = MovedItemObject.AdditionalOrderingAttribute
			- ContiguousItemObject.AdditionalOrderingAttribute;
	
		MovedItemObject.Write();
		ContiguousItemObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure AddSimpleFilterInQueryBuilder(QueryBuilder, FieldName, Value)
	Filter = QueryBuilder.Filter;
	FilterItemQueryBuilder = Filter.Add(FieldName);
	FilterItemQueryBuilder.ComparisonType = ComparisonType.Equal;
	FilterItemQueryBuilder.Value = Value;
	FilterItemQueryBuilder.Use = True;
EndProcedure

Function ListContainsFilterByOwner(List)
	
	RequiredFilters = New Array;
	RequiredFilters.Add(New DataCompositionField("Owner"));
	RequiredFilters.Add(New DataCompositionField("Owner"));
	
	For Each Filter IN List.SettingsComposer.GetSettings().Filter.Items Do
		If RequiredFilters.Find(Filter.LeftValue) <> Undefined Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function ListContainsFilterOnParent(List)
	
	RequiredFilters = New Array;
	RequiredFilters.Add(New DataCompositionField("Parent"));
	RequiredFilters.Add(New DataCompositionField("Parent"));
	
	For Each Filter IN List.SettingsComposer.GetSettings().Filter.Items Do
		If RequiredFilters.Find(Filter.LeftValue) <> Undefined Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function ValidateAbilityToMove(Refs, List, RepresentedAsList)
	
	AccessParameters = AccessParameters("Update", Refs.Metadata(), "Ref");
	If Not AccessParameters.Accessibility Then
		Return NStr("en='Insufficient rights to modify the items order.';ru='Недостаточно прав для изменения порядка элементов.'");
	EndIf;
	
	For Each GroupItem IN List.SettingsComposer.GetSettings().Structure Do
		If GroupItem.Use Then
			Return NStr("en='For the items order modification it is necessary to disable all the groupings.';ru='Для изменения порядка элементов необходимо отключить все группировки.'");
		EndIf;
	EndDo;
	
	Information = GetInformationForMove(Refs.Metadata());
	
	// For hierarchical catalogs you can set filter by the parent,
	// if not, then the display method must be hierarchical one or in the tree form.
	If Information.HasParent AND RepresentedAsList AND Not ListContainsFilterOnParent(List) Then
		Return NStr("en='To change the item order it is necessary to set the Tree or Hierarchical List viewing mode.';ru='Для изменения порядка элементов необходимо установить режим просмотра ""Дерево"" или ""Иерархический список"".'");
	EndIf;
	
	// For subordinated catalogs owner filter shall be set.
	If Information.HasOwner AND Not ListContainsFilterByOwner(List) Then
		Return NStr("en='To change the item order it is necessary to set the filter by the Owner field.';ru='Для изменения порядка элементов необходимо установить отбор по полю ""Владелец"".'");
	EndIf;
	
	// Check of the "Usage" flag for the AdditionalOrderingAttribute attribute related to the moved item.
	If Information.HasFolders Then
		IsFolder = CommonUse.ObjectAttributeValue(Refs, "IsFolder");
		If IsFolder AND Not Information.ForFolders Or Not IsFolder AND Not Information.ForItems Then
			Return NStr("en='Selected items are impossible to transfer.';ru='Выбранный элемент нельзя перемещать.'");
		EndIf;
	EndIf;
	
	Return "";
	
EndFunction

Function NearbyItem(ItemToMove, List, Val Direction) Export
	
	// Preparation of the query text to the main table of the list.
	
	QueryText = 
	"SELECT ALLOWED TOP 1
	|	*
	|FROM
	|	&Table AS Table
	|WHERE
	|	Table.AdditionalOrderingAttribute > &AdditionalOrderingAttribute
	|ORDER BY
	|	Table.AdditionalOrderingAttribute";
	
	QueryText = StrReplace(QueryText, "&Table", List.MainTable);
	
	If Direction = "Up" Then
		QueryText = StrReplace(QueryText, ">", "<");
		QueryText = QueryText + " DESC";
	EndIf;
	
	Information = GetInformationForMove(ItemToMove.Metadata());
	
	QueryBuilder = New QueryBuilder(QueryText);
	QueryBuilder.FillSettings();
	If Information.HasParent Then
		AddSimpleFilterInQueryBuilder(QueryBuilder, "Parent", CommonUse.ObjectAttributeValue(ItemToMove, "Parent"));
	EndIf;
	
	If Information.HasOwner Then
		AddSimpleFilterInQueryBuilder(QueryBuilder, "Owner", CommonUse.ObjectAttributeValue(ItemToMove, "Owner"));
	EndIf;
	
	If Information.HasFolders Then
		If Information.ForFolders AND Not Information.ForItems Then
			AddSimpleFilterInQueryBuilder(QueryBuilder, "IsFolder", True);
		ElsIf Not Information.ForFolders AND Information.ForItems Then
			AddSimpleFilterInQueryBuilder(QueryBuilder, "IsFolder", False);
		EndIf;
	EndIf;
	
	QueryBuilder.Parameters.Insert("AdditionalOrderingAttribute", CommonUse.ObjectAttributeValue(ItemToMove, "AdditionalOrderingAttribute"));
	
	Query = QueryBuilder.GetQuery();
	
	// Preparation of the data layout scheme similar to the list.
	
	DataCompositionSchema = DataCompositionSchema(Query.Text);
	
	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	SchemaURL = PutToTempStorage(DataCompositionSchema);
	DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
	DataCompositionSettingsComposer.LoadSettings(List.SettingsComposer.GetSettings());
	
	ConfigureOutputStructureSetting(DataCompositionSettingsComposer.Settings);
	
	For Each Parameter IN Query.Parameters Do
		DataCompositionSettingsComposer.Settings.DataParameters.SetParameterValue(
			Parameter.Key, Parameter.Value);
	EndDo;
	
	// Query result display
	
	LayoutResult = New ValueTable;
	TemplateComposer = New DataCompositionTemplateComposer;
	
	DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema,
		DataCompositionSettingsComposer.Settings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
		
	DataCompositionProcessor = New DataCompositionProcessor;
	DataCompositionProcessor.Initialize(DataCompositionTemplate);

	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	OutputProcessor.SetObject(LayoutResult);
	OutputProcessor.Output(DataCompositionProcessor);
	
	NearbyItem = Undefined;
	If LayoutResult.Count() > 0 Then
		NearbyItem = LayoutResult[0].Ref;
	EndIf;
	
	Return NearbyItem;
	
EndFunction

Function DataCompositionSchema(QueryText)
	
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.DataSource = "DataSource1";
	DataSet.AutoFillAvailableFields = True;
	DataSet.Query = QueryText;
	DataSet.Name = "DataSet1";
	
	Return DataCompositionSchema;
	
EndFunction

Procedure ConfigureOutputStructureSetting(Settings)
	
	Settings.Structure.Clear();
	Settings.Selection.Items.Clear();
	
	DataCompositionGroup = Settings.Structure.Add(Type("DataCompositionGroup"));
	DataCompositionGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	DataCompositionGroup.Use = True;
	
	GroupingField = DataCompositionGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	GroupingField.Field = New DataCompositionField("Ref");
	GroupingField.Use = True;
	
	ComboBox = Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
	ComboBox.Field = New DataCompositionField("Ref");
	ComboBox.Use = True;
	
EndProcedure

Function CheckItemArranging(TableMetadata)
	If Not AccessRight("Update", TableMetadata) Then
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	QueryText = 
	"SELECT
	|	&Owner AS Owner,
	|	&Parent AS Parent,
	|	Table.AdditionalOrderingAttribute AS AdditionalOrderingAttribute,
	|	1 AS Count,
	|	Table.Ref AS Ref
	|INTO AllItems
	|FROM
	|	&Table AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AllItems.Owner,
	|	AllItems.Parent,
	|	AllItems.AdditionalOrderingAttribute,
	|	SUM(AllItems.Quantity) AS Quantity
	|INTO IndexStatistics
	|FROM
	|	AllItems AS AllItems
	|
	|GROUP BY
	|	AllItems.AdditionalOrderingAttribute,
	|	AllItems.Parent,
	|	AllItems.Owner
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IndexStatistics.Owner,
	|	IndexStatistics.Parent,
	|	IndexStatistics.AdditionalOrderingAttribute
	|INTO Duplicates
	|FROM
	|	IndexStatistics AS IndexStatistics
	|WHERE
	|	IndexStatistics.Count > 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AllItems.Ref AS Ref
	|FROM
	|	AllItems AS AllItems
	|		INNER JOIN Duplicates AS Duplicates
	|		BY AllItems.AdditionalOrderingAttribute = Duplicates.AdditionalOrderingAttribute
	|			AND AllItems.Parent = Duplicates.Parent
	|			AND AllItems.Owner = Duplicates.Owner
	|
	|UNION ALL
	|
	|SELECT
	|	AllItems.Ref
	|FROM
	|	AllItems AS AllItems
	|WHERE
	|	AllItems.AdditionalOrderingAttribute = 0";
	
	Information = GetInformationForMove(TableMetadata);
	
	QueryText = StrReplace(QueryText, "&Table", Information.DescriptionFull);
	
	FieldParent = "Parent";
	If Not Information.HasParent Then
		FieldParent = "1";
	EndIf;
	QueryText = StrReplace(QueryText, "&Parent", FieldParent);
	
	OwnerField = "Owner";
	If Not Information.HasOwner Then
		OwnerField = "1";
	EndIf;
	QueryText = StrReplace(QueryText, "&Owner", OwnerField);
	
	Query = New Query(QueryText);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return False;
	EndIf;
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Object.AdditionalOrderingAttribute = 0;
		Try
			Object.Write();
		Except
			Continue;
		EndTry;
	EndDo;
	
	Return True;
	
EndFunction

#EndRegion
