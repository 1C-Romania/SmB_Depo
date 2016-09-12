////////////////////////////////////////////////////////////////////////////////
//                          FORM USAGE //
//
// The form is for selection of configuration metadata
// objects and transfer their selected list to the calling environment.
//
// Call parameters:
// MetadataObjectToSelectCollection - ValueList - It
// 			is actually a filter of metadata object type that may be selected.
// 			ForExample:
// 				ReferenceMetadataFilter = New ValueList;
// 				ReferenceMetadataFilter.Add("Catalogs");
// 				ReferenceMetadataFilter.Add("Documents");
// 			It allows to select metadata objects, catalogs and documents only.
// SelectedMetadataObjects - ValueList - already selected metadata ojects.
// 			Such objects will be marked by check box in the metadata tree .
// 			It may be useful for setting the selection metadata
// 			objects by default or restarting already installed list.
// ParentSubsystems - ValueList - of subsystem which subordinate
// 				subsystems only will be displayed in the form (special for SSL implementation assistant). 
// SubsystemsWithCIOnly - Boolean - identifier of only those subsystems in the selection list which are included in the command interface (special for SSL implementation assistant).
// ChooseSingle - Boolean - indentifier of metadata object selection only .
//              IN this case marking of several will be impossible, in addition
//              the double click on the metadata object row will choose.
// ChoiceInitialValue - String - Full metadata name which form
//              opening list will be located on.
//

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	SelectedMetadataObjects.LoadValues(Parameters.SelectedMetadataObjects.UnloadValues());
	
	If Parameters.FilterByMetadataObjects.Count() > 0 Then
		Parameters.MetadataObjectToSelectCollection.Clear();
		For Each MetadataObjectFullName IN Parameters.FilterByMetadataObjects Do
			BaseTypeName = CommonUse.BaseTypeNameByMetadataObject(Metadata.FindByFullName(MetadataObjectFullName));
			If Parameters.MetadataObjectToSelectCollection.FindByValue(BaseTypeName) = Undefined Then
				Parameters.MetadataObjectToSelectCollection.Add(BaseTypeName);
			EndIf;
		EndDo;
	EndIf;
	
	If Parameters.Property("SubsystemsWithCIOnly") AND Parameters.SubsystemsWithCIOnly Then
		SubsystemsList = Metadata.Subsystems;
		FillSubsystemsList(SubsystemsList);
		SubsystemsWithCIOnly = True;
	EndIf;
	
	If Parameters.Property("ChooseSingle", ChooseSingle) AND ChooseSingle Then
		Items.Check.Visible = False;
	EndIf;
	
	If Parameters.Property("Title") Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	
	Parameters.Property("ChoiceInitialValue", ChoiceInitialValue);
	
	MetadataObjectTreeFill();
	
	If Parameters.ParentSubsystems.Count()> 0 Then
		Items.MetadataObjectTree.InitialTreeView = InitialTreeView.ExpandAllLevels;
	EndIf;
	
	CollectionsInitialCheck(MetadataObjectTree);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// We are setting the selection initial value.
	If CurrentRowIDOnOpen > 0 Then
		
		Items.MetadataObjectTree.CurrentRow = CurrentRowIDOnOpen;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

// Event handler procedure of clicking the "Mark" field in the form tree.
&AtClient
Procedure CheckOnChange(Item)

	CurrentData = CurrentItem.CurrentData;
	If CurrentData.Check = 2 Then
		CurrentData.Check = 0;
	EndIf;
	MarkNestedElements(CurrentData);
	MarkParentItems(CurrentData);

EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersMetadataObjectTree

