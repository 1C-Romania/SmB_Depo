#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns the values tree filled in with the data for exchange node selection. There are 2 levels in the tree: 
// exchange plan -> exchange nodes. Service nodes are thrown away. 
//
// Parameters:
//    ObjectData - AnyRef, Structure - Ref or structure with values of measurements records set. For
//                   this data exchange nodes are analyzed. If it is not specified, then for all.
//    TableName   - String - If it is the DataObject - structure, the table name is for records set.
//
// Returns:
//    ValueTree - data with columns:
//        * Description                  - String - Exchange plan presentation or exchange node.
//        * PictureIndex                - Number  - 1 = Plan exchange, 2 = node , 3 = marked for delete node.
//        * PictureIndexAutoRecord - Number  - If the DataObject parameter is not specified, it is Undefined.
//                                                   Otherwise: 0 = not, 1 = prohibited, 2
//                                                   = allowed, Undefined for an exchange plan.
//        * ExchangePlanName                 - String - Exchange plan name of the node.
//        * Ref                        - ExchangePlanRef - Node reference, Undefined is for an exchange plan.
//        * Code                           - Number, String - Node code, Undefined is for an exchange plan.
//        * SentNumber            - Number - Node data.
//        * ReceivedNumber                - Number - Node data.
//        * MessageNumber                - Number, NULL  - If an object is specified, then message number is for it, otherwise, NULL.
//        * NotExported                 - Boolean, NULL - If an object is specified, then check box of the export, otherwise, NULL.
//        Appearance picture setup mark                       - Boolean       - If an object is specified, then 0 = no registration, 1 - is
//                                                         present, otherwise, always 0.
//        * SourceMark               - Boolean       - similarly to the "Mark" column.
//        * StringID           - Number        - Added string index (bypass tree downwards from
//                                                         left to right).
//
Function SetNodTree(ObjectData = Undefined, TableName = Undefined) Export
	
	Tree = New ValueTree;
	Columns = Tree.Columns;
	Rows  = Tree.Rows;
	
	Columns.Add("Description");
	Columns.Add("PictureIndex");
	Columns.Add("PictureIndexAutoRecord");
	Columns.Add("ExchangePlanName");
	Columns.Add("Ref");
	Columns.Add("Code");
	Columns.Add("SentNo");
	Columns.Add("ReceivedNo");
	Columns.Add("MessageNo");
	Columns.Add("NotExported");
	Columns.Add("Mark");
	Columns.Add("InitialCheck");
	Columns.Add("RowID");
	
	Query = New Query;
	If ObjectData = Undefined Then
		MetaObject = Undefined;
		QueryText = "
			|SELECT
			|	REFPRESENTATION(Ref) AS Description,
			|	CASE 
			|		WHEN DeletionMark THEN 2 ELSE 1
			|	END AS PictureIndex,
			|
			|	""{0}""            AS ExchangePlanName,
			|	Code                AS Code,
			|	Ref             AS Ref,
			|	SentNo AS SentNo,
			|	ReceivedNo     AS ReceivedNo,
			|	NULL               AS MessageNo,
			|	NULL               AS NotExported,
			|	0                  AS ChangesOnNodeQuantity
			|FROM
			|	ExchangePlan.{0} AS ExchangePlan
			|WHERE
			|	Not ExchangePlan.ThisNode
			|";
		
	Else
		If TypeOf(ObjectData) = Type("Structure") Then
			QueryText = "";
			For Each KeyValue IN ObjectData Do
				curName = KeyValue.Key;
				QueryText = QueryText + "
					|And ChangesTable." + curName + " = &" + curName;
				Query.SetParameter(curName, ObjectData[curName]);
			EndDo;
			CurTableName = TableName;
			MetaObject    = MetadataByFullname(TableName);
			
		ElsIf TypeOf(ObjectData) = Type("String") Then
			QueryText  = "";
			CurTableName = ObjectData;
			MetaObject    = MetadataByFullname(ObjectData);
			
		Else
			QueryText = "
				|And ChangesTable.Ref = &RegistrationObject";
			Query.SetParameter("RegistrationObject", ObjectData);
			
			MetaObject    = ObjectData.Metadata();
			CurTableName = MetaObject.FullName();
		EndIf;
		
		QueryText = "
			|SELECT
			|	REFPRESENTATION(ExchangePlan.Ref) AS Description,
			|	CASE 
			|		WHEN ExchangePlan.DeletionMark THEN 2 ELSE 1
			|	END AS PictureIndex,
			|
			|	""{0}""                         AS ExchangePlanName,
			|	ExchangePlan.Code                  AS Code,
			|	ExchangePlan.Ref               AS Ref,
			|	ExchangePlan.SentNo   AS SentNo,
			|	ExchangePlan.ReceivedNo       AS ReceivedNo,
			|	ChangeTable.MessageNo AS MessageNo,
			|	CASE 
			|		WHEN ChangeTable.MessageNo IS NULL
			|		THEN TRUE
			|		ELSE FALSE
			|	END AS NotExported,
			|	COUNT(ChangeTable.Node) AS ChangesOnNodeQuantity
			|FROM
			|	ExchangePlan.{0} AS ExchangePlan
			|LEFT JOIN
			|	" + CurTableName + ".Changes
			|AS
			|ChangesTable BY ChangesTable.Node = ExchangePlan.Ref
			|	" + QueryText + "
			|WHERE
			|	NOT
			|ExchangePlan.ThisNode GROUP BY
			|	ExchangePlan.Ref,
			|	ChangesTable.MessageNumber
			|";
	EndIf;
	
	CurStringNumber = 0;
	For Each Meta IN Metadata.ExchangePlans Do
		
		If Not AccessRight("Read", Meta) Then
			Continue;
		EndIf;
	
		PlanName = Meta.Name;
		AutoRecord = Undefined;
		If MetaObject <> Undefined Then
			ContentItem = Meta.Content.Find(MetaObject);
			If ContentItem = Undefined Then
				// It is not included in the current exchange plan.
				Continue;
			EndIf;
			AutoRecord = ?(ContentItem.AutoRecord = AutoChangeRecord.Deny, 1, 2);
		EndIf;
		
		PlanName = Meta.Name;
		Query.Text = StrReplace(QueryText, "{0}", PlanName);
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			PlanString = Rows.Add();
			PlanString.Description   = Meta.Presentation();
			PlanString.PictureIndex = 0;
			PlanString.ExchangePlanName  = PlanName;
			
			PlanString.RowID = CurStringNumber;
			CurStringNumber = CurStringNumber + 1;
			
			// Sort by a presentation, it is not allowed in the query.
			TemporaryTable = Result.Unload();
			TemporaryTable.Sort("Description");
			For Each NodeString IN TemporaryTable Do;
				NewRow = PlanString.Rows.Add();
				FillPropertyValues(NewRow, NodeString);
				
				NewRow.InitialCheck = ?(NodeString.ChangesOnNodeQuantity > 0, 1, 0);
				NewRow.Check         = NewRow.InitialCheck;
				
				NewRow.PictureIndexAutoRecord = AutoRecord;
				
				NewRow.RowID = CurStringNumber;
				CurStringNumber = CurStringNumber + 1;
			EndDo;
		EndIf;
		
	EndDo;
	
	Return Tree;
EndFunction

// Returns structure describing metadata for an exchange plan.
// Objects that are not included in the exchange plan content are thrown away.  
//
// Parameters:
//    ExchangePlanName - String           - exchange plan metadata name for which configuration tree is built.
//                   - ExchangePlanRef - configuration tree is built for its exchange plan.
//                   - Undefined     - tree of the entire configuration is built.
//
// Returns: 
//    Structure - metadata description. Fields:
//         * NamesStructure              - Structure - Key - metadata group (constants, catalogs
//                                                    etc), value - full names array.
//         * PresentationsStructure     - Structure - Key - metadata group (constants, catalogs
//                                                    etc), value - full names array.
//         * AutoRecordStructure   - Structure - Key - metadata group (constants, catalogs
//                                                    etc), value - auto registration check boxes array on node.
//         * ChangesQuantity        - Undefined - it is required for further calculation.
//         * ExportedQuantity      - Undefined - it is required for further calculation.
//         * NotExportedQuantity    - Undefined - it is required for further calculation.
//         * ChangesQuantityAsString - Undefined - it is required for further calculation.
//         Group tree                     - ValueTree - contains columns.:
//               ** Description        - String - Metadata object presentation type.
//               ** MetaFullName       - String - Full name of metadata object.
//               ** PictureIndex      - Number  - Depends on metadata.
//               Appearance picture setup mark             - Undefined.
//               ** StringID - Number  - Added string index (bypass tree downwards from left to right).
//               Autoregistration picture index     - Boolean - If ExchangePlanName is specified, then for
//                                                 sheets: 1 - allowed, 2 - prohibited. Else Undefined.
//
Function GenerateMetadataStructure(ExchangePlanName = Undefined) Export
	
	Tree = New ValueTree;
	Columns = Tree.Columns;
	Columns.Add("Description");
	Columns.Add("MetaFullName");
	Columns.Add("PictureIndex");
	Columns.Add("Mark");
	Columns.Add("RowID");
	
	Columns.Add("AutoRecord");
	Columns.Add("CountChanges");
	Columns.Add("CountExported");
	Columns.Add("CountNotExported");
	Columns.Add("CountChangesString");
	
	// Root
	RootString = Tree.Rows.Add();
	RootString.Description = Metadata.Presentation();
	RootString.PictureIndex = 0;
	RootString.RowID = 0;
	
