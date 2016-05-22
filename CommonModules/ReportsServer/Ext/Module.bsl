////////////////////////////////////////////////////////////////////////////////
// Work methods with the DLS from the report form (server).
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Analysis

Function ExtendedInformationAboutSettings(DCSettingsComposer, Form, OutputConditions = Undefined) Export
	If Form = Undefined Then
		ReportSettings = ReportsClientServer.GetReportSettingsByDefault();
	Else
		ReportSettings = Form.ReportSettings;
	EndIf;
	
	DCSettings = DCSettingsComposer.Settings;
	DCUserSettings = DCSettingsComposer.UserSettings;
	
	AdditionalItemsSettings = CommonUseClientServer.StructureProperty(DCUserSettings.AdditionalProperties, "FormItems");
	If AdditionalItemsSettings = Undefined Then
		AdditionalItemsSettings = New Map;
	EndIf;
	
	Information = New Structure;
	Information.Insert("OnlyCustom", False);
	Information.Insert("OnlyQuick", False);
	Information.Insert("CurrentCDHostIdentifier", Undefined);
	If OutputConditions <> Undefined Then
		FillPropertyValues(Information, OutputConditions);
	EndIf;
	
	Information.Insert("DCSettings", DCSettings);
	
	Information.Insert("ReportSettings",           ReportSettings);
	Information.Insert("VariantTree",            VariantTree());
	Information.Insert("VariantSettings",         VariantSettingsTable());
	Information.Insert("UserSettings", UserSettingsTable());
	
	Information.Insert("DisabledLinks", New Array);
	Information.Insert("Links", New Structure);
	Information.Links.Insert("ByType",             TypeRelationsTable());
	Information.Links.Insert("ParametersSelect",   LinksTableOfSelectionParameters());
	Information.Links.Insert("MetadataObjects", LinkTableMetadataObjects(ReportSettings));
	
	Information.Insert("AdditionalItemsSettings",   AdditionalItemsSettings);
	Information.Insert("MapMetadataObjectName", New Map);
	Information.Insert("Search", New Structure);
	Information.Search.Insert("VariantSettingsByKDField", New Map);
	Information.Search.Insert("UserSettings", New Map);
	Information.Insert("ThereAreQuickSettings", False);
	Information.Insert("ThereAreCommonSettings", False);
	
	For Each DCUsersSetting IN DCUserSettings.Items Do
		SettingProperty = Information.UserSettings.Add();
		SettingProperty.DCUsersSetting = DCUsersSetting;
		SettingProperty.ID               = DCUsersSetting.UserSettingID;
		SettingProperty.IndexInCollection = DCUserSettings.Items.IndexOf(DCUsersSetting);
		SettingProperty.DCIdentifier  = DCUserSettings.GetIDByObject(DCUsersSetting);
		SettingProperty.Type              = ReportsClientServer.RowSettingType(TypeOf(DCUsersSetting));
		Information.Search.UserSettings.Insert(SettingProperty.ID, SettingProperty);
	EndDo;
	
	TreeRow = TreeVariantRegisterNode(Information, DCSettings, DCSettings, Information.VariantTree.Rows);
	TreeRow.Global = True;
	Information.Insert("VariantTreeRootRow", TreeRow);
	If Information.CurrentCDHostIdentifier = Undefined Then
		Information.CurrentCDHostIdentifier = TreeRow.DCIdentifier;
		If Not Information.OnlyCustom Then
			TreeRow.OutputAllowed = True;
		EndIf;
	EndIf;
	
	RegisterVariantSettings(DCSettings, Information);
	
	RegisterLinksFromLeading(Information);
	
	Return Information;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Variant tree

Function VariantTree()
	Result = New ValueTree;
	
	// DLS nodes.
	Result.Columns.Add("KDNode");
	Result.Columns.Add("DCUsersSetting");
	
	// Applied structure.
	Result.Columns.Add("UserSetting");
	
	// Search this setting in node.
	Result.Columns.Add("DCIdentifier");
	
	// Link to DLS nodes.
	Result.Columns.Add("ID", New TypeDescription("String"));
	
	// Setting description.
	Result.Columns.Add("Type", New TypeDescription("String"));
	Result.Columns.Add("Subtype", New TypeDescription("String"));
	
	Result.Columns.Add("HasStructure", New TypeDescription("Boolean"));
	Result.Columns.Add("HasFieldsAndDesign", New TypeDescription("Boolean"));
	Result.Columns.Add("Global", New TypeDescription("Boolean"));
	
	// Output.
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("Title", New TypeDescription("String"));
	Result.Columns.Add("OutputAllowed", New TypeDescription("Boolean"));
	Result.Columns.Add("DisplayOnlyCheckBox", New TypeDescription("Boolean"));
	
	Return Result;
EndFunction

Function TreeVariantRegisterNode(Information, DCSettings, KDNode, TreeRowSet, Subtype = "")
	TreeRow = TreeRowSet.Add();
	TreeRow.KDNode = KDNode;
	TreeRow.Type = ReportsClientServer.RowSettingType(TypeOf(KDNode));
	TreeRow.Subtype = Subtype;
	If TreeRow.Type <> "Settings" Then
		TreeRow.ID = KDNode.UserSettingID;
	EndIf;
	
	TreeRow.DCIdentifier = DCSettings.GetIDByObject(KDNode);
	
	If TreeRow.Type = "Settings" Then
		TreeRow.HasStructure = True;
		TreeRow.HasFieldsAndDesign = True;
	ElsIf TreeRow.Type = "Group"
		Or TreeRow.Type = "ChartGrouping"
		Or TreeRow.Type = "TableGrouping" Then
		TreeRow.HasStructure = True;
		TreeRow.HasFieldsAndDesign = True;
	ElsIf TreeRow.Type = "Table" Then
		TreeRow.HasFieldsAndDesign = True;
	ElsIf TreeRow.Type = "Chart" Then
		TreeRow.HasFieldsAndDesign = True;
	ElsIf TreeRow.Type = "StructureTableItemsCollection"
		Or TreeRow.Type = "ChartStructureItemsCollection"
		Or TreeRow.Type = "NestedObjectSettings" Then
		// see next.
	Else
		Return TreeRow;
	EndIf;
	
	FillSettingPresentation(TreeRow, False);
	
	If TreeRow.HasFieldsAndDesign Then
		TreeRow.Title = TitlesFromOutputParameters(KDNode.OutputParameters);
	EndIf;
	
	If Not Information.OnlyCustom Then
		TreeRow.OutputAllowed = (TreeRow.DCIdentifier = Information.CurrentCDHostIdentifier);
	EndIf;
	
	If TypeOf(TreeRow.ID) = Type("String") AND Not IsBlankString(TreeRow.ID) Then
		SettingProperty = Information.Search.UserSettings.Get(TreeRow.ID);
		If SettingProperty <> Undefined Then
			TreeRow.UserSetting   = SettingProperty;
			TreeRow.DCUsersSetting = SettingProperty.DCUsersSetting;
			RegisterCustomSetting(Information, SettingProperty, TreeRow, Undefined);
			If Information.OnlyCustom Then
				TreeRow.OutputAllowed = SettingProperty.OutputAllowed;
			EndIf;
		EndIf;
	EndIf;
	
	If TreeRow.HasStructure Then
		For Each NestedItem IN KDNode.Structure Do
			TreeVariantRegisterNode(Information, DCSettings, NestedItem, TreeRow.Rows);
		EndDo;
	EndIf;
	
	If TreeRow.Type = "Table" Then
		TreeVariantRegisterNode(Information, DCSettings, KDNode.Rows, TreeRow.Rows, "RowTable");
		TreeVariantRegisterNode(Information, DCSettings, KDNode.Columns, TreeRow.Rows, "ColumnTable");
	ElsIf TreeRow.Type = "Chart" Then
		TreeVariantRegisterNode(Information, DCSettings, KDNode.Points, TreeRow.Rows, "PointChart");
		TreeVariantRegisterNode(Information, DCSettings, KDNode.Series, TreeRow.Rows, "SeriesChart");
	ElsIf TreeRow.Type = "StructureTableItemsCollection"
		Or TreeRow.Type = "ChartStructureItemsCollection" Then
		For Each NestedItem IN KDNode Do
			TreeVariantRegisterNode(Information, DCSettings, NestedItem, TreeRow.Rows);
		EndDo;
	ElsIf TreeRow.Type = "NestedObjectSettings" Then
		TreeVariantRegisterNode(Information, DCSettings, KDNode.Settings, TreeRow.Rows);
	EndIf;
	
	Return TreeRow;
EndFunction

Function TitlesFromOutputParameters(OutputParameters)
	OutputKDTitle = OutputParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If OutputKDTitle = Undefined Then
		Return "";
	EndIf;
	If OutputKDTitle.Use = True
		AND OutputKDTitle.Value = DataCompositionTextOutputType.DontOutput Then
		Return "";
	EndIf;
	// IN the Auto value it is considered that the title is displayed.
	// When the OutputTitle parameter is disabled, it is an equivalent to the Auto value.
	DCTitle = OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If DCTitle = Undefined Then
		Return "";
	EndIf;
	Return DCTitle.Value;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Variant settings

Function VariantSettingsTable()
	Result = New ValueTree;
	
	// DLS nodes.
	Result.Columns.Add("KDItem");
	Result.Columns.Add("AvailableKDSetting");
	Result.Columns.Add("DCUsersSetting");
	
	// Applied structure.
	Result.Columns.Add("TreeRow");
	Result.Columns.Add("UserSetting");
	Result.Columns.Add("Owner");
	Result.Columns.Add("Global", New TypeDescription("Boolean"));
	
	// Search this setting in node.
	Result.Columns.Add("CollectionName", New TypeDescription("String"));
	Result.Columns.Add("DCIdentifier");
	
	// Link to DLS nodes.
	Result.Columns.Add("ID", New TypeDescription("String"));
	Result.Columns.Add("ItemIdentificator", New TypeDescription("String"));
	
	// Setting description.
	Result.Columns.Add("Type", New TypeDescription("String"));
	Result.Columns.Add("Subtype", New TypeDescription("String"));
	
	Result.Columns.Add("DCField");
	Result.Columns.Add("Value");
	Result.Columns.Add("ComparisonType");
	Result.Columns.Add("EnterByList", New TypeDescription("Boolean"));
	Result.Columns.Add("TypeInformation");
	
	Result.Columns.Add("MarkedValues");
	Result.Columns.Add("ChoiceParameters");
	
	Result.Columns.Add("TypeLink");
	Result.Columns.Add("ChoiceParameterLinks");
	Result.Columns.Add("LinksByMetadata");
	Result.Columns.Add("TypeRestriction");
	
	// API
	Result.Columns.Add("TypeDescription");
	Result.Columns.Add("ValuesForSelection");
	Result.Columns.Add("SelectionValueQuery");
	Result.Columns.Add("LimitChoiceWithSpecifiedValues", New TypeDescription("Boolean"));
	
	// Output.
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("OutputAllowed", New TypeDescription("Boolean"));
	Result.Columns.Add("DisplayCheckbox", New TypeDescription("Boolean"));
	Result.Columns.Add("ChoiceFoldersAndItems");
	
	Return Result;
EndFunction