&AtClient
Procedure MetadataObjectTreeChoice(Item, SelectedRow, Field, StandardProcessing)

	If ChooseSingle Then
		
		ChooseRun();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ChooseRun()
	
	If ChooseSingle Then
		
		CurData = Items.MetadataObjectTree.CurrentData;
		If CurData <> Undefined
			AND CurData.IsMetadataObject Then
			
			SelectedMetadataObjects.Clear();
			SelectedMetadataObjects.Add(CurData.FullName);
			
		Else
			
			Return;
			
		EndIf;
	Else
		
		SelectedMetadataObjects.Clear();
		
		DataReceiving();
		
	EndIf;
	Notify("MetadataObjectsSelection", SelectedMetadataObjects, Parameters.UUIDSource);
	
	Close();
	
EndProcedure

&AtClient
Procedure CloseExecute()
	
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillSubsystemsList(SubsystemsList) 
	For Each Subsystem IN SubsystemsList Do
		If Subsystem.IncludeInCommandInterface Then
			SubsystemItemsWithCommandInterface.Add(Subsystem.FullName());
		EndIf;	
		
		If Subsystem.Subsystems.Count() > 0 Then
			FillSubsystemsList(Subsystem.Subsystems);
		EndIf;
	EndDo;
EndProcedure

// Procedure fills the value tree of configuration objects.
// If the "Settings.MetadataSelectedObjectCollection" values list is
// not empty, then the tree will be limited by passed list of metadata object collections.
//  If metadata objects in the formed tree will be
// found in the "Settings.MetadataSelectedObjects" value list, then they will be marked as selected.
//
&AtServer
Procedure MetadataObjectTreeFill()
	
	CollectionsOfMetadataObjects = New ValueTable;
	CollectionsOfMetadataObjects.Columns.Add("Name");
	CollectionsOfMetadataObjects.Columns.Add("Synonym");
	CollectionsOfMetadataObjects.Columns.Add("Picture");
	CollectionsOfMetadataObjects.Columns.Add("ObjectPicture");
	CollectionsOfMetadataObjects.Columns.Add("IsCommonCollection");
	CollectionsOfMetadataObjects.Columns.Add("FullName");
	CollectionsOfMetadataObjects.Columns.Add("Parent");
	
	CollectionsOfMetadataObjects_NewRow("Subsystems",                   NStr("en = 'Subsystems'"),                     35, 36, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("CommonModules",                  NStr("en = 'Common modules'"),                   37, 38, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("SessionParameters",              NStr("en = 'Session settings'"),               39, 40, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("Roles",                         NStr("en = 'Roles'"),                           41, 42, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("ExchangePlans",                  NStr("en = 'Exchange plans'"),                   43, 44, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("FilterCriteria",               NStr("en = 'Filter criteria'"),                45, 46, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("EventSubscriptions",            NStr("en = 'Event subscriptions'"),            47, 48, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("ScheduledJobs",          NStr("en = 'Scheduled jobs'"),           49, 50, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("FunctionalOptions",          NStr("en = 'Functional options'"),           51, 52, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("FunctionalOptionsParameters", NStr("en = 'Functional options parameters'"), 53, 54, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("SettingsStorages",            NStr("en = 'Setting storages'"),             55, 56, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("CommonForms",                   NStr("en = 'Common forms'"),                    57, 58, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("CommonCommands",                 NStr("en = 'Common command'"),                  59, 60, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("CommandGroups",                 NStr("en = 'Command groups'"),                  61, 62, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("Interfaces",                   NStr("en = 'Interfaces'"),                     63, 64, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("CommonTemplates",                  NStr("en = 'Common templates'"),                   65, 66, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("CommonPictures",                NStr("en = 'Common pictures'"),                 67, 68, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("XDTOPackages",                   NStr("en = 'XDTO-packages'"),                    69, 70, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("WebServices",                   NStr("en = 'Web-Services'"),                    71, 72, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("WSReferences",                     NStr("en = 'WS-references'"),                      73, 74, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("Styles",                        NStr("en = 'Styles'"),                          75, 76, True, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("Languages",                        NStr("en = 'Languages'"),                          77, 78, True, CollectionsOfMetadataObjects);
	
	CollectionsOfMetadataObjects_NewRow("Constants",                    NStr("en = 'Constants'"),                      PictureLib.Constant,              PictureLib.Constant,                    False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("Catalogs",                  NStr("en = 'Catalogs'"),                    PictureLib.Catalog,             PictureLib.Catalog,                   False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("Documents",                    NStr("en = 'Documents'"),                      PictureLib.Document,               PictureLib.DocumentObject,               False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("DocumentJournals",            NStr("en = 'Document journals'"),             PictureLib.DocumentJournal,       PictureLib.DocumentJournal,             False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("Enums",                 NStr("en = 'Enums'"),                   PictureLib.Enum,           PictureLib.Enum,                 False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("Reports",                       NStr("en = 'Reports'"),                         PictureLib.Report,                  PictureLib.Report,                        False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("DataProcessors",                    NStr("en = 'DataProcessors'"),                      PictureLib.DataProcessor,              PictureLib.DataProcessor,                    False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("ChartsOfCharacteristicTypes",      NStr("en = 'Charts of characteristics types'"),      PictureLib.ChartOfCharacteristicTypes, PictureLib.ChartOfCharacteristicTypesObject, False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("ChartsOfAccounts",                  NStr("en = 'Charts of accounts'"),                   PictureLib.ChartOfAccounts,             PictureLib.ChartOfAccountsObject,             False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("ChartsOfCalculationTypes",            NStr("en = 'Charts of characteristics types'"),      PictureLib.ChartOfCharacteristicTypes, PictureLib.ChartOfCharacteristicTypesObject, False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("InformationRegisters",             NStr("en = 'Information registers'"),              PictureLib.InformationRegister,        PictureLib.InformationRegister,              False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("AccumulationRegisters",           NStr("en = 'Accumulation registers'"),            PictureLib.AccumulationRegister,      PictureLib.AccumulationRegister,            False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("AccountingRegisters",          NStr("en = 'Accounting registers'"),           PictureLib.AccountingRegister,     PictureLib.AccountingRegister,           False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("CalculationRegisters",              NStr("en = 'Calculation registers'"),               PictureLib.CalculationRegister,         PictureLib.CalculationRegister,               False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("BusinessProcesses",               NStr("en = 'Business-processes'"),                PictureLib.BusinessProcess,          PictureLib.BusinessProcessObject,          False, CollectionsOfMetadataObjects);
	CollectionsOfMetadataObjects_NewRow("Tasks",                       NStr("en = 'Tasks'"),                         PictureLib.Task,                 PictureLib.TaskObject,                 False, CollectionsOfMetadataObjects);
	
	// Predefined items creating.
	ItemParameters = MetadataObjectTreeItemParameters();
	ItemParameters.Name = Metadata.Name;
	ItemParameters.Synonym = Metadata.Synonym;
	ItemParameters.Picture = 79;
	ItemParameters.Parent = MetadataObjectTree;
	ConfigurationItem = NewRowOfTree(ItemParameters);
	
	ItemParameters = MetadataObjectTreeItemParameters();
	ItemParameters.Name = "Common";
	ItemParameters.Synonym = "Common";
	ItemParameters.Picture = 0;
	ItemParameters.Parent = ConfigurationItem;
	ItemCommon = NewRowOfTree(ItemParameters);
	
	// Filling of the metadata object tree.
	For Each String IN CollectionsOfMetadataObjects Do
		If Parameters.MetadataObjectToSelectCollection.Count() = 0
			Or Parameters.MetadataObjectToSelectCollection.FindByValue(String.Name) <> Undefined Then
			String.Parent = ?(String.IsCommonCollection, ItemCommon, ConfigurationItem);
			AddMetadataObjectTreeItem(String, ?(String.Name = "Subsystems", Metadata.Subsystems, Undefined));
		EndIf;
	EndDo;
	
	If ItemCommon.GetItems().Count() = 0 Then
		ConfigurationItem.GetItems().Delete(ItemCommon);
	EndIf;
	
EndProcedure

// It returns a new parameter structure of the metadata object tree item.
//
// Returns:
//   Structure with fields:
//     Name           - String - name of the parent item.
//     Synonym       - String - a synonym for the parent item.
//     Check       - Boolean - initial marking of collection or metadata object.
//     Picture      - Number - the parent item image code.
//     ObjectPicture - Number - the subitem image code.
//     Parent        - a ref to the value tree item
//                       which is a root for the addition item.
//
Function MetadataObjectTreeItemParameters()
	
	Return New Structure("Name,FullName,Synonym,Check,Picture,ObjectPicture,Parent", "", "", False, 0, 0, Undefined);
	
EndFunction

// Adds a new row in form value
// tree (tree) and also fills the row full set from metadata by passed item.
// 
// If the subsystem parameter is filled then it is called recursive for all child subsystems.
// 
// Parameters:
//   ItemParameters - Structure with fields:
//     Name           - String - name of the parent item.
//     Synonym       - String - a synonym for the parent item.
//     Check       - Boolean - initial marking of collection or metadata object.
//     Picture      - Number - the parent item image code.
//     ObjectPicture - Number - the subitem image code.
//     Parent        - a ref to the value tree item
//                       which is a root for the addition item.
//   Subsystems      - If it is filled, it contains the Metadata.Subsystems value (Item collection).
//   Check       - Boolean - the identifier of membership test to parent subsystems.
// 
// Returns:
// 
//   A row of the metadata object tree.
//
&AtServer
Function AddMetadataObjectTreeItem(ItemParameters, Subsystems = Undefined, Check = True)
	
	// Test for command interface in tree leaves only.
	If Subsystems <> Undefined  AND Parameters.Property("SubsystemsWithCIOnly") 
		AND Not IsBlankString(ItemParameters.FullName) 
		AND SubsystemItemsWithCommandInterface.FindByValue(ItemParameters.FullName) = Undefined Then
		Return Undefined;
	EndIf;
	
	If Subsystems = Undefined Then
		
		If Metadata[ItemParameters.Name].Count() = 0 Then
			
			// If there is no metadata object from the needed branch. 
			// For example there is
			// not accounting register then it is not necessary to add the "Accounting Registers" root.
			Return Undefined;
			
		EndIf;
		
		NewRow = NewRowOfTree(ItemParameters, Subsystems <> Undefined AND Subsystems <> Metadata.Subsystems);
		
		For Each MetadataCollectionItem IN Metadata[ItemParameters.Name] Do
			
			If Parameters.FilterByMetadataObjects.Count() > 0
				AND Parameters.FilterByMetadataObjects.FindByValue(MetadataCollectionItem.FullName()) = Undefined Then
				Continue;
			EndIf;
			
			ItemParameters = MetadataObjectTreeItemParameters();
			ItemParameters.Name = MetadataCollectionItem.Name;
			ItemParameters.FullName = MetadataCollectionItem.FullName();
			ItemParameters.Synonym = MetadataCollectionItem.Synonym;
			ItemParameters.ObjectPicture = ItemParameters.ObjectPicture;
			ItemParameters.Parent = NewRow;
			NewRowOfTree(ItemParameters, True);
		EndDo;
		
		Return NewRow;
		
	EndIf;
		
	If Subsystems.Count() = 0 AND ItemParameters.Name = "Subsystems" Then
		// If there is no subsystem, then it is not necessary to add the "Subsystem" root.
		Return Undefined;
	EndIf;
	
	NewRow = NewRowOfTree(ItemParameters, Subsystems <> Undefined AND Subsystems <> Metadata.Subsystems);
	
	For Each MetadataCollectionItem IN Subsystems Do
		
		If Not Check
			Or Parameters.ParentSubsystems.Count() = 0
			Or Parameters.ParentSubsystems.FindByValue(MetadataCollectionItem.Name) <> Undefined Then
			
			ItemParameters = MetadataObjectTreeItemParameters();
			ItemParameters.Name = MetadataCollectionItem.Name;
			ItemParameters.FullName = MetadataCollectionItem.FullName();
			ItemParameters.Synonym = MetadataCollectionItem.Synonym;
			ItemParameters.Picture = ItemParameters.Picture;
			ItemParameters.ObjectPicture = ItemParameters.ObjectPicture;
			ItemParameters.Parent = NewRow;
			AddMetadataObjectTreeItem(ItemParameters, MetadataCollectionItem.Subsystems, False);
		EndIf;
	EndDo;
	
	Return NewRow;
	
EndFunction

&AtServer
Function NewRowOfTree(RowParameters, IsMetadataObject = False)
	
	Collection = RowParameters.Parent.GetItems();
	NewRow = Collection.Add();
	NewRow.Name                 = RowParameters.Name;
	NewRow.Presentation       = ?(ValueIsFilled(RowParameters.Synonym), RowParameters.Synonym, RowParameters.Name);
	NewRow.Check             = ?(Parameters.SelectedMetadataObjects.FindByValue(RowParameters.FullName) = Undefined, 0, 1);
	NewRow.Picture            = RowParameters.Picture;
	//( elmi  Lost in translation - fixed for  #17
	//NewRow.FullName           = RowParameters.FullName;
	NewRow.DescriptionFull    = RowParameters.FullName;
    //) elmi  
	NewRow.IsMetadataObject = IsMetadataObject;
	
	If NewRow.IsMetadataObject 
		//( elmi  Lost in translation - fixed for  #17
		//AND NewRow.FullName = ChoiceInitialValue Then
		  AND NewRow.DescriptionFull = ChoiceInitialValue Then
		//) elmi    
		CurrentRowIDOnOpen = NewRow.GetID();
	EndIf;
	
	Return NewRow;
	
EndFunction

// It adds a new row in value table
// of configuration metadata object types.
//
// Parameters:
// Name           - metadata object name or metadata object type.
// Synonym       - a synonym of the metadata object.
// Picture      - the image assigned to metadata
//                 object or metadata object type.
// IsCommonCollection - a flag showing that the current item contains subitems.
//
&AtServer
Procedure CollectionsOfMetadataObjects_NewRow(Name, Synonym, Picture, ObjectPicture, IsCommonCollection, Tab)
	
	NewRow = Tab.Add();
	NewRow.Name               = Name;
	NewRow.Synonym           = Synonym;
	NewRow.Picture          = Picture;
	NewRow.ObjectPicture   = ObjectPicture;
	NewRow.IsCommonCollection = IsCommonCollection;
	
EndProcedure

// The procedure recursively sets/removes the check box for parents of the passed item.
//
// Parameters:
// Item      - FormDataTreeItemCollection 
//
&AtClient
Procedure MarkParentItems(Item)

	Parent = Item.GetParent();
	
	If Parent = Undefined Then
		Return;
	EndIf;
	
	ParentItems = Parent.GetItems();
	If ParentItems.Count() = 0 Then
		Parent.Check = 0;
	ElsIf Item.Check = 2 Then
		Parent.Check = 2;
	Else
		Parent.Check = ItemsMarkValue(ParentItems);
	EndIf;
	
	MarkParentItems(Parent);
	
EndProcedure

&AtClient
Function ItemsMarkValue(ParentItems)
	
	AreMarked    = False;
	HasUnmarked = False;
	
	For Each ParentItem IN ParentItems Do
		
		If ParentItem.Check = 2 OR (AreMarked AND HasUnmarked) Then
			AreMarked    = True;
			HasUnmarked = True;
			Break;
		ElsIf ParentItem.IsMetadataObject Then
			AreMarked    = AreMarked    OR    ParentItem.Check;
			HasUnmarked = HasUnmarked OR Not ParentItem.Check;
		Else
			NestedItems = ParentItem.GetItems();
			If NestedItems.Count() = 0 Then
				Continue;
			EndIf;
			NestedItemMarkValue = ItemsMarkValue(NestedItems);
			AreMarked    = AreMarked    OR    ParentItem.Check OR    NestedItemMarkValue;
			HasUnmarked = HasUnmarked OR Not ParentItem.Check OR Not NestedItemMarkValue;
		EndIf;
	EndDo;
	
	If AreMarked Then
		If HasUnmarked Then
			Return 2;
		Else
			If SubsystemsWithCIOnly Then
				Return 2;
			Else
				Return 1;
			EndIf;
		EndIf;
	Else
		Return 0;
	EndIf;
	
EndFunction

&AtServer
Procedure MarkParentItemsAtServer(Item)

	Parent = Item.GetParent();
	
	If Parent = Undefined Then
		Return;
	EndIf;
	
	ParentItems = Parent.GetItems();
	If ParentItems.Count() = 0 Then
		Parent.Check = 0;
	ElsIf Item.Check = 2 Then
		Parent.Check = 2;
	Else
		Parent.Check = ItemMarkValuesAtServer(ParentItems);
	EndIf;
	
	MarkParentItemsAtServer(Parent);

EndProcedure

&AtServer
Function ItemMarkValuesAtServer(ParentItems)
	
	AreMarked    = False;
	HasUnmarked = False;
	
	For Each ParentItem IN ParentItems Do
		
		If ParentItem.Check = 2 OR (AreMarked AND HasUnmarked) Then
			AreMarked    = True;
			HasUnmarked = True;
			Break;
		ElsIf ParentItem.IsMetadataObject Then
			AreMarked    = AreMarked    OR    ParentItem.Check;
			HasUnmarked = HasUnmarked OR Not ParentItem.Check;
		Else
			NestedItems = ParentItem.GetItems();
			If NestedItems.Count() = 0 Then
				Continue;
			EndIf;
			NestedItemMarkValue = ItemMarkValuesAtServer(NestedItems);
			AreMarked    = AreMarked    OR    ParentItem.Check OR    NestedItemMarkValue;
			HasUnmarked = HasUnmarked OR Not ParentItem.Check OR Not NestedItemMarkValue;
		EndIf;
	EndDo;
	
	Return ?(AreMarked AND HasUnmarked, 2, ?(AreMarked, 1, 0));
	
EndFunction

// CollectionsInitialCheck procedure sets a check
// box for metadata object collections which do not have metadata
// objects (true) and which have metadata objects with the giving check box.
//
// Parameters:
// Item      - FormDataTreeItemCollection 
//
Procedure CollectionsInitialCheck(Parent)
	
	NestedItems = Parent.GetItems();
	
	For Each NestedItem IN NestedItems Do
		If NestedItem.Check Then
			MarkParentItemsAtServer(NestedItem);
		EndIf;
		CollectionsInitialCheck(NestedItem);
	EndDo;
	
EndProcedure

// The procedure recursive sets/removes the chek box
// for nested items starting from the passed item.
//
// Parameters:
// Item      - FormDataTreeItemCollection 
//
&AtClient
Procedure MarkNestedElements(Item)

	NestedItems = Item.GetItems();
	
	If NestedItems.Count() = 0 Then
		If Not Item.IsMetadataObject Then
			Item.Check = 0;
		EndIf;
	Else
		For Each NestedItem IN NestedItems Do
			If Not SubsystemsWithCIOnly Then
				NestedItem.Check = Item.Check;
			EndIf;
			MarkNestedElements(NestedItem);
		EndDo;
	EndIf;
	
EndProcedure

// Procedure for filling the selected item list of tree.
// Recursive looks at all item tree and in the
// case if item is selected adds it FullName in the list of selected.
//
// Parent      - FormDataTreeItem
//
&AtServer
Procedure DataReceiving(Parent = Undefined)
	
	Parent = ?(Parent = Undefined, MetadataObjectTree, Parent);
	
	ItemCollection = Parent.GetItems();
	
	For Each Item IN ItemCollection Do
		If Item.Check = 1 AND Not IsBlankString(Item.FullName) Then
			SelectedMetadataObjects.Add(Item.FullName);
		EndIf;
		DataReceiving(Item);
	EndDo;
	
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