// Parameters:
	CurParameters = New Structure("NamesStructure, PresentationsStructure, AutoRecordStructure, Rows", 
		New Structure, New Structure, New Structure, RootString.Rows);
	
	If ExchangePlanName = Undefined Then
		ExchangePlan = Undefined;
	ElsIf TypeOf(ExchangePlanName) = Type("String") Then
		ExchangePlan = Metadata.ExchangePlans[ExchangePlanName];
	Else
		ExchangePlan = ExchangePlanName.Metadata();
	EndIf;
	CurParameters.Insert("ExchangePlan", ExchangePlan);
	
	Result = New Structure("Tree, NamesStructure, PresentationsStructure, AutoRecordStructure", 
		Tree, CurParameters.StructureName, CurParameters.PresentationsStructure, CurParameters.StructureAutoRecord);
	
	CurStringNumber = 1;
	MetadataLevelForm(CurStringNumber, CurParameters, 1,  2,  False,   "Constants",               NStr("en='Constants';ru='Константы'"));
	MetadataLevelForm(CurStringNumber, CurParameters, 3,  4,  True, "Catalogs",             NStr("en='Catalogs';ru='Справочники'"));
	MetadataLevelForm(CurStringNumber, CurParameters, 5,  6,  True, "Sequences",      NStr("en='Sequences';ru='Последовательности'"));
	MetadataLevelForm(CurStringNumber, CurParameters, 7,  8,  True, "Documents",               NStr("en='Documents';ru='Документы'"));
	MetadataLevelForm(CurStringNumber, CurParameters, 9,  10, True, "ChartsOfCharacteristicTypes", NStr("en='Charts of characteristics types';ru='Планы видов характеристик'"));
	MetadataLevelForm(CurStringNumber, CurParameters, 11, 12, True, "ChartsOfAccounts",             NStr("en='Charts of accounts';ru='Планы счетов'"));
	MetadataLevelForm(CurStringNumber, CurParameters, 13, 14, True, "ChartsOfCalculationTypes",       NStr("en='Charts of calculation types';ru='Планы видов расчета'"));
	MetadataLevelForm(CurStringNumber, CurParameters, 15, 16, True, "InformationRegisters",        NStr("en='Information registers';ru='Регистры сведений'"));
	MetadataLevelForm(CurStringNumber, CurParameters, 17, 18, True, "AccumulationRegisters",      NStr("en='Accumulation registers';ru='Регистры накопления'"));
	MetadataLevelForm(CurStringNumber, CurParameters, 19, 20, True, "AccountingRegisters",     NStr("en='Accounting registers';ru='Регистры бухгалтерии'"));
	MetadataLevelForm(CurStringNumber, CurParameters, 21, 22, True, "CalculationRegisters",         NStr("en='Calculation registers';ru='Регистры расчета'"));
	MetadataLevelForm(CurStringNumber, CurParameters, 23, 24, True, "BusinessProcesses",          NStr("en='Business-processes';ru='Деловые процессы'"));
	MetadataLevelForm(CurStringNumber, CurParameters, 25, 26, True, "Tasks",                  NStr("en='Tasks';ru='Задания'"));
	
	Return Result;
EndFunction

// Calculates the number of changes for the metadata objects for exchange nodes.
//
// Parameters:
//     ListOfTables - Array - names. Can be a collection "key/value" where "value" - name arrays.
//     ListOfNodes  - ExchangePlanRef, Array - nodes.
//
// Returns:
//     ValueTable - Columns:
//         * MetaFullName           - String - Full metadata name for which you should calculate quantity.
//         * ExchangeNode              - ExchangePlanRef - Ref to the exchange node for which you should calculate quantity.
//         * ChangesQuantity     - Number.
//         * ExportedQuantity   - Number.
//         * NotExportedQuantity - Number.
//
Function GetNumberOfChanges(ListOfTables, ListOfNodes) Export
	
	Result = New ValueTable;
	Columns = Result.Columns;
	Columns.Add("MetaFullName");
	Columns.Add("ExchangeNode");
	Columns.Add("CountChanges");
	Columns.Add("CountExported");
	Columns.Add("CountNotExported");
	
	Result.Indexes.Add("MetaFullName");
	Result.Indexes.Add("ExchangeNode");
	
	Query = New Query;
	Query.SetParameter("ListOfNodes", ListOfNodes);
	
	// Input or array or structure/match with many arrays.
	If ListOfTables = Undefined Then
		Return Result;
	ElsIf TypeOf(ListOfTables) = Type("Array") Then
		Source = New Structure("_", ListOfTables);
	Else
		Source = ListOfTables;
	EndIf;
	
	// Packs of 200 tables in a query.
	Text = "";
	Number = 0;
	For Each KeyValue IN Source Do
		If TypeOf(KeyValue.Value) <> Type("Array") Then
			Continue;
		EndIf;
		
		For Each Item IN KeyValue.Value Do
			If IsBlankString(Item) Then
				Continue;
			EndIf;
			
			If Not AccessRight("Read", Metadata.FindByFullName(Item)) Then
				Continue;
			EndIf;
			
			Text = Text + ?(Text = "", "", "UNION ALL") + " 
				|SELECT 
				|""
				|SELECT 
				|	""" + Item + """ AS MetaFullName,
				|	Node                AS ExchangeNode,
				|	COUNT(*)              AS CountChanges,
				|	COUNT(MessageNo) AS CountExported,
				|	COUNT(*) - COUNT(MessageNo) AS CountNotExported
				|FROM
				|	" + Item + ".Changes
				|WHERE
				|Node
				|In (&NodesList)
				|GROUP BY Node
				|";
				
			Number = Number + 1;
			If Number = 200	Then
				Query.Text = Text;
				Selection = Query.Execute().Select();
				While Selection.Next() Do
					FillPropertyValues(Result.Add(), Selection);
				EndDo;
				Text = "";
				Number = 0;
			EndIf;
			
		EndDo;
	EndDo;
	
	// Read the remainings up to the end
	If Text <> "" Then
		Query.Text = Text;
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			FillPropertyValues(Result.Add(), Selection);
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Returns metadata object by its full name. Empty string indicates the configuration.
//
// Parameters:
//    MetadataName - String - Metadata object name, for example, "Catalog.Currencies" or "Constants".
//
// Returns:
//    MetadataObject - search result.
//
Function MetadataByFullname(MetadataName) Export
	
	If IsBlankString(MetadataName) Then
		// The whole configuration
		Return Metadata;
	EndIf;
		
	Value = Metadata.FindByFullName(MetadataName);
	If Value = Undefined Then
		Value = Metadata[MetadataName];
	EndIf;
	
	Return Value;
EndFunction

// Returns check box of object registration on node.
//
// Parameters:
//    Node              - ExchangePlanRef - Exchange plan node for which you
// get the information, RegistrationObject - String, AnyRef, Structure - object for which you get the information.
//                        Structure stores change values of the record set.
//    TableName        - String - If RegistrationObject - is a structure, it contains table name for the dimensions set.
//
// Returns:
//    Boolean - registration result.
//
Function ObjectIsRegisteredAtNod(Node, RegistrationObject, TableName = Undefined) Export
	ParameterType = TypeOf(RegistrationObject);
	If ParameterType = Type("String") Then
		// Constant as metadata
		Definition = MetadataCharacteristics(RegistrationObject);
		CurrentObject = Definition.Manager.CreateValueManager();
		
	ElsIf ParameterType = Type("Structure") Then
		// Dimensions set, TableName - of what.
		Definition = MetadataCharacteristics(TableName);
		CurrentObject = Definition.Manager.CreateRecordSet();
		For Each KeyValue IN RegistrationObject Do
			CurrentObject.Filter[KeyValue.Key].Set(KeyValue.Value);
		EndDo;
		
	Else
		CurrentObject = RegistrationObject;
	EndIf;
	
	Return ExchangePlans.IsChangeRecorded(Node, CurrentObject);
EndFunction