Function UserSettingsTable()
	Result = New ValueTable;
	
	// DLS nodes.
	Result.Columns.Add("KDNode");
	Result.Columns.Add("KDVariantSetting");
	Result.Columns.Add("DCUsersSetting");
	Result.Columns.Add("AvailableKDSetting");
	
	// Applied structure.
	Result.Columns.Add("TreeRow");
	Result.Columns.Add("VariantSetting");
	
	// Search this setting in node.
	Result.Columns.Add("DCIdentifier");
	Result.Columns.Add("IndexInCollection", New TypeDescription("Number"));
	
	// Link to DLS nodes.
	Result.Columns.Add("ID", New TypeDescription("String"));
	Result.Columns.Add("ItemIdentificator", New TypeDescription("String"));
	
	// Setting description.
	Result.Columns.Add("Type", New TypeDescription("String"));
	Result.Columns.Add("Subtype", New TypeDescription("String"));
	
	Result.Columns.Add("DCField");
	Result.Columns.Add("Value");
	Result.Columns.Add("ComparisonType");
	Result.Columns.Add("EnterByList", New TypeDescription("Boolean"));
	Result.Columns.Add("TypeInformation");
	
	Result.Columns.Add("MarkedValues");
	Result.Columns.Add("ChoiceParameters");
	
	// API
	Result.Columns.Add("TypeDescription");
	Result.Columns.Add("ValuesForSelection");
	Result.Columns.Add("SelectionValueQuery");
	Result.Columns.Add("LimitChoiceWithSpecifiedValues", New TypeDescription("Boolean"));
	
	// Output.
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("Quick", New TypeDescription("Boolean"));
	Result.Columns.Add("Ordinary", New TypeDescription("Boolean"));
	Result.Columns.Add("OutputAllowed", New TypeDescription("Boolean"));
	Result.Columns.Add("DisplayCheckbox", New TypeDescription("Boolean"));
	Result.Columns.Add("DisplayOnlyCheckBox", New TypeDescription("Boolean"));
	
	Result.Columns.Add("ItemsType", New TypeDescription("String"));
	Result.Columns.Add("ChoiceFoldersAndItems");
	
	// Additional properties.
	Result.Columns.Add("Additionally", New TypeDescription("Structure"));
	
	Return Result;
EndFunction

Function TypeRelationsTable()
	// Link from DLS.
	TypeRelationsTable = New ValueTable;
	TypeRelationsTable.Columns.Add("Leading");
	TypeRelationsTable.Columns.Add("LeadingFieldDC");
	TypeRelationsTable.Columns.Add("subordinated");
	TypeRelationsTable.Columns.Add("SubordinateNameParameter");
	
	Return TypeRelationsTable;
EndFunction

Function LinksTableOfSelectionParameters()
	LinksTableOfSelectionParameters = New ValueTable;
	LinksTableOfSelectionParameters.Columns.Add("Leading");
	LinksTableOfSelectionParameters.Columns.Add("LeadingFieldDC");
	LinksTableOfSelectionParameters.Columns.Add("subordinated");
	LinksTableOfSelectionParameters.Columns.Add("SubordinateNameParameter");
	LinksTableOfSelectionParameters.Columns.Add("Action");
	
	Return LinksTableOfSelectionParameters;
EndFunction

Function LinkTableMetadataObjects(ReportSettings)
	// Link from metadata.
	Result = New ValueTable;
	Result.Columns.Add("LeadingType",          New TypeDescription("Type"));
	Result.Columns.Add("SubordinatedType",      New TypeDescription("Type"));
	Result.Columns.Add("SubordinatedAttribute", New TypeDescription("String"));
	
	// Extension mechanisms.
	ReportsOverridable.SupplementMetadataObjectsLinks(Result); // Global links...
	If ReportSettings.Events.SupplementMetadataObjectsLinks Then // ... can override locally for report.
		ReportObject = ReportObject(ReportSettings);
		ReportObject.SupplementMetadataObjectsLinks(Result);
	EndIf;
	
	Result.Columns.Add("IsLeading",     New TypeDescription("Boolean"));
	Result.Columns.Add("AreSubordinates", New TypeDescription("Boolean"));
	Result.Columns.Add("Leading",     New TypeDescription("Array"));
	Result.Columns.Add("Subordinate", New TypeDescription("Array"));
	Result.Columns.Add("LeadingFullName",     New TypeDescription("String"));
	Result.Columns.Add("SubordinateFullName", New TypeDescription("String"));
	
	Return Result;
EndFunction

Procedure RegisterVariantSettings(DCSettings, Information)
	VariantTree = Information.VariantTree;
	VariantSettings = Information.VariantSettings;
	
	Found = VariantTree.Rows.FindRows(New Structure("HasStructure", True), True);
	For Each TreeRow IN Found Do
		
		// Settings,
		// property Filter Grouping,
		// property Filter TableGrouping Filter.
		// ChartGrouping, the Filter property.
		
		// Settings, Filter property.Items.
		// Grouping, Filter property.Items
		// TableGrouping, the Selection property.Items
		// ChartGrouping, the Selection property.Items.
		
		RegisterSettingsNode(DCSettings, Information, TreeRow, "Filter");
		
		// Settings, Order property.
		// Grouping,
		// the Order TableGrouping property, the Order property.
		// ChartGrouping, the Order property.
		
		RegisterSettingsNode(DCSettings, Information, TreeRow, "Order");
		
		// Settings, the Structure property.
		// Grouping, the Structure property.
		// TableGrouping, the Structure property.
		// ChartGrouping, the Structure property.
		
		RegisterSettingsNode(DCSettings, Information, TreeRow, "Structure");
		
	EndDo;
	
	Found = VariantTree.Rows.FindRows(New Structure("HasFieldsAndDesign", True), True);
	For Each TreeRow IN Found Do
		
		// Settings, the
		// Selection Table property,
		// the Selection Chart
		// property, the Selection
		// Chart property, the Selection Grouping property, the Selection ChartGrouping property, the Selection propert.
		// TableGrouping, the Selection property.
		
		RegisterSettingsNode(DCSettings, Information, TreeRow, "Selection");
		
		// Settings, the ConditionalDesign property.
		// Table, the ConditionalDesign property.
		// Chart, the ConditionalDesign property.
		// Grouping, the ConditionalDesign property.
		// ChartGrouping, the ConditionalDesign property.
		// TableGrouping, the ConditionalDesign property.
		
		// Settings, the ConditionalDesign property.Items.
		// Table, the ConditionalDesign property.Items.
		// Chart, the ConditionalDesign property.Items.
		// Grouping, the ConditionalDesign property.Items
		// ChartGrouping, the ConditionalDesign property.Items
		// TableGrouping, the ConditionalDesign property.Items.
		
		RegisterSettingsNode(DCSettings, Information, TreeRow, "ConditionalAppearance");
		
	EndDo;
	
	Found = VariantTree.Rows.FindRows(New Structure("Global", True), True);
	For Each TreeRow IN Found Do
		
		// Settings, the DataParameters property, the FindParameterValue() method.
		
		RegisterSettingsNode(DCSettings, Information, TreeRow, "DataParameters");
		
	EndDo;
	
EndProcedure

Procedure RegisterSettingsNode(DCSettings, Information, TreeRow, CollectionName, SetElements = Undefined, Parent = Undefined, Owner = Undefined)
	KDNode = TreeRow.KDNode[CollectionName];
	
	Owner = Information.VariantSettings.Rows.Add();
	Owner.TreeRow = TreeRow;
	If CollectionName <> "DataParameters" Then
		Owner.ID = KDNode.UserSettingID;
	EndIf;
	Owner.Type           = ReportsClientServer.RowSettingType(TypeOf(KDNode));
	Owner.CollectionName  = CollectionName;
	Owner.Global    = TreeRow.Global;
	Owner.KDItem     = KDNode;
	Owner.OutputAllowed = Not Information.OnlyCustom AND TreeRow.OutputAllowed;
	
	If TypeOf(Owner.ID) = Type("String") AND Not IsBlankString(Owner.ID) Then
		SettingProperty = Information.Search.UserSettings.Get(Owner.ID);
		If SettingProperty <> Undefined Then
			Owner.UserSetting = SettingProperty;
			RegisterCustomSetting(Information, SettingProperty, Undefined, Owner);
			If Information.OnlyCustom Then
				Owner.OutputAllowed = SettingProperty.OutputAllowed;
			EndIf;
		EndIf;
	EndIf;
	
	If CollectionName = "Filter"
		Or CollectionName = "DataParameters"
		Or CollectionName = "ConditionalAppearance" Then
		RegisterSubordinatedSettingsItems(Information, KDNode, KDNode.Items, Owner, Owner);
	EndIf;
EndProcedure

Procedure RegisterSubordinatedSettingsItems(Information, KDNode, SetElements, Owner, Parent)
	For Each KDItem IN SetElements Do
		VariantSetting = Parent.Rows.Add();
		FillPropertyValues(VariantSetting, Owner, "TreeRow, CollectionName, Global");
		VariantSetting.ID = KDItem.UserSettingID;
		VariantSetting.Type = ReportsClientServer.RowSettingType(TypeOf(KDItem));
		VariantSetting.DCIdentifier = KDNode.GetIDByObject(KDItem);
		VariantSetting.Owner = Owner;
		VariantSetting.KDItem = KDItem;
		VariantSetting.OutputAllowed = Not Information.OnlyCustom AND Owner.OutputAllowed;
		
		If VariantSetting.Type = "FilterItem"
			Or VariantSetting.Type = "SettingsParameterValue" Then
			RegisterField(Information, KDNode, KDItem, VariantSetting);
			If VariantSetting.AvailableKDSetting = Undefined Then
				VariantSetting.OutputAllowed = False;
				Continue;
			EndIf;
		EndIf;
		
		SettingProperty = Undefined;
		If TypeOf(VariantSetting.ID) = Type("String") AND Not IsBlankString(VariantSetting.ID) Then
			SettingProperty = Information.Search.UserSettings.Get(VariantSetting.ID);
		EndIf;
		If SettingProperty <> Undefined Then
			VariantSetting.UserSetting = SettingProperty;
			RegisterCustomSetting(Information, SettingProperty, Undefined, VariantSetting);
			If Information.OnlyCustom Then
				VariantSetting.OutputAllowed = SettingProperty.OutputAllowed;
				VariantSetting.Value      = SettingProperty.Value;
				VariantSetting.ComparisonType  = SettingProperty.ComparisonType;
			EndIf;
		EndIf;
		
		If VariantSetting.Type = "FilterItem" Then
			RegisterTypesAndLinks(Information, KDNode, KDItem, VariantSetting);
		ElsIf VariantSetting.Type = "FilterItemGroup" Then
			VariantSetting.Value = KDItem.GroupType;
			RegisterSubordinatedSettingsItems(Information, KDNode, KDItem.Items, Owner, VariantSetting);
		ElsIf VariantSetting.Type = "SettingsParameterValue" Then
			RegisterTypesAndLinks(Information, KDNode, KDItem, VariantSetting);
			RegisterSubordinatedSettingsItems(Information, KDNode, KDItem.NestedParameterValues, Owner, VariantSetting);
		EndIf;
		
		If SettingProperty <> Undefined Then
			SettingProperty.TypeDescription      = VariantSetting.TypeDescription;
			SettingProperty.TypeInformation   = VariantSetting.TypeInformation;
			SettingProperty.ValuesForSelection  = VariantSetting.ValuesForSelection;
			SettingProperty.ChoiceParameters    = VariantSetting.ChoiceParameters;
			SettingProperty.LimitChoiceWithSpecifiedValues = VariantSetting.LimitChoiceWithSpecifiedValues;
		EndIf;
	EndDo;
EndProcedure

Procedure RegisterField(Information, KDNode, KDItem, VariantSetting)
	If IsBlankString(VariantSetting.ID) Then
		ID = String(VariantSetting.TreeRow.DCIdentifier);
		If Not IsBlankString(ID) Then
			ID = ID + "_";
		EndIf;
		VariantSetting.ID = ID + VariantSetting.CollectionName + "_" + String(VariantSetting.DCIdentifier);
	EndIf;
	VariantSetting.ItemIdentificator = ReportsClientServer.AdjustIDToName(VariantSetting.ID);
	
	If VariantSetting.Type = "SettingsParameterValue" Then
		AvailableParameters = KDNode.AvailableParameters;
		If AvailableParameters = Undefined Then
			Return;
		EndIf;
		AvailableKDSetting = AvailableParameters.FindParameter(KDItem.Parameter);
		If AvailableKDSetting = Undefined Then
			Return;
		EndIf;
		// QuickSelection, SelectGroupsAndItems, ValuesListAvailables,
		// AvailableValues, BlockUnfilledValues, Usage, Mask, ConnectionByType, ChoiceForm EditFormat.
		If Not AvailableKDSetting.Visible Then
			VariantSetting.OutputAllowed = False;
		EndIf;
		VariantSetting.AvailableKDSetting = AvailableKDSetting;
		VariantSetting.DCField = New DataCompositionField("DataParameters." + String(KDItem.Parameter));
		VariantSetting.Value = KDItem.Value;
		If AvailableKDSetting.ValueListAllowed Then
			VariantSetting.ComparisonType = DataCompositionComparisonType.InList;
		Else
			VariantSetting.ComparisonType = DataCompositionComparisonType.Equal;
		EndIf;
	Else
		FilterAvailableFields = KDNode.FilterAvailableFields;
		If FilterAvailableFields = Undefined Then
			Return;
		EndIf;
		AvailableKDSetting = FilterAvailableFields.FindField(KDItem.LeftValue);
		If AvailableKDSetting = Undefined Then
			Return;
		EndIf;
		VariantSetting.AvailableKDSetting = AvailableKDSetting;
		VariantSetting.DCField       = KDItem.LeftValue;
		VariantSetting.Value     = KDItem.RightValue;
		VariantSetting.ComparisonType = KDItem.ComparisonType;
	EndIf;
	
	If VariantSetting.ComparisonType = DataCompositionComparisonType.InList
		Or VariantSetting.ComparisonType = DataCompositionComparisonType.InListByHierarchy
		Or VariantSetting.ComparisonType = DataCompositionComparisonType.NotInList
		Or VariantSetting.ComparisonType = DataCompositionComparisonType.NotInListByHierarchy Then
		VariantSetting.EnterByList = True;
		VariantSetting.ChoiceFoldersAndItems = FoldersAndItems.FoldersAndItems;
	ElsIf VariantSetting.ComparisonType = DataCompositionComparisonType.InHierarchy
		Or VariantSetting.ComparisonType = DataCompositionComparisonType.NotInHierarchy Then
		VariantSetting.ChoiceFoldersAndItems = FoldersAndItems.Folders;
	Else
		VariantSetting.ChoiceFoldersAndItems = ReportsClientServer.AdjustValueToGroupsAndItemsType(AvailableKDSetting.ChoiceFoldersAndItems);
	EndIf;
	
	VariantSetting.TypeDescription = AvailableKDSetting.ValueType;
	
	Information.Search.VariantSettingsByKDField.Insert(VariantSetting.DCField, VariantSetting);
	
	VariantSetting.DisplayCheckbox = True;
	If (VariantSetting.Type = "SettingsParameterValue"
			AND AvailableKDSetting.Use = DataCompositionParameterUse.Always)
		Or VariantSetting.Type = "SelectedFields"
		Or VariantSetting.Type = "Order"
		Or VariantSetting.Type = "StructureTableItemsCollection"
		Or VariantSetting.Type = "ChartStructureItemsCollection"
		Or VariantSetting.Type = "Filter"
		Or VariantSetting.Type = "ConditionalAppearance"
		Or VariantSetting.Type = "SettingsStructure" Then
		VariantSetting.DisplayCheckbox = False;
	EndIf;
	
EndProcedure

Procedure RegisterTypesAndLinks(Information, KDNode, KDItem, VariantSetting)
	
	///////////////////////////////////////////////////////////////////
	// Information about types.
	
	VariantSetting.LinksByMetadata     = New Array;
	VariantSetting.ChoiceParameterLinks = New Array;
	VariantSetting.ChoiceParameters       = New Array;
	
	If VariantSetting.EnterByList Then
		VariantSetting.MarkedValues = ReportsClientServer.ValueList(VariantSetting.Value);
	EndIf;
	VariantSetting.ValuesForSelection = New ValueList;
	VariantSetting.SelectionValueQuery = New Query;
	
	EnumerationQueryTemplate = "SELECT Refs IN &EnumerationName";
	ValuesQueryText = "";
	
	TypeInformation = ReportsClientServer.TypesAnalysis(VariantSetting.TypeDescription, True);
	TypeInformation.Insert("ContainsReferenceTypes", False);
	TypeInformation.Insert("EnumsQuantity",         0);
	TypeInformation.Insert("OtherReferenceTypesQuantity", 0);
	TypeInformation.Insert("Enums",        New Array);
	TypeInformation.Insert("OtherReferentialTypes", New Array);
	For Each Type IN TypeInformation.ObjectiveTypes Do
		DescriptionFull = Information.MapMetadataObjectName.Get(Type);
		If DescriptionFull = Undefined Then // Name of the metadata object registration.
			MetadataObject = Metadata.FindByType(Type);
			If MetadataObject = Undefined Then
				DescriptionFull = -1;
			Else
				DescriptionFull = MetadataObject.FullName();
			EndIf;
			Information.MapMetadataObjectName.Insert(Type, DescriptionFull);
		EndIf;
		If DescriptionFull = -1 Then
			Continue;
		EndIf;
		
		TypeInformation.ContainsReferenceTypes = True;
		
		If Upper(Left(DescriptionFull, 13)) = "ENUM." Then
			TypeInformation.Enums.Add(DescriptionFull);
			TypeInformation.EnumsQuantity = TypeInformation.EnumsQuantity + 1;
			If ValuesQueryText <> "" Then
				ValuesQueryText = ValuesQueryText + Chars.LF + Chars.LF + "UNION ALL" + Chars.LF + Chars.LF;
			EndIf;
			ValuesQueryText = ValuesQueryText + StrReplace(EnumerationQueryTemplate, "&EnumerationName", DescriptionFull);
		Else
			TypeInformation.OtherReferentialTypes.Add(DescriptionFull);
			TypeInformation.OtherReferenceTypesQuantity = TypeInformation.OtherReferenceTypesQuantity + 1;
		EndIf;
		
		// Search for the type in the global links among subordinates.
		Found = Information.Links.MetadataObjects.FindRows(New Structure("SubordinatedType", Type));
		For Each LinkByMetadata IN Found Do // Register setting as subordinate.
			LinkByMetadata.AreSubordinates = True;
			LinkByMetadata.Subordinate.Add(VariantSetting);
		EndDo;
		
		// Search for a type in the global links among the leading.
		If VariantSetting.ComparisonType = DataCompositionComparisonType.Equal Then
			// Field can be leading if it has the Equals comparison kind.
			Found = Information.Links.MetadataObjects.FindRows(New Structure("LeadingType", Type));
			For Each LinkByMetadata IN Found Do // Registration of setting as a leading one.
				LinkByMetadata.IsLeading = True;
				LinkByMetadata.Leading.Add(VariantSetting);
			EndDo;
		EndIf;
		
	EndDo;
	
	VariantSetting.TypeInformation = TypeInformation;
	
	///////////////////////////////////////////////////////////////////
	// Information about links and selection parameters.
	
	AvailableKDSetting = VariantSetting.AvailableKDSetting;
	
	If ValueIsFilled(AvailableKDSetting.TypeLink) Then
		LinkString = Information.Links.ByType.Add();
		LinkString.subordinated   = VariantSetting;
		LinkString.LeadingFieldDC = AvailableKDSetting.TypeLink.Field;
		LinkString.SubordinateNameParameter = AvailableKDSetting.TypeLink.LinkItem;
	EndIf;
	
	For Each LinkString IN AvailableKDSetting.GetChoiceParameterLinks() Do
		If IsBlankString(String(LinkString.Field)) Then
			Continue;
		EndIf;
		ParametersLinkString = Information.Links.ParametersSelect.Add();
		ParametersLinkString.subordinated             = VariantSetting;
		ParametersLinkString.SubordinateNameParameter = LinkString.Name;
		ParametersLinkString.LeadingFieldDC           = LinkString.Field;
		ParametersLinkString.Action                = LinkString.ValueChange;
	EndDo;
	
	For Each DCChoiceParameter IN AvailableKDSetting.GetChoiceParameters() Do
		VariantSetting.ChoiceParameters.Add(New ChoiceParameter(DCChoiceParameter.Name, DCChoiceParameter.Value));
	EndDo;
	
	///////////////////////////////////////////////////////////////////
	// Values list.
	
	If TypeOf(AvailableKDSetting.AvailableValues) = Type("ValueList")
		AND AvailableKDSetting.AvailableValues.Count() > 0 Then
		// Developer restricted the selection with available values list.
		VariantSetting.LimitChoiceWithSpecifiedValues = True;
		For Each ItemOfList IN AvailableKDSetting.AvailableValues Do
			ValueInDAS = ItemOfList.Value;
			If Not ValueIsFilled(ItemOfList.Presentation)
				AND (ValueInDAS = Undefined
					Or ValueInDAS = Type("Undefined")
					Or ValueInDAS = New TypeDescription("Undefined")
					Or Not ValueIsFilled(ValueInDAS)) Then
				Continue; // Prevent null values.
			EndIf;
			If TypeOf(ValueInDAS) = Type("Type") Then
				TypeArray = New Array;
				TypeArray.Add(ValueInDAS);
				ValueInForm = New TypeDescription(TypeArray);
			Else
				ValueInForm = ValueInDAS;
			EndIf;
			ReportsClientServer.AddUniqueValueInList(VariantSetting.ValuesForSelection, ValueInForm, ItemOfList.Presentation, False);
		EndDo;
	Else
		PreviouslySavedSettings = Information.AdditionalItemsSettings[VariantSetting.ItemIdentificator];
		If PreviouslySavedSettings <> Undefined
			AND CommonUseClientServer.StructureProperty(PreviouslySavedSettings, "LimitChoiceWithSpecifiedValues") = False Then
			OldValuesForSelection  = CommonUseClientServer.StructureProperty(PreviouslySavedSettings, "ValuesForSelection");
			OldTypeDescription      = CommonUseClientServer.StructureProperty(PreviouslySavedSettings, "TypeDescription");
			If TypeOf(OldValuesForSelection) = Type("ValueList") AND TypeOf(OldTypeDescription) = Type("TypeDescription") Then
				ControlType = Not TypeDescriptionsMatch(VariantSetting.TypeDescription, OldTypeDescription);
				VariantSetting.ValuesForSelection.ValueType = VariantSetting.TypeDescription;
				ReportsClientServer.ExpandList(VariantSetting.ValuesForSelection, OldValuesForSelection, ControlType);
			EndIf;
		EndIf;
		
		VariantSetting.SelectionValueQuery.Text = ValuesQueryText;
		If TypeInformation.EnumsQuantity = TypeInformation.TypeCount Then
			VariantSetting.LimitChoiceWithSpecifiedValues = True; // Only enumerations.
		EndIf;
	EndIf;
	
	// Extension mechanisms.
	// Global settings of types output.
	ReportsOverridable.OnDefineSelectionParameters(Undefined, VariantSetting);
	// Local override for report.
	If Information.ReportSettings.Events.OnDefineSelectionParameters Then
		ReportObject = ReportObject(Information.ReportSettings);
		ReportObject.OnDefineSelectionParameters(Undefined, VariantSetting);
	EndIf;
	
	// Automatic filling.
	If VariantSetting.SelectionValueQuery.Text <> "" Then
		AddedValues = VariantSetting.SelectionValueQuery.Execute().Unload().UnloadColumn(0);
		For Each ValueInForm IN AddedValues Do
			ReportsClientServer.AddUniqueValueInList(VariantSetting.ValuesForSelection, ValueInForm, Undefined, False);
		EndDo;
		VariantSetting.ValuesForSelection.SortByPresentation(SortDirection.Asc);
	EndIf;
	