// Changes registration of the passed one.
//
// Parameters:
//     Command                 - Boolean - It is True if it should be added, it is False if it should be deleted.
//     WithoutAccountingAutoRecord - Boolean - it is True if you should not analyze auto registration check box.
//     Node                    - ExchangePlanRef - Ref to the exchange plan node.
//     Data                  - AnyRef, String, Structure - data or array of such data.
//     TableName              - String - If Data is a structure, then it contains a table name.
//
// Returns: 
//     Structure - operation result:
//         * Total   - Number - total objects quantity.
//         Data recovery executed successfully - Number - with quantity of successfully processed objects.
//
Function ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, Data, TableName = Undefined) Export
	
	ReadSettings();
	Result = New Structure("Totals, Successfully", 0, 0);
	
	// Only while adding and working as a part of SSL.
	NeedSSLFilter = TypeOf(Command) = Type("Boolean") AND Command AND ConfigurationIsSupportingSLE AND SettingObjectsExportControl;
	
	If TypeOf(Data) = Type("Array") Then
		RegistrationData = Data;
	Else
		RegistrationData = New Array;
		RegistrationData.Add(Data);
	EndIf;
	
	For Each Item IN RegistrationData Do
		
		Type = TypeOf(Item);
		Values = New Array;
		
		If Item = Undefined Then
			// The whole configuration
			
			If TypeOf(Command) = Type("Boolean") AND Command Then
				// Add registration by parts.
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, "Constants", TableName) );
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, "Catalogs", TableName) );
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, "Documents", TableName) );
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, "Sequences", TableName) );
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, "ChartsOfCharacteristicTypes", TableName) );
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, "ChartsOfAccounts", TableName) );
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, "ChartsOfCalculationTypes", TableName) );
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, "InformationRegisters", TableName) );
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, "AccumulationRegisters", TableName) );
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, "AccountingRegisters", TableName) );
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, "CalculationRegisters", TableName) );
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, "BusinessProcesses", TableName) );
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, "Tasks", TableName) );
				Continue;
			EndIf;
			
			// Delete registration - using platform method.
			Values.Add(Undefined);
			
		ElsIf Type = Type("String") Then
			// Metadata, possible both as a collection, and as a specific kind, watch the authorization.
			Definition = MetadataCharacteristics(Item);
			If NeedSSLFilter Then
				AddResults(Result, SSL_MetadataChangeRegistration(Node, Definition, WithoutAccountingAutoRecord) );
				Continue;
				
			ElsIf WithoutAccountingAutoRecord Then
				If Definition.IsCollection Then
					For Each Meta IN Definition.Metadata Do
						AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, Meta.FullName(), TableName) );
					EndDo;
					Continue;
				Else
					Meta = Definition.Metadata;
					ContentItem = Node.Metadata().Content.Find(Meta);
					If ContentItem = Undefined Then
						Continue;
					EndIf;
					// Constant?
					Values.Add(Definition.Metadata);
				EndIf;
				
			Else
				// Skip unfitting by auto registration.
				If Definition.IsCollection Then
					// Register separately
					For Each Meta IN Definition.Metadata Do
						AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, Meta.FullName(), TableName) );
					EndDo;
					Continue;
				Else
					Meta = Definition.Metadata;
					ContentItem = Node.Metadata().Content.Find(Meta);
					If ContentItem = Undefined Or ContentItem.AutoRecord <> AutoChangeRecord.Allow Then
						Continue;
					EndIf;
					// Constant?
					Values.Add(Definition.Metadata);
				EndIf;
			EndIf;
			
			// See optional options, Values[0] - metadata of a specific kind with the "Item" name.
			For Each CurItem IN GetAdditionalObjectsOfRegistration(Item, Node, WithoutAccountingAutoRecord) Do
				Values.Add(CurItem);
			EndDo;
			
		ElsIf Type = Type("Structure") Then
			// This is either a specific records set, or result of reference type selection with filter.
			Definition = MetadataCharacteristics(TableName);
			If Definition.IsReference Then
				AddResults(Result, ChangeRegistrationAtServer(Command, WithoutAccountingAutoRecord, Node, Item.Ref) );
				Continue;
			EndIf;
			// Specific records set, ignore auto registration.
			If NeedSSLFilter Then
				AddResults(Result, SSL_SetChangesRegistration(Node, Item, Definition) );
				Continue;
			EndIf;
			
			Set = Definition.Manager.CreateRecordSet();
			For Each KeyValue IN Item Do
				Set.Filter[KeyValue.Key].Set(KeyValue.Value);
			EndDo;
			Values.Add(Set);
			// See optional variants.
			For Each CurItem IN GetAdditionalObjectsOfRegistration(Item, Node, WithoutAccountingAutoRecord, TableName) Do
				Values.Add(CurItem);
			EndDo;
			
		Else
			// Specific reference, ignore auto registration.
			If NeedSSLFilter Then
				AddResults(Result, SSL_RefChangeRegistration(Node, Item) );
				Continue;
				
			EndIf;
			Values.Add(Item);
			// See optional variants.
			For Each CurItem IN GetAdditionalObjectsOfRegistration(Item, Node, WithoutAccountingAutoRecord) Do
				Values.Add(CurItem);
			EndDo;
			
		EndIf;
		
		// Registration itself, without filter.
		For Each CurValue IN Values Do
			ExecuteCommandObjectRegistration(Command, Node, CurValue);
			Result.Successfully = Result.Successfully + 1;
			Result.Total   = Result.Total   + 1;
		EndDo;
		
	EndDo; // Robin objects in the data array for registration.
	
	Return Result;
EndFunction

// Returns a full form name start for opening by the passed object.
//
Function GetFormName(CurrentObject = Undefined) Export
	
	Type = TypeOf(CurrentObject);
	If Type = Type("DynamicList") Then
		Return CurrentObject.MainTable + ".";
	ElsIf Type = Type("String") Then
		Return CurrentObject + ".";
	EndIf;
	
	Meta = ?(CurrentObject = Undefined, Metadata(), CurrentObject.Metadata());
	Return Meta.FullName() + ".";
EndFunction	

// Recursive hierarchical marks maintenance with three states in the tree. 
//
// Parameters:
//    RowData - FormDataTreeItem - Mark is stored in the "Mark" numeric column.
//
Procedure MarkChange(RowData) Export
	RowData.Check = RowData.Check % 2;
	SetMarksDown(RowData);
	SetMarksUp(RowData);
EndProcedure

// Recursive hierarchical marks maintenance with three states in the tree. 
//
// Parameters:
//    RowData - FormDataTreeItem - Mark is stored in the "Mark" numeric column.
//
Procedure SetMarksDown(RowData) Export
	Value = RowData.Check;
	For Each Descendant IN RowData.GetItems() Do
		Descendant.Check = Value;
		SetMarksDown(Descendant);
	EndDo;
EndProcedure

// Recursive hierarchical marks maintenance with three states in the tree. 
//
// Parameters:
//    RowData - FormDataTreeItem - Mark is stored in the "Mark" numeric column.
//
Procedure SetMarksUp(RowData) Export
	RowParent = RowData.GetParent();
	If RowParent <> Undefined Then
		AllTrue = True;
		NotAllFalse = False;
		For Each Descendant IN RowParent.GetItems() Do
			AllTrue = AllTrue AND (Descendant.Check = 1);
			NotAllFalse = NotAllFalse Or Boolean(Descendant.Mark);
		EndDo;
		If AllTrue Then
			RowParent.Check = 1;
		ElsIf NotAllFalse Then
			RowParent.Check = 2;
		Else
			RowParent.Check = 0;
		EndIf;
		SetMarksUp(RowParent);
	EndIf;
EndProcedure