EndProcedure

Procedure RegisterLinksFromLeading(Information)
	Links = Information.Links;
	
	// Registration of the selection parameters registration (dynamic connection disabled with the Use check box).
	Found = Links.MetadataObjects.FindRows(New Structure("AreSubordinates, IsLeading", True, True));
	For Each LinkByMetadata IN Found Do
		For Each Leading IN LinkByMetadata.Leading Do
			For Each subordinated IN LinkByMetadata.Subordinate Do
				If Leading.OutputAllowed Then // Disabled link.
					LinkDescription = New Structure;
					LinkDescription.Insert("LinkType",                "ByMetadata");
					LinkDescription.Insert("Leading",                 Leading);
					LinkDescription.Insert("subordinated",             subordinated);
					LinkDescription.Insert("LeadingType",              LinkByMetadata.LeadingType);
					LinkDescription.Insert("SubordinatedType",          LinkByMetadata.SubordinatedType);
					LinkDescription.Insert("SubordinateNameParameter", LinkByMetadata.SubordinatedAttribute);
					Information.DisabledLinks.Add(LinkDescription);
					subordinated.LinksByMetadata.Add(LinkDescription);
				Else // Fixed selection parameter.
					subordinated.ChoiceParameters.Add(New ChoiceParameter(LinkByMetadata.SubordinatedAttribute, Leading.Value));
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	// Links by type.
	For Each TypeLink IN Links.ByType Do
		Leading = Information.Search.VariantSettingsByKDField.Get(TypeLink.LeadingFieldDC);
		If Leading = Undefined Then
			Continue;
		EndIf;
		subordinated = TypeLink.subordinated;
		If Leading.OutputAllowed Then // Disabled link.
			LinkDescription = New Structure;
			LinkDescription.Insert("LinkType",                "ByType");
			LinkDescription.Insert("Leading",                 Leading);
			LinkDescription.Insert("subordinated",             subordinated);
			LinkDescription.Insert("SubordinateNameParameter", TypeLink.SubordinateNameParameter);
			Information.DisabledLinks.Add(LinkDescription);
			subordinated.TypeLink = LinkDescription;
		Else // Fixed type restriction.
			TypeArray = New Array;
			TypeArray.Add(TypeOf(Leading.Value));
			subordinated.TypeRestriction = New TypeDescription(TypeArray);
		EndIf;
	EndDo;
	
	// Selection parameters links.
	For Each LinkSelectParameters IN Links.ParametersSelect Do
		Leading     = LinkSelectParameters.Leading;
		subordinated = LinkSelectParameters.subordinated;
		If Leading = Undefined Then
			BestVariant = 99;
			Found = Information.VariantSettings.Rows.FindRows(New Structure("DCField", LinkSelectParameters.LeadingFieldDC), True);
			For Each ProspectiveParent IN Found Do
				If ProspectiveParent.Parent = subordinated.Parent Then // Items in one group.
					If Not IsBlankString(ProspectiveParent.ItemIdentificator) Then // Leading is put out into custom.
						Leading = ProspectiveParent;
						BestVariant = 0;
						Break; // Best variant.
					Else
						Leading = ProspectiveParent;
						BestVariant = 1;
					EndIf;
				ElsIf BestVariant > 2 AND ProspectiveParent.Owner = subordinated.Owner Then // Items in one collection.
					If Not IsBlankString(ProspectiveParent.ItemIdentificator) Then // Leading is put out into custom.
						If BestVariant > 2 Then
							Leading = ProspectiveParent;
							BestVariant = 2;
						EndIf;
					Else
						If BestVariant > 3 Then
							Leading = ProspectiveParent;
							BestVariant = 3;
						EndIf;
					EndIf;
				ElsIf BestVariant > 4 AND ProspectiveParent.TreeRow = subordinated.TreeRow Then // Items in one node.
					If Not IsBlankString(ProspectiveParent.ItemIdentificator) Then // Leading is put out into custom.
						If BestVariant > 4 Then
							Leading = ProspectiveParent;
							BestVariant = 4;
						EndIf;
					Else
						If BestVariant > 5 Then
							Leading = ProspectiveParent;
							BestVariant = 5;
						EndIf;
					EndIf;
				ElsIf BestVariant > 6 Then
					Leading = ProspectiveParent;
					BestVariant = 6;
				EndIf;
			EndDo;
			If Leading = Undefined Then
				Continue;
			EndIf;
		EndIf;
		If Leading.OutputAllowed Then // Disabled link.
			LinkDescription = New Structure;
			LinkDescription.Insert("LinkType",      "ParametersSelect");
			LinkDescription.Insert("Leading",       Leading);
			LinkDescription.Insert("subordinated",   subordinated);
			LinkDescription.Insert("SubordinateNameParameter", LinkSelectParameters.SubordinateNameParameter);
			LinkDescription.Insert("SubordinatedAction",     LinkSelectParameters.Action);
			Information.DisabledLinks.Add(LinkDescription);
			subordinated.ChoiceParameterLinks.Add(LinkDescription);
		Else // Fixed selection parameter.
			If TypeOf(Leading.Value) = Type("DataCompositionField") Then
				Continue; // Extended work with the selections by the data layout field is not supported.
			EndIf;
			subordinated.ChoiceParameters.Add(New ChoiceParameter(LinkSelectParameters.SubordinateNameParameter, Leading.Value));
		EndIf;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// User settings

Function RegisterCustomSetting(Information, SettingProperty, TreeRow, VariantSetting)
	DCUsersSetting = SettingProperty.DCUsersSetting;
	
	ViewMode = DCUsersSetting.ViewMode;
	If ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then
		Return SettingProperty;
	EndIf;
	
	If Not ValueIsFilled(SettingProperty.ID) Then
		Return SettingProperty;
	EndIf;
	SettingProperty.ItemIdentificator = ReportsClientServer.AdjustIDToName(SettingProperty.ID);
	
	If VariantSetting <> Undefined Then
		If VariantSetting.Owner <> Undefined Then
			SettingProperty.KDNode = VariantSetting.Owner.KDItem;
		EndIf;
		SettingProperty.TreeRow         = VariantSetting.TreeRow;
		SettingProperty.KDVariantSetting  = VariantSetting.KDItem;
		SettingProperty.VariantSetting    = VariantSetting;
		SettingProperty.Subtype               = VariantSetting.Subtype;
		SettingProperty.DCField               = VariantSetting.DCField;
		SettingProperty.AvailableKDSetting = VariantSetting.AvailableKDSetting;
		If ViewMode = DataCompositionSettingsItemViewMode.Auto Then
			ViewMode = SettingProperty.KDVariantSetting.ViewMode;
		EndIf;
	Else
		SettingProperty.KDNode              = TreeRow.KDNode;
		SettingProperty.TreeRow        = TreeRow;
		SettingProperty.Type                 = TreeRow.Type;
		SettingProperty.Subtype              = TreeRow.Subtype;
		SettingProperty.KDVariantSetting = SettingProperty.KDNode;
		If ViewMode = DataCompositionSettingsItemViewMode.Auto Then
			ViewMode = SettingProperty.KDNode.ViewMode;
		EndIf;
	EndIf;
	
	If ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		SettingProperty.Quick = True;
		Information.ThereAreQuickSettings = True;
	ElsIf ViewMode = DataCompositionSettingsItemViewMode.Normal Then
		SettingProperty.Ordinary = True;
		Information.ThereAreCommonSettings = True;
	ElsIf Information.OnlyCustom Then
		Return SettingProperty;
	EndIf;
	
	// Available setting definition.
	If SettingProperty.Type = "NestedObjectSettings" Then
		SettingProperty.AvailableKDSetting = Information.DCSettings.AvailableObjects.Items.Find(SettingProperty.TreeRow.KDNode.ObjectID);
	ElsIf SettingProperty.Type = "SettingsParameterValue"
		Or SettingProperty.Type = "FilterItem" Then
		If SettingProperty.AvailableKDSetting = Undefined Then
			Return SettingProperty; // Field name was changed or field wad deleted.
		EndIf;
	EndIf;
	
	If Information.OnlyCustom Then
		If Information.OnlyQuick Then
			SettingProperty.OutputAllowed = SettingProperty.Quick;
		Else
			SettingProperty.OutputAllowed = True;
		EndIf;
	EndIf;
	
	SettingProperty.DisplayCheckbox = True;
	SettingProperty.DisplayOnlyCheckBox = False;
	
	FillSettingPresentation(SettingProperty, True);
	
	If SettingProperty.Type = "FilterItemGroup"
		Or SettingProperty.Type = "NestedObjectSettings"
		Or SettingProperty.Type = "Group"
		Or SettingProperty.Type = "Table"
		Or SettingProperty.Type = "TableGrouping"
		Or SettingProperty.Type = "Chart"
		Or SettingProperty.Type = "ChartGrouping"
		Or SettingProperty.Type = "ConditionalAppearanceItem" Then
		
		SettingProperty.DisplayOnlyCheckBox = True;
		
	ElsIf SettingProperty.Type = "SettingsParameterValue"
		Or SettingProperty.Type = "FilterItem" Then
		
		If SettingProperty.Type = "SettingsParameterValue" Then
			SettingProperty.Value = DCUsersSetting.Value;
		Else
			SettingProperty.Value = DCUsersSetting.RightValue;
		EndIf;
		
		// Definition of a setting value type.
		TypeInformation = ReportsClientServer.TypesAnalysis(SettingProperty.AvailableKDSetting.ValueType, True);
		SettingProperty.TypeInformation = TypeInformation;
		SettingProperty.TypeDescription    = TypeInformation.TypeDescriptionForForm;
		
		If SettingProperty.Type = "SettingsParameterValue" Then
			If SettingProperty.AvailableKDSetting.Use = DataCompositionParameterUse.Always Then
				SettingProperty.DisplayCheckbox = False;
				DCUsersSetting.Use = True;
			EndIf;
			If SettingProperty.AvailableKDSetting.ValueListAllowed Then
				SettingProperty.ComparisonType = DataCompositionComparisonType.InList;
			Else
				SettingProperty.ComparisonType = DataCompositionComparisonType.Equal;
			EndIf;
		ElsIf SettingProperty.Type = "FilterItem" Then
			SettingProperty.ComparisonType = DCUsersSetting.ComparisonType;
		EndIf;
		
		If SettingProperty.TypeInformation.ContainsTypePeriod
			AND SettingProperty.TypeInformation.TypeCount = 1 Then
			
			SettingProperty.ItemsType = "StandardPeriod";
			
		ElsIf Not SettingProperty.DisplayCheckbox
			AND SettingProperty.TypeInformation.ContainsTypeBoolean
			AND SettingProperty.TypeInformation.TypeCount = 1 Then
			
			SettingProperty.ItemsType = "OnlyCheckBoxValues";
			
		ElsIf SettingProperty.ComparisonType = DataCompositionComparisonType.Filled
			Or SettingProperty.ComparisonType = DataCompositionComparisonType.NotFilled Then
			
			SettingProperty.DisplayOnlyCheckBox = True;
			SettingProperty.Presentation = SettingProperty.Presentation + ": " + Lower(String(SettingProperty.ComparisonType));
			
		ElsIf SettingProperty.ComparisonType = DataCompositionComparisonType.InList
			Or SettingProperty.ComparisonType = DataCompositionComparisonType.InListByHierarchy
			Or SettingProperty.ComparisonType = DataCompositionComparisonType.NotInList
			Or SettingProperty.ComparisonType = DataCompositionComparisonType.NotInListByHierarchy Then
			
			SettingProperty.EnterByList = True;
			SettingProperty.ItemsType = "ListWithSelection";
			SettingProperty.ChoiceFoldersAndItems = FoldersAndItems.FoldersAndItems;
			
		Else
			
			SettingProperty.ItemsType = "LinkWithLinker";
			If SettingProperty.ComparisonType <> DataCompositionComparisonType.Equal
				AND SettingProperty.ComparisonType <> DataCompositionComparisonType.Contains
				AND Not SettingProperty.DisplayOnlyCheckBox Then
				SettingProperty.Presentation = SettingProperty.Presentation + " (" + Lower(String(SettingProperty.ComparisonType)) + ")";
			EndIf;
			If SettingProperty.ComparisonType = DataCompositionComparisonType.InHierarchy
				Or SettingProperty.ComparisonType = DataCompositionComparisonType.NotInHierarchy Then
				SettingProperty.ChoiceFoldersAndItems = FoldersAndItems.Folders;
			EndIf;
			
		EndIf;
		
		If SettingProperty.ChoiceFoldersAndItems = Undefined Then
			SettingProperty.ChoiceFoldersAndItems = VariantSetting.ChoiceFoldersAndItems;
		EndIf;
		
	ElsIf SettingProperty.Type = "SelectedFields"
		Or SettingProperty.Type = "Order"
		Or SettingProperty.Type = "StructureTableItemsCollection"
		Or SettingProperty.Type = "ChartStructureItemsCollection"
		Or SettingProperty.Type = "Filter"
		Or SettingProperty.Type = "ConditionalAppearance"
		Or SettingProperty.Type = "SettingsStructure" Then
		
		SettingProperty.ItemsType = "LinkWithLinker";
		SettingProperty.DisplayCheckbox = False;
		
	Else
		
		SettingProperty.ItemsType = "LinkWithLinker";
		
	EndIf;
	
	If SettingProperty.DisplayOnlyCheckBox Then
		SettingProperty.ItemsType = "";
	ElsIf SettingProperty.Quick AND SettingProperty.ItemsType = "ListWithSelection" Then
		SettingProperty.ItemsType = "LinkWithLinker";
	EndIf;
	
	Return SettingProperty;