// Read exchange node attributes.
//
// Parameters:
//    Ref - ExchangePlanRef - Ref to exchange node.
//    Data - String - Attribute names list for reading separated by commas.
//
// Returns:
//    Structure    - calculated data.
//    Undefined - if there is no data by the passed string.
//
Function GetNodExchangeParameters(Ref, Data, Field = Undefined, Value = Undefined) Export
	
	Query = New Query("
		|SELECT " + Data + " IN " + Ref.Metadata().FullName() + "
		|WHERE Refs = &Refs
		|");
	Query.SetParameter("Ref", Ref);
	
	Temp = Query.Execute().Unload();
	If Temp.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	Result = New Structure(Data);
	FillPropertyValues(Result, Temp[0]);
	
	If Field <> Undefined AND Value = True Then
		Value = Field["SelectionButtonImage"];
	EndIf;
	
	Return Result;
EndFunction	

// Write exchange node attributes.
//
// Parameters:
//    Ref - ExchangePlanRef - Ref to exchange node.
//    Data - String - Attribute names list for reading separated by commas.
//
Procedure SetNodExchangePArameters(Ref, Data) Export
	
	NodeObject = Ref.GetObject();
	If NodeObject = Undefined Then
		// Ref to a remote object
		Return;
	EndIf;
	
	Changed = False;
	For Each Item IN Data Do
		If NodeObject[Item.Key] <> Item.Value Then
			Changed = True;
			Break;
		EndIf;
	EndDo;
	
	If Changed Then
		FillPropertyValues(NodeObject, Data);
		NodeObject.Write();
	EndIf;
EndProcedure

// Returns data description by table name/full metadata name or metadata.
//
// Parameters:
//    - TableName - String - Table name, for example, "Catalog.Currencies".
//
Function MetadataCharacteristics(MetadataTableName) Export
	
	ThisSequence = False;
	IsCollection          = False;
	ThisIsConstant          = False;
	IsReference             = False;
	ThisIsSet              = False;
	Manager              = Undefined;
	TableName            = "";
	
	If TypeOf(MetadataTableName) = Type("String") Then
		Meta = MetadataByFullname(MetadataTableName);
		TableName = MetadataTableName;
	ElsIf TypeOf(MetadataTableName) = Type("Type") Then
		Meta = Metadata.FindByType(MetadataTableName);
		TableName = Meta.FullName();
	Else
		Meta = MetadataTableName;
		TableName = Meta.FullName();
	EndIf;
	
	If Meta = Metadata.Constants Then
		IsCollection = True;
		ThisIsConstant = True;
		Manager     = Constants;
		
	ElsIf Meta = Metadata.Catalogs Then
		IsCollection = True;
		IsReference    = True;
		Manager      = Catalogs;
		
	ElsIf Meta = Metadata.Documents Then
		IsCollection = True;
		IsReference    = True;
		Manager     = Documents;
		
	ElsIf Meta = Metadata.Enums Then
		IsCollection = True;
		IsReference    = True;
		Manager     = Enums;
		
	ElsIf Meta = Metadata.ChartsOfCharacteristicTypes Then
		IsCollection = True;
		IsReference    = True;
		Manager     = ChartsOfCharacteristicTypes;
		
	ElsIf Meta = Metadata.ChartsOfAccounts Then
		IsCollection = True;
		IsReference    = True;
		Manager     = ChartsOfAccounts;
		
	ElsIf Meta = Metadata.ChartsOfCalculationTypes Then
		IsCollection = True;
		IsReference    = True;
		Manager     = ChartsOfCalculationTypes;
		
	ElsIf Meta = Metadata.BusinessProcesses Then
		IsCollection = True;
		IsReference    = True;
		Manager     = BusinessProcesses;
		
	ElsIf Meta = Metadata.Tasks Then
		IsCollection = True;
		IsReference    = True;
		Manager     = Tasks;
		
	ElsIf Meta = Metadata.Sequences Then
		ThisIsSet              = True;
		ThisSequence = True;
		IsCollection          = True;
		Manager              = Sequences;
		
	ElsIf Meta = Metadata.InformationRegisters Then
		IsCollection = True;
		ThisIsSet     = True;
		Manager 	 = InformationRegisters;
		
	ElsIf Meta = Metadata.AccumulationRegisters Then
		IsCollection = True;
		ThisIsSet     = True;
		Manager     = AccumulationRegisters;
		
	ElsIf Meta = Metadata.AccountingRegisters Then
		IsCollection = True;
		ThisIsSet     = True;
		Manager     = AccountingRegisters;
		
	ElsIf Meta = Metadata.CalculationRegisters Then
		IsCollection = True;
		ThisIsSet     = True;
		Manager     = CalculationRegisters;
		
	ElsIf Metadata.Constants.Contains(Meta) Then
		ThisIsConstant = True;
		Manager     = Constants[Meta.Name];
		
	ElsIf Metadata.Catalogs.Contains(Meta) Then
		IsReference = True;
		Manager  = Catalogs[Meta.Name];
		
	ElsIf Metadata.Documents.Contains(Meta) Then
		IsReference = True;
		Manager  = Documents[Meta.Name];
		
	ElsIf Metadata.Sequences.Contains(Meta) Then
		ThisIsSet              = True;
		ThisSequence = True;
		Manager              = Sequences[Meta.Name];
		
	ElsIf Metadata.Enums.Contains(Meta) Then
		IsReference = True;
		Manager  = Enums[Meta.Name];
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(Meta) Then
		IsReference = True;
		Manager  = ChartsOfCharacteristicTypes[Meta.Name];
		
	ElsIf Metadata.ChartsOfAccounts.Contains(Meta) Then
		IsReference = True;
		Manager = ChartsOfAccounts[Meta.Name];
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(Meta) Then
		IsReference = True;
		Manager  = ChartsOfCalculationTypes[Meta.Name];
		
	ElsIf Metadata.InformationRegisters.Contains(Meta) Then
		ThisIsSet = True;
		Manager = InformationRegisters[Meta.Name];
		
	ElsIf Metadata.AccumulationRegisters.Contains(Meta) Then
		ThisIsSet = True;
		Manager = AccumulationRegisters[Meta.Name];
		
	ElsIf Metadata.AccountingRegisters.Contains(Meta) Then
		ThisIsSet = True;
		Manager = AccountingRegisters[Meta.Name];
		
	ElsIf Metadata.CalculationRegisters.Contains(Meta) Then
		ThisIsSet = True;
		Manager = CalculationRegisters[Meta.Name];
		
	ElsIf Metadata.BusinessProcesses.Contains(Meta) Then
		IsReference = True;
		Manager = BusinessProcesses[Meta.Name];
		
	ElsIf Metadata.Tasks.Contains(Meta) Then
		IsReference = True;
		Manager = Tasks[Meta.Name];
		
	Else
		MetaParent = Meta.Parent();
		If MetaParent <> Undefined AND Metadata.CalculationRegisters.Contains(MetaParent) Then
			// Recalculation
			ThisIsSet = True;
			Manager = CalculationRegisters[MetaParent.Name].Recalculations[Meta.Name];
		EndIf;
		
	EndIf;
		
	Return New Structure("TableName, Metadata, Manager, ThisIsSet, IsReference, ThisIsConstant, ThisSequence, IsCollection",
		TableName, Meta, Manager, 
		ThisIsSet, IsReference, ThisIsConstant, ThisSequence, IsCollection);
	
EndFunction

// Returns table describing dimensions for data set changes registration.
//
// Parameters:
//    TableName   - String - Table name, for example, "InformationRegister.CurrencyRates".
//    AllDimensions - Boolean - Check box showing that you receive all changes for information
// register, not only main and leading ones.
//
// Returns:
//    ValueTable - Columns:
//         * Name         - String - change name.
//         * ValueType - TypeDescription - types.
//         * Title   - String - Presentation for dimension.
//
Function RegisterSetDimensions(TableName, AllDimensions = False) Export
	
	If TypeOf(TableName) = Type("String") Then
		Meta = MetadataByFullname(TableName);
	Else
		Meta = TableName;
	EndIf;
	
	// Determine key fields
	Dimensions = New ValueTable;
	Columns = Dimensions.Columns;
	Columns.Add("Name");
	Columns.Add("ValueType");
	Columns.Add("Title");
	
	If Not AllDimensions Then
		// Something registered
		DoNotConsider = "MessageNo,Node,";
		For Each MetaGeneral IN Metadata.CommonAttributes Do
			DoNotConsider = DoNotConsider + MetaGeneral.Name + "," ;
		EndDo;
		
		Query = New Query("SELECT * FROM " + Meta.FullName() + ".Changes WHERE FALSE");
		EmptyResult = Query.Execute();
		For Each ResultColumn IN EmptyResult.Columns Do
			ColumnName = ResultColumn.Name;
			If Find(DoNotConsider, ColumnName + ",") = 0 Then
				String = Dimensions.Add();
				String.Name         = ColumnName;
				String.ValueType = ResultColumn.ValueType;
				
				MetaDimension = Meta.Dimensions.Find(ColumnName);
				String.Title = ?(MetaDimension = Undefined, ColumnName, MetaDimension.Presentation());
			EndIf;
		EndDo;
		
		Return Dimensions;
	EndIf;
	
	// All dimensions
	
	ThisIsInformationRegister = Metadata.InformationRegisters.Contains(Meta);
	
	// Recorder
	If Metadata.AccumulationRegisters.Contains(Meta)
	 Or Metadata.AccountingRegisters.Contains(Meta)
	 Or Metadata.CalculationRegisters.Contains(Meta)
	 Or (ThisIsInformationRegister AND Meta.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate)
	 Or Metadata.Sequences.Contains(Meta)
	Then
		String = Dimensions.Add();
		String.Name         = "Recorder";
		String.ValueType = Documents.AllRefsType();
		String.Title   = NStr("en='Recorder';ru='Регистратор'");
	EndIf;
	
	// Period
	If ThisIsInformationRegister AND Meta.MainFilterOnPeriod Then
		String = Dimensions.Add();
		String.Name         = "Period";
		String.ValueType = New TypeDescription("Date");
		String.Title   = NStr("en='Period';ru='отчетный период'");
	EndIf;
	
	// Dimensions
	If ThisIsInformationRegister Then
		For Each MetaDimension IN Meta.Dimensions Do
			String = Dimensions.Add();
			String.Name         = MetaDimension.Name;
			String.ValueType = MetaDimension.Type;
			String.Title   = MetaDimension.Presentation();
		EndDo;
	EndIf;
	
	// Recalculation
	If Metadata.CalculationRegisters.Contains(Meta.Parent()) Then
		String = Dimensions.Add();
		String.Name         = "RecalculationObject";
		String.ValueType = Documents.AllRefsType();
		String.Title   = NStr("en='Recalculation object';ru='Объект перерасчета'");
	EndIf;
	
	Return Dimensions;
EndFunction

// Modifies form table adding columns to it.
//
// Parameters:
//    FormTable   - FormItem - Item connected to data to which data columns will be added.
//    StoreNames - String - Column names list which will be saved separated by commas.
//    Add      - Array - Structures with added columns description with attributes Name, ValueType, Title.
//    ColumnGroup  - FormItem - Columns group to which it is added.
//
Procedure FormTableAddColumns(FormTable, StoreNames, Add, ColumnGroup = Undefined) Export
	
	Form = FromOfFormItem(FormTable);
	FormItems = Form.Items;
	AttributeNameOfTable = FormTable.DataPath;
	
	Saving = New Structure(StoreNames);
	SavingDataPasses = New Map;
	For Each Item IN Saving Do
		SavingDataPasses.Insert(AttributeNameOfTable + "." + Item.Key, True);
	EndDo;
	
	IsDynamicList = False;
	For Each Attribute IN Form.GetAttributes() Do
		If Attribute.Name = AttributeNameOfTable AND Attribute.ValueType.ContainsType(Type("DynamicList")) Then
			IsDynamicList = True;
			Break;
		EndIf;
	EndDo;

	// The dynamic one recreates attributes.
	If Not IsDynamicList Then
		DeletingNames = New Array;
		
		// Delete all attributes that are not listed in SaveNames.
		For Each Attribute IN Form.GetAttributes(AttributeNameOfTable) Do
			curName = Attribute.Name;
			If Not Saving.Property(curName) Then
				DeletingNames.Add(Attribute.Path + "." + curName);
			EndIf;
		EndDo;
		
		Adding = New Array;
		For Each Column IN Add Do
			curName = Column.Name;
			If Not Saving.Property(curName) Then
				Adding.Add( New FormAttribute(curName, Column.ValueType, AttributeNameOfTable, Column.Title) );
			EndIf;
		EndDo;
		
		Form.ChangeAttributes(Adding, DeletingNames);
	EndIf;
	
	// Delete items
	Parent = ?(ColumnGroup = Undefined, FormTable, ColumnGroup);
	
	Delete = New Array;
	For Each Item IN Parent.ChildItems Do
		Delete.Add(Item);
	EndDo;
	For Each Item IN Delete Do
		If TypeOf(Item) <> Type("FormGroup") AND SavingDataPasses[Item.DataPath] = Undefined Then
			FormItems.Delete(Item);
		EndIf;
	EndDo;
	
	// Create items
	Prefix = FormTable.Name;
	For Each Column IN Add Do
		curName = Column.Name;
		FormItem = FormItems.Insert(Prefix + curName, Type("FormField"), Parent);
		FormItem.Type = FormFieldType.InputField;
		FormItem.DataPath = AttributeNameOfTable + "." + curName;
		FormItem.Title = Column.Title;
	EndDo;
	
EndProcedure	

// Returns detailed object presentation.
//
// Parameters:
//    - ObjectViews - AnyRef - presentation of which is received.
//
Function REFPRESENTATION(ObjectViews) Export
	
	If TypeOf(ObjectViews) = Type("String") Then
		// Metadata 
		Meta = Metadata.FindByFullName(ObjectViews);
		Result = Meta.Presentation();
		If Metadata.Constants.Contains(Meta) Then
			Result = Result + " (constant)";
		EndIf;
		Return Result;
	EndIf;
	
	// Ref
	Result = "";
	CommonUseModule = CommonUseCommonModule("CommonUse");
	If CommonUseModule <> Undefined Then
		Try
			Result = CommonUseModule.SubjectString(ObjectViews);
		Except
			// There is no subject receiving method or it is broken.
		EndTry;
	EndIf;
	
	If IsBlankString(Result) AND ObjectViews <> Undefined AND Not ObjectViews.IsEmpty() Then
		Meta = ObjectViews.Metadata();
		If Metadata.Documents.Contains(Meta) Then
			Result = String(ObjectViews);
		Else
			Presentation = Meta.ObjectPresentation;
			If IsBlankString(Presentation) Then
				Presentation = Meta.Presentation();
			EndIf;
			Result = String(ObjectViews);
			If Not IsBlankString(Presentation) Then
				Result = Result + " (" + Presentation + ")";
			EndIf;
		EndIf;
	EndIf;
	
	If IsBlankString(Result) Then
		Result = NStr("en='Not defined';ru='Не определена'");
	EndIf;
	
	Return Result;
EndFunction

// Returns the check box showing that work is executed in the file base.
//
Function ThisIsFileBase() Export
	Return Find(InfobaseConnectionString(), "File=") > 0;
EndFunction

//  Reads the current data from dynamic list by its settings and returns as a values table.
//
// Parameters:
//    - DataSource - DynamicList - form attribute.
//
Function DynamicListCurrentData(DataSource) Export
	
	CompositionSchema = New DataCompositionSchema;
	
	Source = CompositionSchema.DataSources.Add();
	Source.Name = "Source";
	Source.DataSourceType = "local";
	
	Set = CompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	Set.Query = DataSource.QueryText;
	Set.AutoFillAvailableFields = True;
	Set.DataSource = Source.Name;
	Set.Name = Source.Name;
	
	SettingsSource = New DataCompositionAvailableSettingsSource(CompositionSchema);
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(SettingsSource);
	
	CurPreferences = Composer.Settings;
	
	// Selected fields
	For Each Item IN CurPreferences.Selection.SelectionAvailableFields.Items Do
		If Not Item.Folder Then
			Field = CurPreferences.Selection.Items.Add(Type("DataCompositionSelectedField"));
			Field.Use = True;
			Field.Field = Item.Field;
		EndIf;
	EndDo;
	Group = CurPreferences.Structure.Add(Type("DataCompositionGroup"));
	Group.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));

	// Filter
	CopyDataCompositionFilter(CurPreferences.Filter, DataSource.Filter);
	CopyDataCompositionFilter(CurPreferences.Filter, DataSource.SettingsComposer.GetSettings().Filter);

	// Displaying
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionSchema, CurPreferences, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	Processor = New DataCompositionProcessor;
	Processor.Initialize(Template);
	Output  = New DataCompositionResultValueCollectionOutputProcessor;
	
	Result = New ValueTable;
	Output.SetObject(Result); 
	Output.Output(Processor);
	
	Return Result;