EndFunction

Procedure FillSettingPresentation(SettingProperty, IsCustomSetting)
	ItemHeader = "";
	If IsCustomSetting Then
		KDVariantSetting = SettingProperty.KDVariantSetting;
		DCUsersSetting = SettingProperty.DCUsersSetting;
		AvailableKDSetting = SettingProperty.AvailableKDSetting;
	Else
		KDVariantSetting = SettingProperty.KDNode;
		DCUsersSetting = KDVariantSetting;
		AvailableKDSetting = Undefined;
	EndIf;
	
	PresentationsStructure = New Structure("Presentation, UserSettingPresentation", "", "");
	FillPropertyValues(PresentationsStructure, KDVariantSetting);
	
	SettingProperty.DisplayOnlyCheckBox = ValueIsFilled(PresentationsStructure.Presentation);
	
	If ValueIsFilled(PresentationsStructure.UserSettingPresentation) Then
		
		ItemHeader = PresentationsStructure.UserSettingPresentation;
		
	ElsIf ValueIsFilled(PresentationsStructure.Presentation) AND PresentationsStructure.Presentation <> "1" Then
		
		ItemHeader = PresentationsStructure.Presentation;
		
	ElsIf AvailableKDSetting <> Undefined AND ValueIsFilled(AvailableKDSetting.Title) Then
		
		ItemHeader = AvailableKDSetting.Title;
		
	EndIf;
	
	// By default presentation.
	If Not ValueIsFilled(ItemHeader) Then
		
		If ValueIsFilled(SettingProperty.Subtype) Then
			
			If SettingProperty.Subtype = "SeriesChart" Then
				
				ItemHeader = NStr("en = 'Series'");
				
			ElsIf SettingProperty.Subtype = "PointChart" Then
				
				ItemHeader = NStr("en = 'Points'");
				
			ElsIf SettingProperty.Subtype = "RowTable" Then
				
				ItemHeader = NStr("en = 'Rows'");
				
			ElsIf SettingProperty.Subtype = "ColumnTable" Then
				
				ItemHeader = NStr("en = 'Columns'");
				
			Else
				
				ItemHeader = String(SettingProperty.Subtype);
				
			EndIf;
			
		ElsIf SettingProperty.Type = "Filter" Then
			
			ItemHeader = NStr("en = 'Filter'");
			
		ElsIf SettingProperty.Type = "FilterItemGroup" Then
			
			ItemHeader = String(DCUsersSetting.GroupType);
			
		ElsIf SettingProperty.Type = "FilterItem" Then
			
			ItemHeader = String(KDVariantSetting.LeftValue);
			
		ElsIf SettingProperty.Type = "Order" Then
			
			ItemHeader = NStr("en = 'Sort'");
			
		ElsIf SettingProperty.Type = "SelectedFields" Then
			
			ItemHeader = NStr("en = 'Fields'");
			
		ElsIf SettingProperty.Type = "ConditionalAppearance" Then
			
			ItemHeader = NStr("en = 'Appearance'");
			
		ElsIf SettingProperty.Type = "ConditionalAppearanceItem" Then
			
			DesignPresentation = String(DCUsersSetting.Appearance);
			If DesignPresentation = "" Then
				ItemHeader = NStr("en = 'Not arrange'");
			Else
				ItemHeader = DesignPresentation;
			EndIf;
			
			FieldsPresentation = String(DCUsersSetting.Fields);
			If FieldsPresentation = "" Then
				ItemHeader = ItemHeader + " / " + NStr("en = 'All fields'");
			Else
				ItemHeader = ItemHeader + " / " + NStr("en = 'Fields:'") + " " + FieldsPresentation;
			EndIf;
			
			FilterPresentation = FilterPresentation(DCUsersSetting.Filter);
			If FilterPresentation <> "" Then
				ItemHeader = ItemHeader + " / " + NStr("en = 'Condition:'") + " " + FilterPresentation;
			EndIf;
			
		ElsIf SettingProperty.Type = "SettingsParameterValue" Then
			
			ItemHeader = String(KDVariantSetting.Parameter);
			
		ElsIf SettingProperty.Type = "Group"
			Or SettingProperty.Type = "TableGrouping"
			Or SettingProperty.Type = "ChartGrouping" Then
			
			GroupFields = KDVariantSetting.GroupFields;
			If GroupFields.Items.Count() = 0 Then
				ItemHeader = NStr("en = '<Detailed records>'");
			Else
				ItemHeader = TrimAll(String(GroupFields));
			EndIf;
			If IsBlankString(ItemHeader) Then
				ItemHeader = NStr("en = 'Group'");
			EndIf;
			
		ElsIf SettingProperty.Type = "Table" Then
			
			ItemHeader = NStr("en = 'Table'");
			
		ElsIf SettingProperty.Type = "Chart" Then
			
			ItemHeader = NStr("en = 'Chart'");
			
		ElsIf SettingProperty.Type = "NestedObjectSettings" Then
			
			ItemHeader = String(DCUsersSetting);
			If IsBlankString(ItemHeader) Then
				ItemHeader = NStr("en = 'Nested group'");
			EndIf;
			
		ElsIf SettingProperty.Type = "SettingsStructure" Then
			
			ItemHeader = NStr("en = 'Structure'");
			
		Else
			
			ItemHeader = String(SettingProperty.Type);
			
		EndIf;
		
	EndIf;
	
	SettingProperty.Presentation = TrimAll(ItemHeader);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary

Function FilterPresentation(KDNode, KDRowsSet = Undefined)
	If KDRowsSet = Undefined Then
		KDRowsSet = KDNode.Items;
	EndIf;
	
	Presentation = "";
	
	For Each KDItem IN KDRowsSet Do
		
		If TypeOf(KDItem) = Type("DataCompositionFilterItemGroup") Then
			
			AuthorPresentationFolders = String(KDItem.GroupType);
			NestedPresentation = FilterPresentation(KDNode, KDItem.Items);
			If NestedPresentation = "" Then
				Continue;
			EndIf;
			ItemPresentation = AuthorPresentationFolders + "(" + NestedPresentation + ")";
			
		ElsIf TypeOf(KDItem) = Type("DataCompositionFilterItem") Then
			
			AvailableKDSelectionField = KDNode.FilterAvailableFields.FindField(KDItem.LeftValue);
			If AvailableKDSelectionField = Undefined Then
				Continue;
			EndIf;
			
			If ValueIsFilled(AvailableKDSelectionField.Title) Then
				FieldPresentation = AvailableKDSelectionField.Title;
			Else
				FieldPresentation = String(KDItem.LeftValue);
			EndIf;
			
			ValuePresentation = String(KDItem.RightValue);
			
			If KDItem.ComparisonType = DataCompositionComparisonType.Equal Then
				PresentationConditions = "=";
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.NotEqual Then
				PresentationConditions = "<>";
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.Greater Then
				PresentationConditions = ">";
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.GreaterOrEqual Then
				PresentationConditions = ">=";
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.Less Then
				PresentationConditions = "<";
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.LessOrEqual Then
				PresentationConditions = "<=";
			
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.InHierarchy Then
				PresentationConditions = NStr("en = 'In group'");
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.NotInHierarchy Then
				PresentationConditions = NStr("en = 'Not in the group'");
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.InList Then
				PresentationConditions = NStr("en = 'In list'");
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.NotInList Then
				PresentationConditions = NStr("en = 'Not in the list'");
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.InListByHierarchy Then
				PresentationConditions = NStr("en = 'In list including subordinate'");
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.NotInListByHierarchy Then
				PresentationConditions = NStr("en = 'Not in the list including subordinate'");
			
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.Contains Then
				PresentationConditions = NStr("en = 'Contains'");
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.NotContains Then
				PresentationConditions = NStr("en = 'Doesn''t contain'");
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.Like Then
				PresentationConditions = NStr("en = 'Like'");
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.NotLike Then
				PresentationConditions = NStr("en = 'Not like'");
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.BeginsWith Then
				PresentationConditions = NStr("en = 'Begins with'");
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.NotBeginsWith Then
				PresentationConditions = NStr("en = 'Not beginning with'");
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.Filled Then
				PresentationConditions = NStr("en = 'Filled'");
				ValuePresentation = "";
			ElsIf KDItem.ComparisonType = DataCompositionComparisonType.NotFilled Then
				PresentationConditions = NStr("en = 'not filled'");
				ValuePresentation = "";
			EndIf;
			
			ItemPresentation = TrimAll(FieldPresentation + " " + PresentationConditions + " " + ValuePresentation);
			
		Else
			Continue;
		EndIf;
		
		Presentation = Presentation + ?(Presentation = "", "", ", ") + ItemPresentation;
		
	EndDo;
	
	Return Presentation;