EndFunction

// Read settings from the general storage.
//
Procedure ReadSettings(SettingKey = "") Export
	
	ObjectKey = Metadata().FullName() + ".Form.Form";
	
	CurrentSettings = CommonSettingsStorage.Load(ObjectKey);
	If TypeOf(CurrentSettings) <> Type("Map") Then
		// Defaults
		CurrentSettings = New Map;
		CurrentSettings.Insert("SettingAutoRecordMovements",            False);
		CurrentSettings.Insert("SettingAutoRecordOfSequences", False);
		CurrentSettings.Insert("SettingAddressExternalDataQueryProcessors",      "");
		CurrentSettings.Insert("SettingObjectsExportControl",           True); // Check via SSL
		CurrentSettings.Insert("SettingVariantMessageNumber",              0);     // Register as a new one
	EndIf;
	
	SettingAutoRecordMovements            = CurrentSettings["SettingAutoRecordMovements"];
	SettingAutoRecordOfSequences = CurrentSettings["SettingAutoRecordOfSequences"];
	SettingAddressExternalDataQueryProcessors      = CurrentSettings["SettingAddressExternalDataQueryProcessors"];
	SettingObjectsExportControl           = CurrentSettings["SettingObjectsExportControl"];
	SettingVariantMessageNumber             = CurrentSettings["SettingVariantMessageNumber"];

	CheckSettingsCorrectness(SettingKey);
EndProcedure

// Set check boxes of SSL support.
//
Procedure ReadSSLSupportFlags() Export
	ConfigurationIsSupportingSLE = SSL_RequiredVersionAvailable();
	
	If ConfigurationIsSupportingSLE Then
		// Use external registration interface.
		RegistrationIsAvailableThroughSSL = SSL_RequiredVersionAvailable("2.1.5.11");
		DIBIsAvailable                = SSL_RequiredVersionAvailable("2.1.3.25");
	Else
		RegistrationIsAvailableThroughSSL = False;
		DIBIsAvailable                = False;
	EndIf;
EndProcedure

// Write settings to the general storage.
//
Procedure SaveSettings(SettingKey = "") Export
	
	ObjectKey = Metadata().FullName() + ".Form.Form";
	
	CurrentSettings = New Map;
	CurrentSettings.Insert("SettingAutoRecordMovements",            SettingAutoRecordMovements);
	CurrentSettings.Insert("SettingAutoRecordOfSequences", SettingAutoRecordOfSequences);
	CurrentSettings.Insert("SettingAddressExternalDataQueryProcessors",      SettingAddressExternalDataQueryProcessors);
	CurrentSettings.Insert("SettingObjectsExportControl",           SettingObjectsExportControl);
	CurrentSettings.Insert("SettingVariantMessageNumber",             SettingVariantMessageNumber);
	
	CommonSettingsStorage.Save(ObjectKey, "", CurrentSettings)
EndProcedure	