EndFunction

Function TypeDescriptionsMatch(TypeDescription1, TypeDescription2) Export
	If TypeDescription1 = Undefined Or TypeDescription2 = Undefined Then
		Return False;
	EndIf;
	
	Return TypeDescription1 = TypeDescription2
		Or CommonUse.ValueToXMLString(TypeDescription1) = CommonUse.ValueToXMLString(TypeDescription2);
EndFunction

Function ReportObject(ReportSettings) Export
	If ReportSettings.Property("ReportObject") Then
		Return ReportSettings.ReportObject;
	EndIf;
	ReportObject = CommonUse.ObjectByDescriptionFull(ReportSettings.DescriptionFull);
	ReportSettings.Insert("ReportObject", ReportObject);
	Return ReportObject;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Output

Procedure OutputSettingItems(Form, Items, SettingProperty, OutputGroup, Other) Export
	OutputItem = New Structure("Size, ItemName1, ItemName2");
	OutputItem.Size = 1;
	
	ItemNameTemplate = SettingProperty.Type + "_%1_" + SettingProperty.ItemIdentificator;
	
	// Group is required to output some types of the fields.
	If SettingProperty.ItemsType = "StandardPeriod"
		Or SettingProperty.ItemsType = "ListWithSelection" Then
		GroupName = StrReplace(ItemNameTemplate, "%1", "Group");
		
		Group = Items.Add(GroupName, Type("FormGroup"), Items.NotSorted);
		Group.Type                 = FormGroupType.UsualGroup;
		Group.Representation         = UsualGroupRepresentation.None;
		Group.Title           = SettingProperty.Presentation;
		Group.ShowTitle = False;
	EndIf;
	
	// Usage check box.
	If SettingProperty.DisplayCheckbox Then
		FlagName = StrReplace(ItemNameTemplate, "%1", "Use");
		
		If SettingProperty.ItemsType = "ListWithSelection" Then
			CheckBoxForGroup = Group;
			OutputItem.ItemName1 = GroupName;
		Else
			CheckBoxForGroup = Items.NotSorted;
			OutputItem.ItemName1 = FlagName;
		EndIf;
		
		CheckBox = Items.Add(FlagName, Type("FormField"), CheckBoxForGroup);
		CheckBox.Type         = FormFieldType.CheckBoxField;
		CheckBox.Title   = SettingProperty.Presentation + ?(SettingProperty.DisplayOnlyCheckBox, "", ":");
		CheckBox.DataPath = Other.PathToLinker + ".UserSettings[" + SettingProperty.IndexInCollection + "].Use";
		CheckBox.TitleLocation = FormItemTitleLocation.Right;
		CheckBox.SetAction("OnChange", "Attachable_CheckBoxUse__OnChange");
	EndIf;
	
	// Fields for values.
	If SettingProperty.ItemsType <> "" Then
		
		TypeInformation = SettingProperty.TypeInformation;
		
		If SettingProperty.Type = "SettingsParameterValue"
			Or SettingProperty.Type = "FilterItem" Then
			
			If SettingProperty.EnterByList Then
				SettingProperty.MarkedValues = ReportsClientServer.ValueList(SettingProperty.Value);
			EndIf;
			
			// Save setting selection parameters in the additional properties of the custom settings.
			ItemSettings = New Structure;
			ItemSettings.Insert("Presentation",     SettingProperty.Presentation);
			ItemSettings.Insert("DisplayCheckbox",    SettingProperty.DisplayCheckbox);
			ItemSettings.Insert("TypeDescription",     SettingProperty.TypeDescription);
			ItemSettings.Insert("ChoiceParameters",   SettingProperty.ChoiceParameters);
			ItemSettings.Insert("ValuesForSelection", SettingProperty.ValuesForSelection);
			ItemSettings.Insert("LimitChoiceWithSpecifiedValues", SettingProperty.LimitChoiceWithSpecifiedValues);
			Other.AdditionalItemsSettings.Insert(SettingProperty.ItemIdentificator, ItemSettings);
		EndIf;
		
		////////////////////////////////////////////////////////////////////////////////
		// OUTPUT.
		
		ValueName = StrReplace(ItemNameTemplate, "%1", "Value");
		
		If SettingProperty.ItemsType = "OnlyCheckBoxValues" Then
			
			QuickSettingsAddAttribute(Other.FillingParameters, ValueName, SettingProperty.TypeDescription);
			
			OutputItem.ItemName1 = ValueName;
			
			InputField = Items.Add(ValueName, Type("FormField"), Group);
			InputField.Type                = FormFieldType.CheckBoxField;
			InputField.Title          = SettingProperty.Presentation;
			InputField.TitleLocation = FormItemTitleLocation.Right;
			InputField.SetAction("OnChange", "Attachable_ValueCheckBox_OnChange");
			
			Other.AddedInputFields.Insert(ValueName, SettingProperty.Value);
			
		ElsIf SettingProperty.ItemsType = "LinkWithLinker" Then
			
			Other.MainFormAttributesNames.Insert(SettingProperty.ItemIdentificator, ValueName);
			Other.NamesOfElementsForLinksSetup.Insert(SettingProperty.ItemIdentificator, ValueName);
			
			OutputItem.ItemName2 = ValueName;
			
			InputField = Items.Add(ValueName, Type("FormField"), Group);
			InputField.Type         = FormFieldType.InputField;
			InputField.Title   = SettingProperty.Presentation;
			InputField.DataPath = Other.PathToLinker + ".UserSettings[" + SettingProperty.IndexInCollection + "].Value";
			InputField.TitleLocation = FormItemTitleLocation.None;
			InputField.SetAction("OnChange", "Attachable_TextBox_OnChange");
			
			If SettingProperty.EnterByList Then
				InputField.SetAction("StartChoice", "Attachable_LinkerList_Value_StartChoice");
			EndIf;
			
			If SettingProperty.Type = "SettingsParameterValue" Then
				InputField.AutoMarkIncomplete = SettingProperty.AvailableKDSetting.DenyIncompleteValues;
			EndIf;
			
		ElsIf SettingProperty.ItemsType = "InputField" Then
			
			OutputItem.ItemName2 = ValueName;
			
			Other.MainFormAttributesNames.Insert(SettingProperty.ItemIdentificator, ValueName);
			Other.NamesOfElementsForLinksSetup.Insert(SettingProperty.ItemIdentificator, ValueName);
			
			// Attribute
			QuickSettingsAddAttribute(Other.FillingParameters, ValueName, SettingProperty.TypeDescription);
			
			InputField = Items.Add(ValueName, Type("FormField"), Group);
			InputField.Type                 = FormFieldType.InputField;
			InputField.Title           = SettingProperty.Presentation;
			InputField.OpenButton      = False;
			InputField.SpinButton = False;
			InputField.TitleLocation  = FormItemTitleLocation.None;
			InputField.SetAction("OnChange", "Attachable_TextBox_OnChange");
			
			FillPropertyValues(InputField, SettingProperty.AvailableKDSetting, "QuickSelection, Mask, ChoiceForm, EditFormat");
			
			InputField.ChoiceFoldersAndItems = SettingProperty.ChoiceFoldersAndItems;
			
			If SettingProperty.Type = "SettingsParameterValue" Then
				InputField.AutoMarkIncomplete = SettingProperty.AvailableKDSetting.DenyIncompleteValues;
			EndIf;
			
			// Entered fields of the following types are not dragged horizontally and do not have the clear button.:
			//     Date, Boolean, Number, Type.
			InputField.ClearButton            = TypeInformation.ContainsObjectTypes;
			InputField.HorizontalStretch = TypeInformation.ContainsObjectTypes;
			For Each ListItemInForm IN SettingProperty.ValuesForSelection Do
				FillPropertyValues(InputField.ChoiceList.Add(), ListItemInForm);
			EndDo;
			If SettingProperty.LimitChoiceWithSpecifiedValues Then
				InputField.ListChoiceMode = True;
				InputField.ButtonCreation = False;
				InputField.HorizontalStretch = True;
			EndIf;
			
			// Fixed selection parameters.
			If SettingProperty.ChoiceParameters.Count() > 0 Then
				InputField.ChoiceParameters = New FixedArray(SettingProperty.ChoiceParameters);
			EndIf;
			
			// Attribute value.
			Value = SettingProperty.Value;
			If TypeOf(Value) = Type("StandardBeginningDate") Then
				Value = Date(Value);
			ElsIf TypeOf(Value) = Type("Type") Then
				TypeArray = New Array;
				TypeArray.Add(Value);
				Value = New TypeDescription(TypeArray);
			EndIf;
			Other.AddedInputFields.Insert(ValueName, Value);
			
		ElsIf SettingProperty.ItemsType = "StandardPeriod" Then
			
			Group.Group = ChildFormItemsGroup.Horizontal;
			
			OutputItem.Size = 1;
			OutputItem.ItemName2 = GroupName;
			
			PeriodKindName           = StrReplace(ItemNameTemplate, "%1", "Kind");
			AuthorPresentationActualName        = StrReplace(ItemNameTemplate, "%1", "Presentation");
			BeginOfPeriodName         = StrReplace(ItemNameTemplate, "%1", "Begin");
			EndOfPeriodName      = StrReplace(ItemNameTemplate, "%1", "End");
			DecorationName            = StrReplace(ItemNameTemplate, "%1", "Decoration");
			PagesName             = StrReplace(ItemNameTemplate, "%1", "Pages");
			StandardNamePage  = StrReplace(ItemNameTemplate, "%1", "PageStandard");
			RandomNamePage = StrReplace(ItemNameTemplate, "%1", "PageCustom");
			
			// Attributes.
			QuickSettingsAddAttribute(Other.FillingParameters, ValueName,      "StandardPeriod");
			QuickSettingsAddAttribute(Other.FillingParameters, PeriodKindName,    "EnumRef.AvailableReportPeriods");
			QuickSettingsAddAttribute(Other.FillingParameters, AuthorPresentationActualName, "String");
			
			// Period kind - Item.
			ItemPeriodType = Items.Add(PeriodKindName, Type("FormField"), Group);
			ItemPeriodType.Type                      = FormFieldType.InputField;
			ItemPeriodType.Title                = SettingProperty.Presentation;
			ItemPeriodType.ListChoiceMode      = True;
			ItemPeriodType.HorizontalStretch = False;
			ItemPeriodType.Width                   = 11;
			ItemPeriodType.TitleLocation       = FormItemTitleLocation.None;
			ItemPeriodType.SetAction("OnChange", "Attachable_StandardPeriod_Type_OnChange");
			
			// Period kind - Selection list.
			MinimalPeriodicity = Form.ReportSettings.AccordanceFrequencySettings[SettingProperty.DCField];
			If MinimalPeriodicity = Undefined Then
				MinimalPeriodicity = Enums.AvailableReportPeriods.Day;
			EndIf;
			
			AvailablePeriods = ReportsClientServer.GetAvailablePeriodsList();
			For IndexOf = AvailablePeriods.Find(MinimalPeriodicity) To AvailablePeriods.UBound() Do
				ItemPeriodType.ChoiceList.Add(AvailablePeriods[IndexOf]);
			EndDo;
			
			// Pages.
			PagesGroup = Items.Add(PagesName, Type("FormGroup"), Group);
			PagesGroup.Type                = FormGroupType.Pages;
			PagesGroup.PagesRepresentation = FormPagesRepresentation.None;
			PagesGroup.Width = 24;
			PagesGroup.HorizontalStretch = False;
			
			// Page StandardPeriod.
			PageStandardPeriod = Items.Add(StandardNamePage, Type("FormGroup"), PagesGroup);
			PageStandardPeriod.Type                 = FormGroupType.Page;
			PageStandardPeriod.Group         = ChildFormItemsGroup.Horizontal;
			PageStandardPeriod.ShowTitle = False;
			
			// Page Custom.
			PageCustomPeriod = Items.Add(RandomNamePage, Type("FormGroup"), PagesGroup);
			PageCustomPeriod.Type                 = FormGroupType.Page;
			PageCustomPeriod.Group         = ChildFormItemsGroup.Horizontal;
			PageCustomPeriod.ShowTitle = False;
			
			// Standard period.
			Period = Items.Add(AuthorPresentationActualName, Type("FormField"), PageStandardPeriod);
			Period.Type       = FormFieldType.InputField;
			Period.Title = NStr("en = 'Period'");
			Period.HorizontalStretch = True;
			Period.ChoiceButton   = True;
			Period.OpenButton = False;
			Period.ClearButton  = False;
			Period.SpinButton  = False;
			Period.TextEdit = False;
			Period.TitleLocation   = FormItemTitleLocation.None;
			Period.SetAction("Clearing",      "Attachable_StandardPeriod_Value_Clearing");
			Period.SetAction("StartChoice", "Attachable_StandardPeriod_Value_StartChoice");
			
			// Begin custom period.
			BeginOfPeriod = Items.Add(BeginOfPeriodName, Type("FormField"), PageCustomPeriod);
			BeginOfPeriod.Type    = FormFieldType.InputField;
			BeginOfPeriod.HorizontalStretch = True;
			BeginOfPeriod.ChoiceButton   = True;
			BeginOfPeriod.OpenButton = False;
			BeginOfPeriod.ClearButton  = False;
			BeginOfPeriod.SpinButton  = False;
			BeginOfPeriod.TextEdit = True;
			BeginOfPeriod.TitleLocation   = FormItemTitleLocation.None;
			BeginOfPeriod.SetAction("OnChange", "Attachable_StandardPeriod_BeginOfPeriod_OnChange");
			
			If SettingProperty.Type = "SettingsParameterValue" Then
				BeginOfPeriod.AutoMarkIncomplete = SettingProperty.AvailableKDSetting.DenyIncompleteValues;
			EndIf;
			
			Dash = Items.Add(DecorationName, Type("FormDecoration"), PageCustomPeriod);
			Dash.Type       = FormDecorationType.Label;
			Dash.Title = Char(8211); // Medium dash (en dash).
			
			// End custom period.
			EndOfPerioding = Items.Add(EndOfPeriodName, Type("FormField"), PageCustomPeriod);
			EndOfPerioding.Type = FormFieldType.InputField;
			FillPropertyValues(EndOfPerioding, BeginOfPeriod, "HorizontalStretch, Width, TitleLocation, TextEdit, ChoiceButton, OpenButton, ClearButton, SpinButton, AutoMarkIncomplete");
			EndOfPerioding.SetAction("OnChange", "Attachable_StandardPeriod_EndOfPeriod_OnChange");
			
			// Values.
			BeginOfPeriod = SettingProperty.Value.StartDate;
			EndOfPeriod  = SettingProperty.Value.EndDate;
			PeriodKind    = ReportsClientServer.GetKindOfStandardPeriod(SettingProperty.Value, ItemPeriodType.ChoiceList);
			Presentation = ReportsClientServer.PresentationStandardPeriod(SettingProperty.Value, PeriodKind);
			
			Additionally = New Structure;
			Additionally.Insert("ValueName",        ValueName);
			Additionally.Insert("PeriodKindName",      PeriodKindName);
			Additionally.Insert("BeginOfPeriodName",    BeginOfPeriodName);
			Additionally.Insert("EndOfPeriodName", EndOfPeriodName);
			Additionally.Insert("AuthorPresentationActualName",   AuthorPresentationActualName);
			Additionally.Insert("PeriodKind",         PeriodKind);
			Additionally.Insert("Presentation",      Presentation);
			SettingProperty.Additionally = Additionally;
			Other.AddedStandardPeriods.Add(SettingProperty);
			
			// Activation page.
			If PeriodKind = Enums.AvailableReportPeriods.Custom Then
				PagesGroup.CurrentPage = PageCustomPeriod;
			Else
				PagesGroup.CurrentPage = PageStandardPeriod;
			EndIf;
			
		ElsIf SettingProperty.ItemsType = "ListWithSelection" Then
			
			Group.Group = ChildFormItemsGroup.Vertical;
			
			OutputItem.Size = 5;
			OutputItem.ItemName1 = GroupName;
			
			HeaderNameGroup = StrReplace(ItemNameTemplate, "%1", "GroupHeader");
			DecorationName       = StrReplace(ItemNameTemplate, "%1", "Decoration");
			TableName              = StrReplace(ItemNameTemplate, "%1", "ValueList");
			ColumnsGroupName        = StrReplace(ItemNameTemplate, "%1", "ColumnGroup");
			ColumnUsageName = StrReplace(ItemNameTemplate, "%1", "Column_Use");
			ValueNameColumn      = StrReplace(ItemNameTemplate, "%1", "Column_Value");
			CommandPanelName = StrReplace(ItemNameTemplate, "%1", "CommandBar");
			CompleteNameButton    = StrReplace(ItemNameTemplate, "%1", "Pick");
			InsertNameButton  = StrReplace(ItemNameTemplate, "%1", "InsertFromBuffer");
			
			Other.MainFormAttributesNames.Insert(SettingProperty.ItemIdentificator, TableName);
			Other.NamesOfElementsForLinksSetup.Insert(SettingProperty.ItemIdentificator, ValueNameColumn);
			
			If Not SettingProperty.DisplayCheckbox Or Not SettingProperty.LimitChoiceWithSpecifiedValues Then
				
				// Group row for the title and command panel table.
				TableHeaderGroup = Items.Add(HeaderNameGroup, Type("FormGroup"), Group);
				TableHeaderGroup.Type                 = FormGroupType.UsualGroup;
				TableHeaderGroup.Group         = ChildFormItemsGroup.Horizontal;
				TableHeaderGroup.Representation         = UsualGroupRepresentation.None;
				TableHeaderGroup.ShowTitle = False;
				
				// Check box is already created.
				If SettingProperty.DisplayCheckbox Then
					Items.Move(CheckBox, TableHeaderGroup);
				EndIf;
				
				// Title / Empty decoration.
				EmptyDecoration = Items.Add(DecorationName, Type("FormDecoration"), TableHeaderGroup);
				EmptyDecoration.Type                      = FormDecorationType.Label;
				EmptyDecoration.Title                = ?(SettingProperty.DisplayCheckbox, " ", SettingProperty.Presentation + ":");
				EmptyDecoration.HorizontalStretch = True;
				
				// Buttons.
				If Not SettingProperty.LimitChoiceWithSpecifiedValues Then
					If TypeInformation.ContainsReferenceTypes Then
						CommandPickUp = Form.Commands.Add(CompleteNameButton);
						CommandPickUp.Action    = "Attachable_ListWithPickup_Pickup";
						CommandPickUp.Title   = NStr("en = 'Pick'");
						CommandPickUp.Representation = ButtonRepresentation.Text;
					Else
						CommandPickUp = Form.Commands.Add(CompleteNameButton);
						CommandPickUp.Action    = "Attachable_ListWithSelection_Add";
						CommandPickUp.Title   = NStr("en = 'Add'");
						CommandPickUp.Representation = ButtonRepresentation.Text;
						CommandPickUp.Picture    = PictureLib.CreateListItem;
					EndIf;
					
					ButtonPickUp = Items.Add(CompleteNameButton, Type("FormButton"), TableHeaderGroup);
					ButtonPickUp.CommandName = CompleteNameButton;
					ButtonPickUp.Type = FormButtonType.Hyperlink;
					
					If Other.HasDataLoadFromFile Then
						InsertCommand = Form.Commands.Add(InsertNameButton);
						InsertCommand.Action    = "Attachable_ListWithSelection_InsertFromBuffer";
						InsertCommand.Title   = NStr("en = 'Insert from clipboard...'");
						InsertCommand.Picture    = PictureLib.FillForm;
						InsertCommand.Representation = ButtonRepresentation.Picture;
						
						InsertButton = Items.Add(InsertNameButton, Type("FormButton"), TableHeaderGroup);
						InsertButton.CommandName = InsertNameButton;
						InsertButton.Type = FormButtonType.Hyperlink;
					EndIf;
				EndIf;
				
			EndIf;
			
			// Attribute.
			QuickSettingsAddAttribute(Other.FillingParameters, TableName, "ValueList");
			
			// Group with indent and table.
			GroupWithIndent = Items.Add(GroupName + "Indent", Type("FormGroup"), Group);
			GroupWithIndent.Type                 = FormGroupType.UsualGroup;
			GroupWithIndent.Group         = ChildFormItemsGroup.Horizontal;
			GroupWithIndent.Representation         = UsualGroupRepresentation.None;
			GroupWithIndent.Title           = SettingProperty.Presentation;
			GroupWithIndent.ShowTitle = False;
			
			// Indent decoration.
			EmptyDecoration = Items.Add(DecorationName + "Indent", Type("FormDecoration"), GroupWithIndent);
			EmptyDecoration.Type                      = FormDecorationType.Label;
			EmptyDecoration.Title                = "     ";
			EmptyDecoration.HorizontalStretch = False;
			
			// Table.
			FormTable = Items.Add(TableName, Type("FormTable"), GroupWithIndent);
			FormTable.Representation               = TableRepresentation.List;
			FormTable.Title                 = SettingProperty.Presentation;
			FormTable.TitleLocation        = FormItemTitleLocation.None;
			FormTable.CommandBarLocation  = FormItemCommandBarLabelLocation.None;
			FormTable.VerticalLines         = False;
			FormTable.HorizontalLines       = False;
			FormTable.Header                     = False;
			FormTable.Footer                    = False;
			FormTable.ChangeRowOrder      = True;
			FormTable.HorizontalStretch  = True;
			FormTable.VerticalStretch    = True;
			FormTable.Height                    = 3;
			
			If SettingProperty.DisplayCheckbox Then
				// For platform 8.3.5 and less.
				Instruction = ReportsVariants.ConditionalDesignInstruction();
				Instruction.Fields = TableName + "," + ColumnUsageName + "," + ValueNameColumn;
				Instruction.Filters.Insert(CheckBox.DataPath, False);
				Instruction.Appearance.Insert("TextColor", StyleColors.InaccessibleDataColor);
				ReportsVariants.AddConditionalAppearanceItem(Form, Instruction);
				
				If Not SettingProperty.DCUsersSetting.Use Then
					FormTable.TextColor = Form.InactiveTableValuesColor;
				EndIf;
			EndIf;
			
			// Group of the in cell columns.
			ColumnGroup = Items.Add(ColumnsGroupName, Type("FormGroup"), FormTable);
			ColumnGroup.Type         = FormGroupType.ColumnGroup;
			ColumnGroup.Group = ColumnsGroup.InCell;
			
			// Use column.
			ColumnUseItem = Items.Add(ColumnUsageName, Type("FormField"), ColumnGroup);
			ColumnUseItem.Type = FormFieldType.CheckBoxField;
			
			// Value column.
			ElementValueColumn = Items.Add(ValueNameColumn, Type("FormField"), ColumnGroup);
			ElementValueColumn.Type = FormFieldType.InputField;
			
			FillPropertyValues(ElementValueColumn, SettingProperty.AvailableKDSetting, "QuickSelection, Mask, ChoiceForm, EditFormat");
			
			ElementValueColumn.ChoiceFoldersAndItems = SettingProperty.ChoiceFoldersAndItems;
			
			If SettingProperty.LimitChoiceWithSpecifiedValues Then
				ElementValueColumn.ReadOnly = True;
			EndIf;
			
			// Fill names of the metadata objects in the profiles of items types and identifiers (for the preset).
			// Used after clicking the Selection button to receive selection form name.
			If ValueIsFilled(ElementValueColumn.ChoiceForm) Then
				Other.MapMetadataObjectName.Insert(SettingProperty.ItemIdentificator, ElementValueColumn.ChoiceForm);
			EndIf;
			
			// Fixed selection parameters.
			If SettingProperty.ChoiceParameters.Count() > 0 Then
				ElementValueColumn.ChoiceParameters = New FixedArray(SettingProperty.ChoiceParameters);
			EndIf;
			
			Additionally = New Structure;
			Additionally.Insert("TableName",              TableName);
			Additionally.Insert("ColumnNameValue",      ValueNameColumn);
			Additionally.Insert("ColumnNameUse", ColumnUsageName);
			SettingProperty.Additionally = Additionally;
			Other.AddedValueLists.Add(SettingProperty);
			
		EndIf;
	EndIf;
	
	If OutputItem.ItemName1 = Undefined Then
		TitleActualName = StrReplace(ItemNameTemplate, "%1", "Title");
		LabelField = Items.Add(TitleActualName, Type("FormDecoration"), Items.NotSorted);
		LabelField.Type       = FormDecorationType.Label;
		LabelField.Title = SettingProperty.Presentation + ":";
		OutputItem.ItemName1 = TitleActualName;
	EndIf;
	
	If SettingProperty.ItemsType = "StandardPeriod" Then
		OutputGroup.Order.Insert(0, OutputItem);
	Else
		OutputGroup.Order.Add(OutputItem);
	EndIf;
	OutputGroup.Size = OutputGroup.Size + OutputItem.Size;
	
EndProcedure

Procedure QuickSettingsAddAttribute(FillingParameters, AttributeFullName, AttributeType)
	If TypeOf(AttributeType) = Type("TypeDescription") Then
		AddedTypes = AttributeType;
	ElsIf TypeOf(AttributeType) = Type("String") Then
		AddedTypes = New TypeDescription(AttributeType);
	ElsIf TypeOf(AttributeType) = Type("Array") Then
		AddedTypes = New TypeDescription(AttributeType);
	ElsIf TypeOf(AttributeType) = Type("Type") Then
		TypeArray = New Array;
		TypeArray.Add(AttributeType);
		AddedTypes = New TypeDescription(TypeArray);
	Else
		Return;
	EndIf;
	
	ExistingTypes = FillingParameters.Attributes.Existing.Get(AttributeFullName);
	If TypeDescriptionsMatch(ExistingTypes, AddedTypes) Then
		FillingParameters.Attributes.Existing.Delete(AttributeFullName);
	Else
		DotPosition = Find(AttributeFullName, ".");
		If DotPosition = 0 Then
			PathToAttribute = "";
			ShortAttributeName = AttributeFullName;
		Else
			PathToAttribute = Left(AttributeFullName, DotPosition - 1);
			ShortAttributeName = Mid(AttributeFullName, DotPosition + 1);
		EndIf;
		
		FillingParameters.Attributes.Adding.Add(New FormAttribute(ShortAttributeName, AddedTypes, PathToAttribute));
		If ExistingTypes <> Undefined Then
			FillingParameters.Attributes.ToDelete.Add(AttributeFullName);
			FillingParameters.Attributes.Existing.Delete(AttributeFullName);
		EndIf;
	EndIf;