// Check whether settings are correct, reset in case of violation.
//
// Returns:
//     Structure - Key - setting name, value contains error description
//                 or Undefined if there is no error for this parameter.
//
Function CheckSettingsCorrectness(SettingKey = "") Export
	
	Result = New Structure("HasErrors,
		|SettingMovementsAutoRecord, SettingSequencesAutoRecord,
		|SettingAddressExternalQueryDataProcessors,
		|SettingObjectsExportControl, SettingMessageNumberOption",
		False);
		
	// External data processor availability.
	If IsBlankString(SettingAddressExternalDataQueryProcessors) Then
		// Remove possible spaces, option is disabled.
		SettingAddressExternalDataQueryProcessors = "";
		
	ElsIf Lower(Right(TrimAll(SettingAddressExternalDataQueryProcessors), 4)) = ".epf" Then
		// Data processor file
		File = New File(SettingAddressExternalDataQueryProcessors);
		Try
			If File.Exist() Then
				ExternalDataProcessors.Create(SettingAddressExternalDataQueryProcessors);
			Else
				If ThisIsFileBase() Then
					Text = NStr("en='File ""%1"" is not available';ru='Файл ""%1"" не доступен'");
				Else
					Text = NStr("en='File ""%1"" is not available on server';ru='Файл ""%1"" не доступен на сервере'");
				EndIf;
				Result.SettingAddressExternalDataQueryProcessors = StrReplace(Text, "%1", SettingAddressExternalDataQueryProcessors);;
				Result.HasErrors = True;
			EndIf;
		Except
			// Incorrect file or prohibition by security profiles.
			Information = ErrorInfo();
			Result.SettingAddressExternalDataQueryProcessors = BriefErrorDescription(Information);
			
			Result.HasErrors = True;
		EndTry;
			
	Else
		// IN configuration content
		If Metadata.DataProcessors.Find(SettingAddressExternalDataQueryProcessors) = Undefined Then
			Text = NStr("en='Data processor ""%1"" is not found in the configuration content';ru='Обработка ""%1"" не найдена в составе конфигурации'");
			Result.SettingAddressExternalDataQueryProcessors = StrReplace(Text, "%1", SettingAddressExternalDataQueryProcessors);
			
			Result.HasErrors = True;
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// The service one for registration in the enabled data processors.
//
Function ExternalDataProcessorInfo() Export
	
	Info = New Structure;
	
	Info.Insert("Kind",             "CreatingLinkedObjects");
	Info.Insert("Commands",         New ValueTable);
	Info.Insert("SafeMode", True);
	Info.Insert("Purpose",      New Array);
	
	Info.Insert("Description", NStr("en='Registration of modifications for the data exchange';ru='Регистрация изменений для обмена данными'"));
	Info.Insert("Version",       "1.0");
	Info.Insert("SSLVersion",    "1.2.1.4");
	Info.Insert("Information",    NStr("en='Data processor to control objects registration on the exchange nodes before export generation. While working in the configuration content with SSL of 2 version.1.2.0 and more controls data migration limitation for the exchange nodes.';ru='Обработка для управления регистрацией объектов на узлах обмена до формирования выгрузки. При работе в составе конфигурации с БСП версии 2.1.2.0 и старше производит контроль ограничений миграции данных для узлов обмена.'"));
	
	Info.Purpose.Add("ExchangePlans.*");
	Info.Purpose.Add("Constants.*");
	Info.Purpose.Add("Catalogs.*");
	Info.Purpose.Add("Documents.*");
	Info.Purpose.Add("Sequences.*");
	Info.Purpose.Add("ChartsOfCharacteristicTypes.*");
	Info.Purpose.Add("ChartsOfAccounts.*");
	Info.Purpose.Add("ChartsOfCalculationTypes.*");
	Info.Purpose.Add("InformationRegisters.*");
	Info.Purpose.Add("AccumulationRegisters.*");
	Info.Purpose.Add("AccountingRegisters.*");
	Info.Purpose.Add("CalculationRegisters.*");
	Info.Purpose.Add("BusinessProcesses.*");
	Info.Purpose.Add("Tasks.*");
	
	Columns = Info.Commands.Columns;
	StringType = New TypeDescription("String");
	Columns.Add("Presentation", StringType);
	Columns.Add("ID", StringType);
	Columns.Add("Use", StringType);
	Columns.Add("Modifier",   StringType);
	Columns.Add("ShowAlert", New TypeDescription("Boolean"));
	
	// The only command, further actions - determine by the type of the passed one.
	Command = Info.Commands.Add();
	Command.Presentation = NStr("en='Editing of the object modifications registration';ru='Редактирование регистрации изменений объекта'");
	Command.ID = "OpenEditRegistrationForm";
	Command.Use = "CallOfClientMethod";
	
	Return Info;
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions
//

//
// Copies data layout filter by adding to the existing ones.
//
Procedure CopyDataCompositionFilter(GroupReceiver, GroupSource) 
	
	SourceCollection = GroupSource.Items;
	TargetCollection = GroupReceiver.Items;
	For Each Item IN SourceCollection Do
		PointType  = TypeOf(Item);
		NewItem = TargetCollection.Add(PointType);
		
		FillPropertyValues(NewItem, Item);
		If PointType = Type("DataCompositionFilterItemGroup") Then
			CopyDataCompositionFilter(NewItem, Item) 
		EndIf;
		
	EndDo;
	
EndProcedure

// Executes direct action with the end object.
//
Procedure ExecuteCommandObjectRegistration(Val Command, Val Node, Val RegistrationObject)
	
	If TypeOf(Command) = Type("Boolean") Then
		If Command Then
			// Registration
			If SettingVariantMessageNumber = 1 Then
				// As a sent one
				Command = 1 + Node.SentNo;
			Else
				// As a new one
				RecordChanges(Node, RegistrationObject);
			EndIf;
		Else
			// Cancel registration
			ExchangePlans.DeleteChangeRecords(Node, RegistrationObject);
		EndIf;
	EndIf;
	
	If TypeOf(Command) = Type("Number") Then
		// Single registration with the specified message number.
		If Command = 0 Then
			// Similar to registration of the new one.
			RecordChanges(Node, RegistrationObject)
		Else
			// Change registration number, do not check SSL.
			ExchangePlans.RecordChanges(Node, RegistrationObject);
			Selection = ExchangePlans.SelectChanges(Node, Command, RegistrationObject);
			While Selection.Next() Do
				// Select changes to set data exchange message number.
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure RecordChanges(Val Node, Val RegistrationObject)
	
	If Not RegistrationIsAvailableThroughSSL Then
		ExchangePlans.RecordChanges(Node, RegistrationObject);
		Return;
	EndIf;
		
	// Always put to registration to SSL, additional actions are required.
	ModuleDataExchangeEvents = CommonUseCommonModule("DataExchangeEvents");
	
	// Input or metadata object or object.
	If TypeOf(RegistrationObject) = Type("MetadataObject") Then
		Characteristics = MetadataCharacteristics(RegistrationObject);
		If Characteristics.IsReference Then
			
			Selection = Characteristics.Manager.Select();
			While Selection.Next() Do
				ModuleDataExchangeEvents.RecordChangesData(Node, Selection.Ref, ThisObject.SettingObjectsExportControl);
			EndDo;
			
			Return;
		EndIf;
	EndIf;
	
	// Regular object
	ModuleDataExchangeEvents.RecordChangesData(Node, RegistrationObject, ThisObject.SettingObjectsExportControl);
EndProcedure

// Returns managed form to which item belongs.
//
Function FromOfFormItem(FormItem)
	Result = FormItem;
	FormTypes = New TypeDescription("ManagedForm");
	While Not FormTypes.ContainsType(TypeOf(Result)) Do
		Result = Result.Parent;
	EndDo;
	Return Result;
EndFunction

// Internal one for metadata group generation (for example, catalogs) in the metadata tree.
//
Procedure MetadataLevelForm(CurrentLineNumber, Parameters, PictureIndex, NodsPictureIndex, AddSubordinated, MetaName, TemplatePresentation)
	
	LevelPresentations = New Array;
	AutoRecord     = New Array;
	LevelNames         = New Array;
	
	AllRows = Parameters.Rows;
	MetaPlan  = Parameters.ExchangePlan;
	
	GroupRow = AllRows.Add();
	GroupRow.RowID = CurrentLineNumber;
	
	GroupRow.MetaFullName  = MetaName;
	GroupRow.Description   = TemplatePresentation;
	GroupRow.PictureIndex = PictureIndex;
	
	Rows = GroupRow.Rows;
	WereSubordinate = False;
	
	For Each Meta IN Metadata[MetaName] Do
		
		If MetaPlan = Undefined Then
			// Not considering exchange plan
			
			If Not AvailableByFunctionalOptions(Meta) Then
				Continue;
			EndIf;
			
			WereSubordinate = True;
			MetaFullName   = Meta.FullName();
			Description    = Meta.Presentation();
			
			If AddSubordinated Then
				
				NewRow = Rows.Add();
				NewRow.MetaFullName  = MetaFullName;
				NewRow.Description   = Description ;
				NewRow.PictureIndex = NodsPictureIndex;
				
				CurrentLineNumber = CurrentLineNumber + 1;
				NewRow.RowID = CurrentLineNumber;
				
			EndIf;
			
			LevelNames.Add(MetaFullName);
			LevelPresentations.Add(Description);
			
		Else
			
			Item = MetaPlan.Content.Find(Meta);
			
			If Item <> Undefined AND AccessRight("Read", Meta) Then
				
				If Not AvailableByFunctionalOptions(Meta) Then
					Continue;
				EndIf;
				
				WereSubordinate = True;
				MetaFullName   = Meta.FullName();
				Description    = Meta.Presentation();
				AutoRecord = ?(Item.AutoRecord = AutoChangeRecord.Deny, 1, 2);
				
				If AddSubordinated Then
					
					NewRow = Rows.Add();
					NewRow.MetaFullName   = MetaFullName;
					NewRow.Description    = Description ;
					NewRow.PictureIndex  = NodsPictureIndex;
					NewRow.AutoRecord = AutoRecord;
					
					CurrentLineNumber = CurrentLineNumber + 1;
					NewRow.RowID = CurrentLineNumber;
					
				EndIf;
				
				LevelNames.Add(MetaFullName);
				LevelPresentations.Add(Description);
				AutoRecord.Add(AutoRecord);
				
			EndIf;
		EndIf;
		
	EndDo;
	
	If WereSubordinate Then
		Rows.Sort("Description");
		Parameters.StructureName.Insert(MetaName, LevelNames);
		Parameters.PresentationsStructure.Insert(MetaName, LevelPresentations);
		If Not AddSubordinated Then
			Parameters.StructureAutoRecord.Insert(MetaName, AutoRecord);
		EndIf;
	Else
		// Do not put object kinds without registration.
		AllRows.Delete(GroupRow);
	EndIf;
	
EndProcedure

Function AvailableByFunctionalOptions(MetadataObject)
	Return ObjectsAvailability()[MetadataObject] <> False;
EndFunction

Function ObjectsAvailability()
	
	Parameters = New Structure();
	
	ObjectsAvailability = New Map;
	
	For Each FunctionalOption IN Metadata.FunctionalOptions Do
		
		Value = -1;
		
		For Each Item IN FunctionalOption.Content Do
			
			If Value = -1 Then
				Value = GetFunctionalOption(FunctionalOption.Name, Parameters);
			EndIf;
			
			If Value = True Then
				ObjectsAvailability.Insert(Item.Object, True);
			Else
				If ObjectsAvailability[Item.Object] = Undefined Then
					ObjectsAvailability.Insert(Item.Object, False);
				EndIf;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return ObjectsAvailability;
	
EndFunction

// Accumulate registration results.
//
Procedure AddResults(Receiver, Source)
	Receiver.Successfully = Receiver.Successfully + Source.Successfully;
	Receiver.Total   = Receiver.Total   + Source.Total;
EndProcedure	

// Returns an array of additionally registered objects according to the check boxes.
//
Function GetAdditionalObjectsOfRegistration(RegistrationObject, NodControlAutoRecord, WithNoAuthrization, TableName = Undefined)
	Result = New Array;
	
	// See global parameters.
	If (NOT SettingAutoRecordMovements) AND (NOT SettingAutoRecordOfSequences) Then
		Return Result;
	EndIf;
	
	ValueType = TypeOf(RegistrationObject);
	OnStartName = ValueType = Type("String");
	If OnStartName Then
		Definition = MetadataCharacteristics(RegistrationObject);
	ElsIf ValueType = Type("Structure") Then
		Definition = MetadataCharacteristics(TableName);
		If Definition.ThisSequence Then
			Return Result;
		EndIf;
	Else
		Definition = MetadataCharacteristics(RegistrationObject.Metadata());
	EndIf;
	
	MetaObject = Definition.Metadata;
	
	// Collection recursively	
	If Definition.IsCollection Then
		For Each Meta IN MetaObject Do
			AdditionalSet = GetAdditionalObjectsOfRegistration(Meta.FullName(), NodControlAutoRecord, WithNoAuthrization, TableName);
			For Each Item IN AdditionalSet Do
				Result.Add(Item);
			EndDo;
		EndDo;
		Return Result;
	EndIf;
	
	// Single
	NodeStructure = NodControlAutoRecord.Metadata().Content;
	
	// Documents. They can influence sequences and movements.
	If Metadata.Documents.Contains(MetaObject) Then
		
		If SettingAutoRecordMovements Then
			For Each Meta IN MetaObject.RegisterRecords Do
				
				ContentItem = NodeStructure.Find(Meta);
				If ContentItem <> Undefined AND (WithNoAuthrization Or ContentItem.AutoRecord = AutoChangeRecord.Allow) Then
					If OnStartName Then
						Result.Add(Meta);
					Else
						Definition = MetadataCharacteristics(Meta);
						Set = Definition.Manager.CreateRecordSet();
						Set.Filter.Recorder.Set(RegistrationObject);
						Set.Read();
						Result.Add(Set);
						// And check received set recursively.
						AdditionalSet = GetAdditionalObjectsOfRegistration(Set, NodControlAutoRecord, WithNoAuthrization, TableName);
						For Each Item IN AdditionalSet Do
							Result.Add(Item);
						EndDo;
					EndIf;
				EndIf;
				
			EndDo;
		EndIf;
		
		If SettingAutoRecordOfSequences Then
			For Each Meta IN Metadata.Sequences Do
				
				Definition = MetadataCharacteristics(Meta);
				If Meta.Documents.Contains(MetaObject) Then
					// Sequence is registered for this document.
					ContentItem = NodeStructure.Find(Meta);
					If ContentItem <> Undefined AND (WithNoAuthrization Or ContentItem.AutoRecord = AutoChangeRecord.Allow) Then
						// Registered on this node.
						If OnStartName Then
							Result.Add(Meta);
						Else
							Set = Definition.Manager.CreateRecordSet();
							Set.Filter.Recorder.Set(RegistrationObject);
							Set.Read();
							Result.Add(Set);
						EndIf;
					EndIf;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	// Register records. They can influence sequences.
	ElsIf SettingAutoRecordOfSequences AND (
		Metadata.InformationRegisters.Contains(MetaObject)
		Or Metadata.AccumulationRegisters.Contains(MetaObject)
		Or Metadata.AccountingRegisters.Contains(MetaObject)
		Or Metadata.CalculationRegisters.Contains(MetaObject)
	) Then
		For Each Meta IN Metadata.Sequences Do
			If Meta.RegisterRecords.Contains(MetaObject) Then
				// Sequence is registered for records set.
				ContentItem = NodeStructure.Find(Meta);
				If ContentItem <> Undefined AND (WithNoAuthrization Or ContentItem.AutoRecord = AutoChangeRecord.Allow) Then
					Result.Add(Meta);
				EndIf;
			EndIf;
		EndDo;
		
	EndIf;
	
	Return Result;
EndFunction

// Converts string to number
// 
// Parameters:
//     Text - String - number row presentation.
// 
// Returns:
//     Number        - converted string.
//     Undefined - if a string can not be converted.
//
Function StringToNumber(Val Text)
	NumberText = TrimAll(StrReplace(Text, Chars.NBSp, ""));
	
	If IsBlankString(NumberText) Then
		Return 0;
	EndIf;
	
	// Leading zeros
	Position = 1;
	While Mid(NumberText, Position, 1) = "0" Do
		Position = Position + 1;
	EndDo;
	NumberText = Mid(NumberText, Position);
	
	// Check for the default result.
	If NumberText = "0" Then
		Result = 0;
	Else
		NumberType = New TypeDescription("Number");
		Result = NumberType.AdjustValue(NumberText);
		If Result = 0 Then
			// Default result is processed above, this is a conversion error.
			Result = Undefined;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

// Returns general module or Undefined if there is no such one.
//
Function CommonUseCommonModule(Val ModuleName)
	
	If Metadata.CommonModules.Find(ModuleName) = Undefined Then
		Return Undefined;
	EndIf;
	
	SetSafeMode(True);
	Result = Eval(ModuleName);
	SetSafeMode(False);
	
	Return Result;
EndFunction

// Returns check box showing that SSL in the current configuration provides functionality.
//
Function SSL_RequiredVersionAvailable(Val Version = Undefined) Export
	
	CurrentVersion = Undefined;
	ModuleStandardSubsystemsServer = CommonUseCommonModule("StandardSubsystemsServer");
	If ModuleStandardSubsystemsServer <> Undefined Then
		Try
			CurrentVersion = ModuleStandardSubsystemsServer.LibraryVersion();
		Except
			CurrentVersion = Undefined;
		EndTry;
	EndIf;
	
	If CurrentVersion = Undefined Then
		// Version definition method is absent or broken, consider SSL unavailable.
		Return False
	EndIf;
	CurrentVersion = StrReplace(CurrentVersion, ".", Chars.LF);
	
	NecessaryVersion = StrReplace(?(Version = Undefined, "2.2.2", Version), ".", Chars.LF);
	
	For IndexOf = 1 To StrLineCount(NecessaryVersion) Do
		
		CurrentVersionType = StringToNumber(StrGetLine(CurrentVersion, IndexOf));
		NesessaryVersionType  = StringToNumber(StrGetLine(NecessaryVersion,  IndexOf));
		
		If CurrentVersionType = Undefined Then
			Return False;
			
		ElsIf CurrentVersionType > NesessaryVersionType Then
			Return True;
			
		ElsIf CurrentVersionType < NesessaryVersionType Then
			Return False;
			
		EndIf;
	EndDo;
	
	Return True;
EndFunction

// Returns check box of object control in SSL.
//
Function SSL_ObjectExportControl(Node, RegistrationObject)
	
	sending = DataItemSend.Auto;
	ModuleDataExchangeEvents = CommonUseCommonModule("DataExchangeEvents");
	If ModuleDataExchangeEvents <> Undefined Then
		ModuleDataExchangeEvents.OnDataSendingToCorrespondent(RegistrationObject, sending, , Node);
		Return sending = DataItemSend.Auto;
	EndIf;
	
	// Unknown SSL version
	Return True;
EndFunction