EndProcedure

Procedure PutInOrder(Form, OutputGroup, Parent, ColumnsCount, FlexibleBalancing = True) Export
	Items = Form.Items;
	If FlexibleBalancing Then
		If OutputGroup.Size <= 7 Then
			ColumnsCount = 1;
		EndIf;
	EndIf;
	
	ParentName = Parent.Name;
	
	ColumnNumber = 0;
	ButtonsLeft = ColumnsCount + 1;
	TotalLeftPlace = OutputGroup.Size;
	PlaceLeftInColumn = 0;
	
	For Each OutputItem IN OutputGroup.Order Do
		If ButtonsLeft > 0
			AND OutputItem.Size > PlaceLeftInColumn*4 Then // The current step is bigger than the left place.
			ColumnNumber = ColumnNumber + 1;
			ButtonsLeft = ButtonsLeft - 1;
			PlaceLeftInColumn = TotalLeftPlace/ButtonsLeft;
			
			UpperLevelColumn = Items.Add(ParentName + ColumnNumber, Type("FormGroup"), Items[ParentName]);
			UpperLevelColumn.Type                 = FormGroupType.UsualGroup;
			UpperLevelColumn.Group         = ChildFormItemsGroup.Vertical;
			UpperLevelColumn.Representation         = UsualGroupRepresentation.None;
			UpperLevelColumn.ShowTitle = False;
			
			SubgroupNumber = 0;
			CurrentGroup1 = Undefined;
			CurrentGroup2 = Undefined;
		EndIf;
		
		If OutputItem.ItemName2 = Undefined Then // Output in one column.
			If CurrentGroup2 <> Undefined Then
				CurrentGroup2 = Undefined;
			EndIf;
			Items.Move(Items[OutputItem.ItemName1], UpperLevelColumn);
		Else
			If CurrentGroup2 = Undefined Then
				SubgroupNumber = SubgroupNumber + 1;
				
				Columns = Items.Add(ParentName + ColumnNumber + "_" + SubgroupNumber, Type("FormGroup"), UpperLevelColumn);
				Columns.Type                 = FormGroupType.UsualGroup;
				Columns.Group         = ChildFormItemsGroup.Horizontal;
				Columns.Representation         = UsualGroupRepresentation.None;
				Columns.ShowTitle = False;
				
				CurrentGroup1 = Items.Add(ParentName + ColumnNumber + "_" + SubgroupNumber + "_1", Type("FormGroup"), Columns);
				CurrentGroup1.Type                 = FormGroupType.UsualGroup;
				CurrentGroup1.Group         = ChildFormItemsGroup.Vertical;
				CurrentGroup1.Representation         = UsualGroupRepresentation.None;
				CurrentGroup1.ShowTitle = False;
				
				CurrentGroup2 = Items.Add(ParentName + ColumnNumber + "_" + SubgroupNumber + "_2", Type("FormGroup"), Columns);
				CurrentGroup2.Type                 = FormGroupType.UsualGroup;
				CurrentGroup2.Group         = ChildFormItemsGroup.Vertical;
				CurrentGroup2.Representation         = UsualGroupRepresentation.None;
				CurrentGroup2.ShowTitle = False;
			EndIf;
			Items.Move(Items[OutputItem.ItemName1], CurrentGroup1);
			Items.Move(Items[OutputItem.ItemName2], CurrentGroup2);
		EndIf;
		
		TotalLeftPlace = TotalLeftPlace - OutputItem.Size;
		PlaceLeftInColumn = PlaceLeftInColumn - OutputItem.Size;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Save form state

Function RememberSelectedRows(Form, TableName, KeyColumns) Export
	TableAttribute = Form[TableName];
	ItemTable = Form.Items[TableName];
	
	Result = New Structure;
	Result.Insert("Selected", New Array);
	Result.Insert("Current", Undefined);
	
	CurrentIdentifier = ItemTable.CurrentRow;
	If CurrentIdentifier <> Undefined Then
		TableRow = TableAttribute.FindByID(CurrentIdentifier);
		If TableRow <> Undefined Then
			RowData = New Structure(KeyColumns);
			FillPropertyValues(RowData, TableRow);
			Result.Current = RowData;
		EndIf;
	EndIf;
	
	SelectedRows = ItemTable.SelectedRows;
	If SelectedRows <> Undefined Then
		For Each SelectedIdentifier IN SelectedRows Do
			If SelectedIdentifier = CurrentIdentifier Then
				Continue;
			EndIf;
			TableRow = TableAttribute.FindByID(SelectedIdentifier);
			If TableRow <> Undefined Then
				RowData = New Structure(KeyColumns);
				FillPropertyValues(RowData, TableRow);
				Result.Selected.Add(RowData);
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

Procedure RecallSelectedRows(Form, TableName, TableRows) Export
	TableAttribute = Form[TableName];
	ItemTable = Form.Items[TableName];
	
	ItemTable.SelectedRows.Clear();
	
	If TableRows.Current <> Undefined Then
		Found = FindTableRows(TableAttribute, TableRows.Current);
		If Found <> Undefined AND Found.Count() > 0 Then
			For Each TableRow IN Found Do
				If TableRow <> Undefined Then
					ID = TableRow.GetID();
					ItemTable.CurrentRow = ID;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	For Each RowData IN TableRows.Selected Do
		Found = FindTableRows(TableAttribute, RowData);
		If Found <> Undefined AND Found.Count() > 0 Then
			For Each TableRow IN Found Do
				If TableRow <> Undefined Then
					ItemTable.SelectedRows.Add(TableRow.GetID());
				EndIf;
			EndDo;
		EndIf;
	EndDo;
EndProcedure

Function FindTableRows(TableAttribute, RowData)
	If TypeOf(TableAttribute) = Type("FormDataCollection") Then // Values table.
		Return TableAttribute.FindRows(RowData);
	ElsIf TypeOf(TableAttribute) = Type("FormDataTree") Then // Values tree.
		Return FindRecursively(TableAttribute.GetItems(), RowData);
	Else
		Return Undefined;
	EndIf;
EndFunction

Function FindRecursively(RowsSet, RowData, Found = Undefined)
	If Found = Undefined Then
		Found = New Array;
	EndIf;
	For Each TableRow IN RowsSet Do
		ValuesMatch = True;
		For Each KeyAndValue IN RowData Do
			If TableRow[KeyAndValue.Key] <> KeyAndValue.Value Then
				ValuesMatch = False;
				Break;
			EndIf;
		EndDo;
		If ValuesMatch Then
			Found.Add(TableRow);
		EndIf;
		FindRecursively(TableRow.GetItems(), RowData, Found);
	EndDo;
	Return Found;
EndFunction

#EndRegion