// Checks whether reference can register changes in SSL.
// Returns structure with fields "Totally" and "Successfully" describing registration quantity.
//
Function SSL_RefChangeRegistration(Node, Ref, WithoutAccountingAutoRecord = True)
	
	Result = New Structure("Totals, Successfully", 0, 0);
	
	If WithoutAccountingAutoRecord Then
		NodeStructure = Undefined;
	Else
		NodeStructure = Node.Metadata().Content;
	EndIf;
	
	ContentItem = ?(NodeStructure = Undefined, Undefined, NodeStructure.Find(Ref.Metadata()));
	If ContentItem = Undefined Or ContentItem.AutoRecord = AutoChangeRecord.Allow Then
		// Object itself
		Result.Total = 1;
		RegistrationObject = Ref.GetObject();
		// For dead references RegistrationObject will be Undefined.
		If RegistrationObject = Undefined Or SSL_ObjectExportControl(Node, RegistrationObject) Then
			ExecuteCommandObjectRegistration(True, Node, Ref);
			Result.Successfully = 1;
		EndIf;
		RegistrationObject = Undefined;
	EndIf;	
	
	// See optional variants.
	If Result.Successfully > 0 Then
		For Each Item IN GetAdditionalObjectsOfRegistration(Ref, Node, WithoutAccountingAutoRecord) Do
			Result.Total = Result.Total + 1;
			If SSL_ObjectExportControl(Node, Item) Then
				ExecuteCommandObjectRegistration(True, Node, Item);
				Result.Successfully = Result.Successfully + 1;
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Checks whether values set can register changes in SSL.
// Returns structure with fields "Totally" and "Successfully" describing registration quantity.
//
Function SSL_SetChangesRegistration(Node, FieldsStructure, Definition, WithoutAccountingAutoRecord = True)
	
	Result = New Structure("Totals, Successfully", 0, 0);
	
	If WithoutAccountingAutoRecord Then
		NodeStructure = Undefined;
	Else
		NodeStructure = Node.Metadata().Content;
	EndIf;
	
	ContentItem = ?(NodeStructure = Undefined, Undefined, NodeStructure.Find(Definition.Metadata));
	If ContentItem = Undefined Or ContentItem.AutoRecord = AutoChangeRecord.Allow Then
		Result.Total = 1;
		
		Set = Definition.Manager.CreateRecordSet();
		For Each KeyValue IN FieldsStructure Do
			Set.Filter[KeyValue.Key].Set(KeyValue.Value);
		EndDo;
		Set.Read();
		
		If SSL_ObjectExportControl(Node, Set) Then
			ExecuteCommandObjectRegistration(True, Node, Set);
			Result.Successfully = 1;
		EndIf;
		
	EndIf;
	
	// See optional variants.
	If Result.Successfully > 0 Then
		For Each Item IN GetAdditionalObjectsOfRegistration(Set, Node, WithoutAccountingAutoRecord) Do
			Result.Total = Result.Total + 1;
			If SSL_ObjectExportControl(Node, Item) Then
				ExecuteCommandObjectRegistration(True, Node, Item);
				Result.Successfully = Result.Successfully + 1;
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Checks whether constant can register changes in SSL.
// Returns structure with fields "Totally" and "Successfully" describing registration quantity.
//
Function SSL_ConstatntChangesRegistration(Node, Definition, WithoutAccountingAutoRecord = True)
	
	Result = New Structure("Totals, Successfully", 0, 0);
	
	If WithoutAccountingAutoRecord Then
		NodeStructure = Undefined;
	Else
		NodeStructure = Node.Metadata().Content;
	EndIf;
	
	ContentItem = ?(NodeStructure = Undefined, Undefined, NodeStructure.Find(Definition.Metadata));
	If ContentItem = Undefined Or ContentItem.AutoRecord = AutoChangeRecord.Allow Then
		Result.Total = 1;
		
		RegistrationObject = Definition.Manager.CreateValueManager();
		
		If SSL_ObjectExportControl(Node, RegistrationObject) Then
			ExecuteCommandObjectRegistration(True, Node, RegistrationObject);
			Result.Successfully = 1;
		EndIf;
		
	EndIf;	
	
	Return Result;
EndFunction

// Checks whether metadata set can register changes in SSL.
// Returns structure with fields "Totally" and "Successfully" describing registration quantity.
//
Function SSL_MetadataChangeRegistration(Node, Definition, WithoutAccountingAutoRecord)
	
	Result = New Structure("Totals, Successfully", 0, 0);
	
	If Definition.IsCollection Then
		For Each MetaKind IN Definition.Metadata Do
			CurDescription = MetadataCharacteristics(MetaKind);
			AddResults(Result, SSL_MetadataChangeRegistration(Node, CurDescription, WithoutAccountingAutoRecord) );
		EndDo;
	Else;
		AddResults(Result, SSL_MetadataObjectsChangesRegistration(Node, Definition, WithoutAccountingAutoRecord) );
	EndIf;
	
	Return Result;
EndFunction

// Checks whether metadata object can register changes in SSL.
// Returns structure with fields "Totally" and "Successfully" describing registration quantity.
//
Function SSL_MetadataObjectsChangesRegistration(Node, Definition, WithoutAccountingAutoRecord)
	
	Result = New Structure("Totals, Successfully", 0, 0);
	
	ContentItem = Node.Metadata().Content.Find(Definition.Metadata);
	If ContentItem = Undefined Then
		// They are not registered at all
		Return Result;
	EndIf;
	
	If (NOT WithoutAccountingAutoRecord) AND ContentItem.AutoRecord <> AutoChangeRecord.Allow Then
		// Clipping by auto registration.
		Return Result;
	EndIf;
	
	CurTableName = Definition.TableName;
	If Definition.ThisIsConstant Then
		AddResults(Result, SSL_ConstatntChangesRegistration(Node, Definition) );
		Return Result;
		
	ElsIf Definition.IsReference Then
		DimensionsFields = "Ref";
		
	ElsIf Definition.ThisIsSet Then
		DimensionsFields = "";
		For Each String IN RegisterSetDimensions(CurTableName) Do
			DimensionsFields = DimensionsFields + "," + String.Name
		EndDo;
		DimensionsFields = Mid(DimensionsFields, 2);
		
	Else
		Return Result;
	EndIf;
	
	Query = New Query("
		|SELECT DISTINCT 
		|	" + ?(IsBlankString(DimensionsFields), "*", DimensionsFields) + "
		|IN 
		|	" + CurTableName + "
		|");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Definition.ThisIsSet Then
			Data = New Structure(DimensionsFields);
			FillPropertyValues(Data, Selection);
			AddResults(Result, SSL_SetChangesRegistration(Node, Data, Definition) );
		ElsIf Definition.IsReference Then
			AddResults(Result, SSL_RefChangeRegistration(Node, Selection.Ref, WithoutAccountingAutoRecord) );
		EndIf;
	EndDo;

	Return Result;
EndFunction

// Updates MOI data and register on the passed node.
//
Function SSL_RefreshAndRegisterHostIOM(Val Node) Export
	
	Result = New Structure("Totals, Successfully", 0 , 0);
	
	MetaPlanExchangeSite = Node.Metadata();
	
	If (NOT DIBIsAvailable)                                      // Work with MOI is unavailable because of SSL version.
		Or (ExchangePlans.MasterNode() <> Undefined)              // Current base - subordinate node.
		Or (NOT MetaPlanExchangeSite.DistributedInfobase) // Node parameter of not DIB
	Then 
		Return Result;
	EndIf;
	
	// Register all for DIB without SSL rules control.
	
	// Catalog itself
	MetaCatalog = Metadata.Catalogs["MetadataObjectIDs"];
	If MetaPlanExchangeSite.Content.Contains(MetaCatalog) Then
		ExchangePlans.RecordChanges(Node, MetaCatalog);
		
		Query = New Query("SELECT COUNT(Ref) AS ItemCount FROM Catalog.MetadataObjectIDs");
		Result.Successfully = Query.Execute().Unload()[0].ItemCount;
	EndIf;
	
	// Predefined items
	Result.Successfully = Result.Successfully 
		+ RegisterPredefinedChangesForNode(Node, Metadata.Catalogs)
		+ RegisterPredefinedChangesForNode(Node, Metadata.ChartsOfCharacteristicTypes)
		+ RegisterPredefinedChangesForNode(Node, Metadata.ChartsOfAccounts)
		+ RegisterPredefinedChangesForNode(Node, Metadata.ChartsOfCalculationTypes);
	
	Result.Total = Result.Successfully;
	Return Result;
EndFunction

Function RegisterPredefinedChangesForNode(Val Node, Val MetadataCollection)
	
	NodeStructure = Node.Metadata().Content;
	Result  = 0;
	Query     = New Query;
	
	For Each MetadataObject IN MetadataCollection Do
		If NodeStructure.Contains(MetadataObject) Then
			
			Query.Text = "
				|SELECT
				|	Ref
				|FROM
				|	" + MetadataObject.FullName() + "
				|WHERE
				|	Predefined";
			Selection = Query.Execute().Select();
			
			Result = Result + Selection.Count();
			
			// Register for DIB without SSL rules control.
			While Selection.Next() Do
				ExchangePlans.RecordChanges(Node, Selection.Ref);
			EndDo;
			
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#EndIf
